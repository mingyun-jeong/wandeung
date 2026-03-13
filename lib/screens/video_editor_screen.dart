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
import '../providers/upload_queue_provider.dart';
import '../providers/video_editor_provider.dart';
import '../services/video_export_service.dart';
import '../services/video_upload_service.dart';
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
    ref.read(exportStatusProvider.notifier).state = ExportStatus.exporting;
    ref.read(exportProgressProvider.notifier).state = null;

    // 바텀시트 표시
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ExportProgressSheet(
        onCancel: () async {
          await VideoExportService.cancelExport();
        },
        onResume: () {
          // 바텀시트 닫고 내보내기 재시작
          Navigator.pop(sheetContext);
          _handleExport();
        },
        onClose: () {
          Navigator.pop(sheetContext);
        },
      ),
    );

    try {
      final segments = ref.read(speedSegmentsProvider);
      final overlays = ref.read(overlaysProvider);
      final subtitles = ref.read(subtitlesProvider);

      final result = await VideoExportService.exportVideo(
        inputPath: widget.videoPath,
        trimStart: _controller.startTrim,
        trimEnd: _controller.endTrim,
        speedSegments: segments,
        overlays: overlays,
        subtitles: subtitles,
        videoResolution: _correctedVideoDimension,
        onProgress: (progress) {
          ref.read(exportProgressProvider.notifier).state = progress;
        },
      );

      if (mounted) {
        ref.read(exportStatusProvider.notifier).state =
            ExportStatus.completed;

        // 완료 후 잠시 보여주고 바텀시트 닫기
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        Navigator.pop(context); // 바텀시트 닫기

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('내보내기가 완료되었습니다'),
            behavior: SnackBarBehavior.floating,
          ),
        );

        if (widget.existingRecord != null) {
          // 기존 기록 편집 → 내보내기 영상을 자식 레코드로 저장
          try {
            await Gal.putVideo(result.outputPath, album: '완등');
          } catch (_) {}
          final thumbnailPath = await generateThumbnail(result.outputPath);
          final savedExport = await RecordService.saveExport(
            parentRecordId: widget.existingRecord!.id!,
            parentRecord: widget.existingRecord!,
            videoPath: result.outputPath,
            thumbnailPath: thumbnailPath,
            videoDurationSeconds: result.duration.inSeconds,
          );

          // 썸네일 즉시 R2 업로드
          if (thumbnailPath != null) {
            try {
              await VideoUploadService.uploadThumbnailAndUpdateRecord(
                recordId: savedExport.id!,
                localThumbnailPath: thumbnailPath,
                userId: savedExport.userId,
              );
            } catch (e) {
              debugPrint('내보내기 썸네일 업로드 실패: $e');
            }
          }

          // 영상은 업로드 큐에 등록 (Wi-Fi 설정에 따라 처리)
          ref.read(uploadQueueProvider.notifier).enqueue(
            recordId: savedExport.id!,
            localVideoPath: result.outputPath,
          );

          if (mounted) {
            ref.invalidate(
                exportedRecordsProvider(widget.existingRecord!.id!));
            Navigator.pop(context, true); // 기록 페이지로 복귀
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
    } on ExportCancelledException {
      if (mounted) {
        ref.read(exportStatusProvider.notifier).state =
            ExportStatus.cancelled;
        ref.read(exportProgressProvider.notifier).state = null;
      }
    } catch (e) {
      if (mounted) {
        ref.read(exportStatusProvider.notifier).state = ExportStatus.error;
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
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
                  // AspectRatio 위젯이 실제로 차지하는 크기 계산
                  final double videoWidth;
                  final double videoHeight;
                  if (constraints.maxWidth / constraints.maxHeight >
                      _displayAspectRatio) {
                    // 세로가 꽉 차고 좌우 여백
                    videoHeight = constraints.maxHeight;
                    videoWidth = videoHeight * _displayAspectRatio;
                  } else {
                    // 가로가 꽉 차고 상하 여백
                    videoWidth = constraints.maxWidth;
                    videoHeight = videoWidth / _displayAspectRatio;
                  }
                  final videoSize = Size(videoWidth, videoHeight);

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
                      Center(
                        child: SizedBox(
                          width: videoWidth,
                          height: videoHeight,
                          child: OverlayLayer(
                            previewSize: videoSize,
                          ),
                        ),
                      ),

                      // Text 오버레이 레이어
                      Center(
                        child: SizedBox(
                          width: videoWidth,
                          height: videoHeight,
                          child: SubtitleOverlayLayer(
                            previewSize: videoSize,
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
