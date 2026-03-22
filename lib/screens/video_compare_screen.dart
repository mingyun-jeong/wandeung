import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import '../config/r2_config.dart';
import '../models/climbing_record.dart';
import '../utils/constants.dart';
import '../widgets/reclim_app_bar.dart';
import '../app.dart';

class VideoCompareScreen extends StatefulWidget {
  final ClimbingRecord record1;
  final ClimbingRecord record2;

  const VideoCompareScreen({
    super.key,
    required this.record1,
    required this.record2,
  });

  @override
  State<VideoCompareScreen> createState() => _VideoCompareScreenState();
}

class _VideoCompareScreenState extends State<VideoCompareScreen> {
  VideoPlayerController? _controller1;
  VideoPlayerController? _controller2;
  double _aspectRatio1 = 9 / 16;
  double _aspectRatio2 = 9 / 16;
  bool _initialized1 = false;
  bool _initialized2 = false;
  String? _error1;
  String? _error2;
  bool _isSyncPlaying = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initBothVideos();
  }

  Future<void> _initBothVideos() async {
    await Future.wait([
      _initVideo(widget.record1.videoPath, isFirst: true),
      _initVideo(widget.record2.videoPath, isFirst: false),
    ]);
  }

  Future<void> _initVideo(String? path, {required bool isFirst}) async {
    if (path == null) {
      if (mounted) {
        setState(() {
          if (isFirst) {
            _error1 = '영상 경로가 없습니다';
            _initialized1 = true;
          } else {
            _error2 = '영상 경로가 없습니다';
            _initialized2 = true;
          }
        });
      }
      return;
    }

    VideoPlayerController controller;
    if (path.startsWith('/')) {
      if (!File(path).existsSync()) {
        if (mounted) {
          setState(() {
            if (isFirst) {
              _error1 = '영상 파일을 찾을 수 없습니다';
              _initialized1 = true;
            } else {
              _error2 = '영상 파일을 찾을 수 없습니다';
              _initialized2 = true;
            }
          });
        }
        return;
      }
      controller = VideoPlayerController.file(File(path));
    } else {
      final url = await R2Config.getPresignedUrl(path);
      controller = VideoPlayerController.networkUrl(Uri.parse(url));
    }

    try {
      await controller.initialize();
    } catch (e) {
      debugPrint('영상 초기화 실패: $e');
      controller.dispose();
      if (mounted) {
        setState(() {
          if (isFirst) {
            _error1 = '영상을 재생할 수 없습니다';
            _initialized1 = true;
          } else {
            _error2 = '영상을 재생할 수 없습니다';
            _initialized2 = true;
          }
        });
      }
      return;
    }

    final size = controller.value.size;
    final rotation = controller.value.rotationCorrection;
    double aspectRatio;
    if (size.width > 0 && size.height > 0 && (rotation == 90 || rotation == 270)) {
      aspectRatio = size.height / size.width;
    } else {
      aspectRatio = controller.value.aspectRatio;
    }

    controller.addListener(_onVideoStateChanged);

    if (mounted) {
      setState(() {
        if (isFirst) {
          _controller1 = controller;
          _aspectRatio1 = aspectRatio;
          _initialized1 = true;
        } else {
          _controller2 = controller;
          _aspectRatio2 = aspectRatio;
          _initialized2 = true;
        }
      });
    }
  }

  void _togglePlayPause(VideoPlayerController controller) {
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    // 개별 조작 시 동시 재생 상태 해제
    _isSyncPlaying = false;
    setState(() {});
  }

  Future<void> _toggleSyncPlayPause() async {
    final c1 = _controller1;
    final c2 = _controller2;
    if (c1 == null && c2 == null) return;

    if (_isSyncPlaying) {
      _isSyncPlaying = false;
      setState(() {});
      await Future.wait([
        if (c1 != null) c1.pause(),
        if (c2 != null) c2.pause(),
      ]);
    } else {
      _isSyncPlaying = true;
      setState(() {});
      await Future.wait([
        if (c1 != null) c1.play(),
        if (c2 != null) c2.play(),
      ]);
    }
    if (mounted) setState(() {});
  }

  void _onVideoStateChanged() {
    if (!mounted) return;
    // 둘 다 재생 중이 아니면 동시 재생 상태 해제
    final c1Playing = _controller1?.value.isPlaying ?? false;
    final c2Playing = _controller2?.value.isPlaying ?? false;
    if (_isSyncPlaying && !c1Playing && !c2Playing) {
      _isSyncPlaying = false;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller1?.removeListener(_onVideoStateChanged);
    _controller2?.removeListener(_onVideoStateChanged);
    _controller1?.dispose();
    _controller2?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    final panel1 = _VideoPanel(
      controller: _controller1,
      record: widget.record1,
      initialized: _initialized1,
      error: _error1,
      aspectRatio: _aspectRatio1,
      onPlayPause: () {
        if (_controller1 != null) _togglePlayPause(_controller1!);
      },
      onSeek: (position) {
        _controller1?.seekTo(position);
        setState(() {});
      },
    );

    final panel2 = _VideoPanel(
      controller: _controller2,
      record: widget.record2,
      initialized: _initialized2,
      error: _error2,
      aspectRatio: _aspectRatio2,
      onPlayPause: () {
        if (_controller2 != null) _togglePlayPause(_controller2!);
      },
      onSeek: (position) {
        _controller2?.seekTo(position);
        setState(() {});
      },
    );

    final bothReady = _initialized1 && _initialized2 &&
        _controller1 != null && _controller2 != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: isLandscape ? null : ReclimAppBar(
        title: '영상 비교',
        showBackButton: true,
        extraActions: [
          if (bothReady)
            IconButton(
              onPressed: _toggleSyncPlayPause,
              tooltip: _isSyncPlaying ? '동시 정지' : '동시 재생',
              icon: Icon(
                _isSyncPlaying ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
                size: 28,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: isLandscape
            ? Stack(
                children: [
                  Row(
                    children: [
                      Expanded(child: panel1),
                      const SizedBox(width: 12),
                      Expanded(child: panel2),
                    ],
                  ),
                  if (bothReady)
                    Positioned(
                      top: 8,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: _toggleSyncPlayPause,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isSyncPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isSyncPlaying ? '동시 정지' : '동시 재생',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              )
            : Column(
                children: [
                  Expanded(child: panel1),
                  const SizedBox(height: 12),
                  Expanded(child: panel2),
                ],
              ),
      ),
    );
  }


}

class _VideoPanel extends StatelessWidget {
  final VideoPlayerController? controller;
  final ClimbingRecord record;
  final bool initialized;
  final String? error;
  final double aspectRatio;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSeek;

  const _VideoPanel({
    required this.controller,
    required this.record,
    required this.initialized,
    this.error,
    required this.aspectRatio,
    required this.onPlayPause,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = DifficultyColor.values.firstWhere(
      (c) => c.name == record.difficultyColor,
      orElse: () => DifficultyColor.white,
    );

    final isCompleted = record.status == 'completed';
    final dateStr = DateFormat('yyyy.MM.dd').format(record.recordedAt);
    final isLightColor = color == DifficultyColor.white || color == DifficultyColor.yellow;

    return Column(
      children: [
        // 기록 정보 라벨
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Color(color.colorValue),
                      shape: BoxShape.circle,
                      border: isLightColor
                          ? Border.all(
                              color: Colors.black.withOpacity(0.15), width: 0.5)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      record.gymName ?? '암장 미지정',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? ReclimColors.success.withOpacity(0.1)
                          : const Color(0xFFFF6B35).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isCompleted ? '완등' : '도전중',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isCompleted
                            ? ReclimColors.success
                            : const Color(0xFFE65100),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    if (record.tags.isNotEmpty)
                      Expanded(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: record.tags.map((tag) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          )).toList(),
                        ),
                      )
                    else
                      const Spacer(),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 영상 영역
        Expanded(
          child: Container(
            color: Colors.black,
            child: Center(
              child: error != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.videocam_off_rounded,
                            size: 36, color: Colors.white38),
                        const SizedBox(height: 6),
                        Text(error!,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                      ],
                    )
                  : !initialized
                      ? const CircularProgressIndicator(color: Colors.white)
                      : controller != null
                          ? AspectRatio(
                              aspectRatio: aspectRatio,
                              child: VideoPlayer(controller!),
                            )
                          : const SizedBox.shrink(),
            ),
          ),
        ),
        // 컨트롤 바
        if (controller != null && initialized)
          _ControlBar(
            controller: controller!,
            onPlayPause: onPlayPause,
            onSeek: onSeek,
          ),
      ],
    );
  }
}

class _ControlBar extends StatefulWidget {
  final VideoPlayerController controller;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSeek;

  const _ControlBar({
    required this.controller,
    required this.onPlayPause,
    required this.onSeek,
  });

  @override
  State<_ControlBar> createState() => _ControlBarState();
}

class _ControlBarState extends State<_ControlBar> {
  bool _isDragging = false;
  double _dragValue = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onVideoUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onVideoUpdate);
    super.dispose();
  }

  void _onVideoUpdate() {
    if (!_isDragging && mounted) {
      setState(() {});
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final value = widget.controller.value;
    final position = value.position;
    final duration = value.duration;
    final durationMs = duration.inMilliseconds.toDouble();
    final positionMs = _isDragging
        ? _dragValue
        : position.inMilliseconds.toDouble().clamp(0, durationMs);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      color: colorScheme.surface,
      child: Row(
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: IconButton(
              onPressed: widget.onPlayPause,
              padding: EdgeInsets.zero,
              icon: Icon(
                value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 24,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            _formatDuration(position),
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurface.withOpacity(0.6),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: colorScheme.primary,
                inactiveTrackColor: colorScheme.outline.withOpacity(0.2),
                thumbColor: colorScheme.primary,
              ),
              child: Slider(
                value: durationMs > 0 ? positionMs / durationMs : 0,
                onChangeStart: (v) {
                  _isDragging = true;
                  _dragValue = v * durationMs;
                },
                onChanged: (v) {
                  setState(() => _dragValue = v * durationMs);
                },
                onChangeEnd: (v) {
                  _isDragging = false;
                  widget.onSeek(
                      Duration(milliseconds: (v * durationMs).toInt()));
                },
              ),
            ),
          ),
          Text(
            _formatDuration(duration),
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurface.withOpacity(0.6),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
