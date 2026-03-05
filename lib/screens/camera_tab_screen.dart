import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/camera_settings_provider.dart';
import '../providers/gym_provider.dart';
import '../widgets/camera_grade_overlay.dart';
import '../widgets/camera_gym_overlay.dart';
import '../widgets/zoom_controls.dart';
import 'record_save_screen.dart';

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
  int _recordingSeconds = 0;
  Timer? _timer;
  int _selectedCameraIndex = 0;
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      if (_controller != null && _controller!.value.isInitialized) {
        _controller?.dispose();
        _controller = null;
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_controller == null) {
        _initCamera();
      }
    }
  }

  Future<void> _initCamera() async {
    if (_isInitializing) return;
    _isInitializing = true;

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
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: true,
    );
    try {
      await controller.initialize();
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
      final file = await _controller!.stopVideoRecording();
      _timer?.cancel();
      if (!mounted) return;

      // .temp → .mp4로 변환
      String videoPath = file.path;
      if (p.extension(videoPath).toLowerCase() != '.mp4') {
        final mp4Path =
            p.join(p.dirname(videoPath), '${p.basenameWithoutExtension(videoPath)}.mp4');
        await File(videoPath).rename(mp4Path);
        videoPath = mp4Path;
      }

      // 캐시 → 영구 저장소로 이동 (캐시는 OS가 임의로 삭제 가능)
      final appDir = await getApplicationDocumentsDirectory();
      final videosDir = Directory(p.join(appDir.path, 'videos'));
      if (!videosDir.existsSync()) {
        videosDir.createSync(recursive: true);
      }
      final persistentPath = p.join(videosDir.path, p.basename(videoPath));
      await File(videoPath).rename(persistentPath);
      videoPath = persistentPath;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 가장 가까운 암장 자동 선택 (미선택 상태일 때만)
    ref.listen(nearbyGymsProvider, (_, next) {
      next.whenData((gyms) {
        if (gyms.isNotEmpty) {
          final settings = ref.read(cameraSettingsProvider);
          if (settings.selectedGym == null && settings.manualGymName == null) {
            ref.read(cameraSettingsProvider.notifier).setGym(gyms.first);
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
                ElevatedButton(
                  onPressed: () async {
                    setState(() => _errorMessage = null);
                    await openAppSettings();
                  },
                  child: const Text('설정 열기'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 카메라 프리뷰
          Center(child: CameraPreview(_controller!)),

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

          // 좌측 오버레이: 난이도/색상 + 암장 (녹화 중에는 숨김)
          if (!_isRecording)
            const Positioned(
              left: 16,
              bottom: 160,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CameraGradeOverlay(),
                  SizedBox(height: 8),
                  CameraGymOverlay(),
                ],
              ),
            ),

          // 하단: 녹화 버튼 (초록)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _toggleRecording,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: Center(
                    child: _isRecording
                        ? Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          )
                        : Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),

          // 우측: 줌 컨트롤 (암장 선택과 같은 높이)
          Positioned(
            right: 16,
            bottom: 160,
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
