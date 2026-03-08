import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_editor_2/video_editor.dart';
import 'package:video_player/video_player.dart';

import 'package:gal/gal.dart';

import '../models/climbing_record.dart';
import '../models/subtitle_item.dart';
import '../providers/record_provider.dart';
import '../providers/subtitle_provider.dart';
import '../providers/video_editor_provider.dart';
import '../services/custom_font_service.dart';
import '../services/video_export_service.dart';
import '../utils/thumbnail_utils.dart';
import '../widgets/editor/export_progress_dialog.dart';
import '../widgets/editor/overlay_layer.dart';
import '../widgets/editor/overlay_sticker_sheet.dart';
import '../widgets/editor/speed_picker_sheet.dart';
import '../widgets/editor/speed_segment_bar.dart';
import '../widgets/editor/subtitle_editor_sheet.dart';
import '../widgets/editor/subtitle_overlay_layer.dart';
import '../widgets/editor/subtitle_timeline_track.dart';
import 'record_save_screen.dart';

/// 비디오 편집 화면
///
/// 촬영 후 또는 기존 기록에서 진입하여 트림/배속/오버레이 편집 후 내보내기
class VideoEditorScreen extends ConsumerStatefulWidget {
  final String videoPath;
  final ClimbingRecord? existingRecord;

  const VideoEditorScreen({
    super.key,
    required this.videoPath,
    this.existingRecord,
  });

  @override
  ConsumerState<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends ConsumerState<VideoEditorScreen> {
  late VideoEditorController _controller;
  bool _isInitialized = false;
  bool _isExporting = false;
  Duration _currentPosition = Duration.zero;
  double _displayAspectRatio = 16 / 9;
  bool _isRotationCorrected = false;

  /// 회전 보정된 영상 해상도 (FFmpeg export용)
  Size get _correctedVideoDimension {
    final dim = _controller.videoDimension;
    if (_isRotationCorrected) {
      return Size(dim.height, dim.width);
    }
    return dim;
  }

  @override
  void initState() {
    super.initState();
    _controller = VideoEditorController.file(
      XFile(widget.videoPath),
      minDuration: Duration.zero,
      maxDuration: const Duration(minutes: 10),
    );
    _controller.initialize().then((_) {
      if (mounted) {
        // 회전 보정된 비율 계산
        final size = _controller.video.value.size;
        final rotation = _controller.video.value.rotationCorrection;
        if (size.width > 0 &&
            size.height > 0 &&
            (rotation == 90 || rotation == 270)) {
          _displayAspectRatio = size.height / size.width;
          _isRotationCorrected = true;
        } else {
          _displayAspectRatio = _controller.video.value.aspectRatio;
        }

        setState(() => _isInitialized = true);
        // 배속 구간 초기화 (전체 영상, 1x)
        ref
            .read(speedSegmentsProvider.notifier)
            .initWithFullRange(_controller.videoDuration);
        _controller.video.addListener(_onVideoPositionChanged);
        // 기본 폰트 에셋 복사
        CustomFontService.ensureDefaultFonts();
      }
    });
  }

  void _onVideoPositionChanged() {
    final pos = _controller.video.value.position;
    if (mounted && pos != _currentPosition) {
      setState(() => _currentPosition = pos);
    }
  }

  @override
  void dispose() {
    _controller.video.removeListener(_onVideoPositionChanged);
    _controller.dispose();
    super.dispose();
  }

  /// 편집 없이 원본 그대로 저장 화면으로 이동
  void _skipEditing() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RecordSaveScreen(videoPath: widget.videoPath),
      ),
    );
  }

  /// 내보내기 실행
  Future<void> _handleExport() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    // 진행률 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ExportProgressDialog(),
    );

    try {
      final segments = ref.read(speedSegmentsProvider);
      final overlays = ref.read(overlaysProvider);
      final subtitles = ref.read(subtitlesProvider);

      // 기본 폰트 준비 및 경로 확인
      await CustomFontService.ensureDefaultFonts();
      final fontPath = await _getFontPath();

      final result = await VideoExportService.exportVideo(
        inputPath: widget.videoPath,
        trimStart: _controller.startTrim,
        trimEnd: _controller.endTrim,
        speedSegments: segments,
        overlays: overlays,
        subtitles: subtitles,
        videoResolution: _correctedVideoDimension,
        fontPath: fontPath,
        onProgress: (progress) {
          ref.read(exportProgressProvider.notifier).state = progress;
        },
      );

      if (mounted) {
        Navigator.pop(context); // 다이얼로그 닫기

        // 내보내기 결과 영상 플레이어 표시
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => _ExportPreviewScreen(videoPath: result.outputPath),
          ),
        );

        if (!mounted) return;

        if (widget.existingRecord != null) {
          // 기존 기록 편집 → 내보내기 영상을 자식 레코드로 저장
          try {
            await Gal.putVideo(result.outputPath, album: '완등');
          } catch (_) {}
          final thumbnailPath = await generateThumbnail(result.outputPath);
          await RecordService.saveExport(
            parentRecordId: widget.existingRecord!.id!,
            parentRecord: widget.existingRecord!,
            videoPath: result.outputPath,
            thumbnailPath: thumbnailPath,
            videoDurationSeconds: result.duration.inSeconds,
          );
          if (mounted) {
            ref.invalidate(
                exportedRecordsProvider(widget.existingRecord!.id!));
            Navigator.pop(context, true); // RecordSaveScreen으로 복귀
          }
        } else {
          // 신규 촬영 → 저장 화면으로 이동
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => RecordSaveScreen(
                videoPath: result.outputPath,
                originalVideoPath: widget.videoPath,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 다이얼로그 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('내보내기 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
        ref.read(exportProgressProvider.notifier).state = null;
      }
    }
  }

  /// 번들 폰트 경로 반환 (없으면 null)
  Future<String?> _getFontPath() async {
    return CustomFontService.getDefaultFontPath();
  }

  void _showSpeedPicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) => const SpeedPickerSheet(),
    );
  }

  void _showOverlayStickers() {
    showModalBottomSheet(
      context: context,
      builder: (_) => const OverlayStickerSheet(),
    );
  }

  void _showSubtitleEditor({SubtitleItem? existingItem}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubtitleEditorSheet(
        currentPosition: _currentPosition,
        videoDuration: _controller.videoDuration,
        existingItem: existingItem,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final segments = ref.watch(speedSegmentsProvider);
    final currentSpeed =
        segments.isNotEmpty ? segments.first.speed : 1.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ─── 상단 바 ──────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 뒤로가기
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Text(
                    '편집',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  // 건너뛰기 / 내보내기
                  Row(
                    children: [
                      TextButton(
                        onPressed: _skipEditing,
                        child: const Text(
                          '건너뛰기',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(width: 4),
                      FilledButton(
                        onPressed: _isExporting ? null : _handleExport,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ),
                        child: const Text('내보내기'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ─── 영상 프리뷰 + 오버레이 ──────────────
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // 비디오 프리뷰 (회전 보정 적용)
                      Center(
                        child: AspectRatio(
                          aspectRatio: _displayAspectRatio,
                          child: GestureDetector(
                            onTap: () {
                              if (_controller.video.value.isPlaying) {
                                _controller.video.pause();
                              } else {
                                _controller.video.play();
                              }
                            },
                            child: VideoPlayer(_controller.video),
                          ),
                        ),
                      ),

                      // 배속 표시 배지
                      if (currentSpeed != 1.0)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${currentSpeed}x',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),

                      // 드래그 가능한 오버레이 레이어
                      Positioned.fill(
                        child: OverlayLayer(
                          previewSize: Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          ),
                        ),
                      ),

                      // Text 오버레이 레이어
                      Positioned.fill(
                        child: SubtitleOverlayLayer(
                          previewSize: Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          ),
                          currentPosition: _currentPosition,
                          onSubtitleTap: () {
                            final selectedId =
                                ref.read(selectedSubtitleIdProvider);
                            if (selectedId != null) {
                              final sub = ref
                                  .read(subtitlesProvider)
                                  .where((s) => s.id == selectedId)
                                  .firstOrNull;
                              if (sub != null) {
                                _showSubtitleEditor(existingItem: sub);
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // ─── 배속 구간 바 ─────────────────────────
            SpeedSegmentBar(
              segments: segments,
              totalDuration: _controller.videoDuration,
            ),

            // ─── 자막 타임라인 트랙 ─────────────────────
            SubtitleTimelineTrack(
              totalDuration: _controller.videoDuration,
              currentPosition: _currentPosition,
              onSubtitleTap: (sub) => _showSubtitleEditor(existingItem: sub),
            ),

            // ─── 트림 슬라이더 ────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  TrimSlider(
                    controller: _controller,
                    height: 60,
                    child: TrimTimeline(
                      controller: _controller,
                      padding: const EdgeInsets.only(top: 10),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ─── 하단 툴바 ───────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ToolbarButton(
                    icon: Icons.speed,
                    label: '속도',
                    badge: currentSpeed != 1.0
                        ? '${currentSpeed}x'
                        : null,
                    onTap: _showSpeedPicker,
                  ),
                  _ToolbarButton(
                    icon: Icons.emoji_emotions,
                    label: '스티커',
                    onTap: _showOverlayStickers,
                  ),
                  _ToolbarButton(
                    icon: Icons.title,
                    label: '텍스트',
                    badge: ref.watch(subtitlesProvider).isNotEmpty
                        ? '${ref.watch(subtitlesProvider).length}'
                        : null,
                    onTap: () => _showSubtitleEditor(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// 하단 툴바 버튼
class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              if (badge != null)
                Positioned(
                  top: -6,
                  right: -12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// 내보내기 결과 영상 미리보기 화면
class _ExportPreviewScreen extends StatefulWidget {
  final String videoPath;
  const _ExportPreviewScreen({required this.videoPath});

  @override
  State<_ExportPreviewScreen> createState() => _ExportPreviewScreenState();
}

class _ExportPreviewScreenState extends State<_ExportPreviewScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller.play();
        }
      });
    _controller.addListener(_onPlayerStateChanged);
  }

  void _onPlayerStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onPlayerStateChanged);
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final min = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 바
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48),
                  const Text(
                    '내보내기 완료',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // 영상 플레이어
            Expanded(
              child: Center(
                child: _initialized
                    ? GestureDetector(
                        onTap: () {
                          _controller.value.isPlaying
                              ? _controller.pause()
                              : _controller.play();
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AspectRatio(
                              aspectRatio: _controller.value.aspectRatio,
                              child: VideoPlayer(_controller),
                            ),
                            if (!_controller.value.isPlaying)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(12),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 48,
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      )
                    : const CircularProgressIndicator(color: Colors.white),
              ),
            ),

            // 재생 진행 바
            if (_initialized) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      _formatDuration(_controller.value.position),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 12),
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: Colors.white,
                        ),
                        child: Slider(
                          value: _controller.value.duration.inMilliseconds > 0
                              ? _controller.value.position.inMilliseconds /
                                  _controller.value.duration.inMilliseconds
                              : 0.0,
                          onChanged: (v) {
                            final pos = Duration(
                              milliseconds:
                                  (v * _controller.value.duration.inMilliseconds)
                                      .round(),
                            );
                            _controller.seekTo(pos);
                          },
                        ),
                      ),
                    ),
                    Text(
                      _formatDuration(_controller.value.duration),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],

            // 확인 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text(
                    '확인',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
