import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/camera_settings_provider.dart';
import '../providers/gym_color_scale_provider.dart';
import '../utils/cache_cleanup.dart';
import '../providers/gym_provider.dart';
import '../widgets/camera_grade_overlay.dart';
import '../widgets/camera_gym_overlay.dart';
import '../widgets/zoom_controls.dart';
import 'record_save_screen.dart';
import '../app.dart';

class CameraTabScreen extends ConsumerStatefulWidget {
  const CameraTabScreen({super.key});

  @override
  ConsumerState<CameraTabScreen> createState() => _CameraTabScreenState();
}

class _CameraTabScreenState extends ConsumerState<CameraTabScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isRecording = false;
  bool _isInitializing = false;
  bool _hasEverInitialized = false;
  int _recordingSeconds = 0;
  Timer? _timer;
  int _selectedCameraIndex = 0;
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _baseZoom = 1.0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 카메라 탭이 아닐 때는 lifecycle 처리 불필요
    final currentTab = ref.read(bottomNavIndexProvider);
    if (currentTab != 2) return;

    if (state == AppLifecycleState.inactive) {
      final controllerToDispose = _controller;
      _controller = null;
      _isRecording = false;
      _timer?.cancel();
      _recordingSeconds = 0;
      controllerToDispose?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (_controller == null && !_isInitializing && _hasEverInitialized) {
        _initCamera();
      }
    }
  }

  Future<void> _initCamera() async {
    if (_isInitializing) return;
    _isInitializing = true;
    if (mounted) setState(() => _errorMessage = null);

    try {
      final cameraStatus = await Permission.camera.request();
      final audioStatus = await Permission.microphone.request();

      if (!mounted) return;

      if (!cameraStatus.isGranted || !audioStatus.isGranted) {
        setState(() {
          _errorMessage = '카메라 및 마이크 권한이 필요합니다.\n설정에서 권한을 허용해 주세요.';
        });
        return;
      }

      _cameras = await availableCameras();
      if (!mounted) return;

      if (_cameras.isNotEmpty) {
        await _setupCamera(_cameras[_selectedCameraIndex]);
      } else {
        setState(() {
          _errorMessage = '사용 가능한 카메라를 찾을 수 없습니다.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '카메라 초기화 실패: $e';
        });
      }
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _setupCamera(CameraDescription camera) async {
    _controller?.dispose();
    _controller = null;
    _isRecording = false;
    _timer?.cancel();
    _recordingSeconds = 0;
    // 이전 카메라 세션의 캐시 정리
    CacheCleanup.clearAppCache();
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: true,
    );
    try {
      await controller.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('카메라 초기화 시간 초과 (에뮬레이터에서는 카메라가 지원되지 않을 수 있습니다)');
        },
      );
      if (mounted) {
        final minZoom = await controller.getMinZoomLevel();
        final maxZoom = await controller.getMaxZoomLevel();
        setState(() {
          _controller = controller;
          _minZoom = minZoom;
          _maxZoom = maxZoom;
          _currentZoom = minZoom;
          _errorMessage = null;
        });
      }
    } catch (e) {
      controller.dispose();
      if (mounted) {
        setState(() {
          _errorMessage = '카메라를 열 수 없습니다: $e';
        });
      }
    }
  }

  void _toggleRecording() async {
    if (_controller == null) return;

    if (_isRecording) {
      if (!_controller!.value.isRecordingVideo) {
        // 컨트롤러가 실제로 녹화 중이 아니면 상태만 리셋
        setState(() {
          _isRecording = false;
          _recordingSeconds = 0;
        });
        _timer?.cancel();
        return;
      }
      final file = await _controller!.stopVideoRecording();
      _timer?.cancel();
      if (!mounted) return;

      // .temp → .mp4로 변환 (캐시에 유지, 저장 시에만 영구 저장소로 이동)
      String videoPath = file.path;
      if (p.extension(videoPath).toLowerCase() != '.mp4') {
        final mp4Path =
            p.join(p.dirname(videoPath), '${p.basenameWithoutExtension(videoPath)}.mp4');
        await File(videoPath).rename(mp4Path);
        videoPath = mp4Path;
      }

      if (!mounted) return;
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => RecordSaveScreen(videoPath: videoPath),
        ),
      );

      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _recordingSeconds = 0;
      });

    } else {
      try {
        await _controller!.startVideoRecording();
        if (!mounted) return;
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _recordingSeconds++);
        });
        setState(() => _isRecording = true);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('녹화 시작 실패: $e')),
        );
      }
    }
  }

  void _switchCamera() async {
    if (_cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _setupCamera(_cameras[_selectedCameraIndex]);
  }

  void _setZoom(double zoom) async {
    if (_controller == null) return;
    await _controller!.setZoomLevel(zoom);
    setState(() => _currentZoom = zoom);
  }

  String get _formattedTime {
    final min = (_recordingSeconds ~/ 60).toString().padLeft(2, '0');
    final sec = (_recordingSeconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _timer?.cancel();
    CacheCleanup.clearAppCache();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentTab = ref.watch(bottomNavIndexProvider);

    // ref.listen으로 탭 전환을 감지하여 카메라 lifecycle 관리
    ref.listen(bottomNavIndexProvider, (previous, next) {
      if (next == 2 && previous != 2) {
        // 카메라 탭으로 진입
        if (!_hasEverInitialized) {
          _hasEverInitialized = true;
          _initCamera();
        } else if (_controller == null && !_isInitializing && _errorMessage == null) {
          _initCamera();
        }
      } else if (next != 2 && previous == 2) {
        // 카메라 탭에서 이탈 — 비동기로 dispose하여 build 중 side-effect 방지
        final controllerToDispose = _controller;
        _controller = null;
        _isRecording = false;
        _timer?.cancel();
        _recordingSeconds = 0;
        if (mounted) setState(() {});
        controllerToDispose?.dispose();
      }
    });

    // 최초 진입 시 (listen은 변경만 감지하므로 초기 상태 처리)
    if (currentTab == 2 && !_hasEverInitialized && !_isInitializing) {
      _hasEverInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _initCamera();
      });
    }

    ref.listen(nearbyGymsProvider, (_, next) {
      next.whenData((gyms) {
        if (gyms.isNotEmpty) {
          final settings = ref.read(cameraSettingsProvider);
          if (settings.selectedGym == null) {
            ref.read(cameraSettingsProvider.notifier).setGym(gyms.first);
            // 브랜드 색상표가 있으면 Lv.1(최고 난이도) 색상으로 기본값 설정
            final colorScale = ref.read(gymColorScaleProvider(gyms.first.name));
            if (colorScale != null && colorScale.levels.isNotEmpty) {
              final lv1 = colorScale.levels.first;
              ref.read(cameraSettingsProvider.notifier).setColor(lv1.color);
              ref.read(cameraSettingsProvider.notifier).setGrade(lv1.vMin);
            }
          }
        }
      });
    });

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 64),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _errorMessage = null);
                        _initCamera();
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('재시도'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () async {
                        await openAppSettings();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white38),
                      ),
                      child: const Text('설정 열기'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 24),
              if (!_isInitializing)
                ElevatedButton.icon(
                  onPressed: _initCamera,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('재시도'),
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 카메라 프리뷰 (핀치 줌 지원)
          GestureDetector(
            onScaleStart: (_) {
              _baseZoom = _currentZoom;
            },
            onScaleUpdate: (details) {
              final newZoom = (_baseZoom * details.scale).clamp(_minZoom, _maxZoom);
              _setZoom(newZoom);
            },
            child: Center(child: CameraPreview(_controller!)),
          ),

          // 상단: 닫기 + 촬영 시간 + 카메라 전환
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // X 버튼 → 기록 탭으로 전환
                  GestureDetector(
                    onTap: () {
                      ref.read(bottomNavIndexProvider.notifier).state = 1;
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 24),
                    ),
                  ),
                  if (_isRecording)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(_formattedTime,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16)),
                    ),
                  // 카메라 전환
                  GestureDetector(
                    onTap: _isRecording ? null : _switchCamera,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.flip_camera_ios,
                        color:
                            _isRecording ? Colors.white38 : Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 하단 오버레이: 암장 + 난이도 (녹화 중에는 숨김)
          if (!_isRecording)
            Positioned(
              left: 16,
              right: 16,
              bottom: 140,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Expanded(child: CameraGymOverlay()),
                    SizedBox(width: 8),
                    CameraGradeOverlay(),
                  ],
                ),
              ),
            ),

          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _toggleRecording,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: ReclimColors.accent.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isRecording
                        ? Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: ReclimColors.accent,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          )
                        : Container(
                            width: 60,
                            height: 60,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  ReclimColors.accent,
                                  ReclimColors.accentLight,
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),

          // 우측: 줌 컨트롤
          Positioned(
            right: 16,
            bottom: 220,
            child: ZoomControls(
              currentZoom: _currentZoom,
              minZoom: _minZoom,
              maxZoom: _maxZoom,
              onZoomChanged: _setZoom,
            ),
          ),
        ],
      ),
    );
  }
}
