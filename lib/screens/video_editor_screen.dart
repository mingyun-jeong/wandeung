import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_editor_2/video_editor.dart';
import 'package:video_player/video_player.dart';

import 'package:gal/gal.dart';

import '../models/climbing_record.dart';
import '../models/subtitle_item.dart';
import '../providers/editor_history_provider.dart';
import '../providers/record_provider.dart';
import '../providers/subtitle_provider.dart';
import '../providers/upload_queue_provider.dart';
import '../providers/video_editor_provider.dart';
import '../services/video_export_service.dart';
import '../services/video_upload_service.dart';
import '../utils/thumbnail_utils.dart';
import '../utils/timeline_thumbnail_utils.dart';
import '../widgets/editor/export_progress_dialog.dart';
import '../widgets/editor/overlay_layer.dart';
import '../widgets/editor/overlay_sticker_sheet.dart';
import '../widgets/editor/editor_tab_bar.dart';
import '../widgets/editor/playback_control_bar.dart';
import '../widgets/editor/subtitle_editor_sheet.dart';
import '../widgets/editor/subtitle_overlay_layer.dart';
import '../widgets/editor/track_label_panel.dart';
import '../widgets/editor/vllo_timeline.dart';
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
  List<String> _timelineThumbnails = [];

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

        _controller.video.setLooping(false);
        setState(() => _isInitialized = true);
        // 배속 구간 초기화 (전체 영상, 1x)
        ref
            .read(speedSegmentsProvider.notifier)
            .initWithFullRange(_controller.videoDuration);
        _controller.video.addListener(_onVideoPositionChanged);

        // 타임라인 썸네일 비동기 생성
        _generateThumbnails();
      }
    });
  }

  Future<void> _generateThumbnails() async {
    final thumbs = await generateTimelineThumbnails(
      videoPath: widget.videoPath,
      totalDuration: _controller.videoDuration,
    );
    if (mounted && thumbs.isNotEmpty) {
      setState(() => _timelineThumbnails = thumbs);
    }
  }

  void _onVideoPositionChanged() {
    final pos = _controller.video.value.position;
    if (!mounted) return;

    // 트림 끝 지점 또는 영상 끝에 도달하면 자동 정지
    if (_controller.video.value.isPlaying && pos >= _controller.endTrim) {
      _controller.video.pause();
      _controller.video.seekTo(_controller.endTrim);
      setState(() => _currentPosition = _controller.endTrim);
      return;
    }

    if (pos != _currentPosition) {
      setState(() => _currentPosition = pos);
    }
  }

  /// 타임라인에서 특정 위치로 seek
  void _seekTo(Duration position) {
    _controller.video.pause();
    _controller.video.seekTo(position);
    setState(() => _currentPosition = position);
  }

  void _togglePlayPause() {
    if (_controller.video.value.isPlaying) {
      _controller.video.pause();
    } else {
      _controller.video.play();
    }
  }

  /// 약 1/30초(≈33ms) 앞으로 이동
  void _stepForward() {
    final newPos = _currentPosition + const Duration(milliseconds: 33);
    final maxPos = _controller.videoDuration;
    _seekTo(newPos > maxPos ? maxPos : newPos);
  }

  /// 약 1/30초(≈33ms) 뒤로 이동
  void _stepBackward() {
    final newPos = _currentPosition - const Duration(milliseconds: 33);
    _seekTo(newPos < Duration.zero ? Duration.zero : newPos);
  }

  void _jumpToStart() => _seekTo(_controller.startTrim);

  void _jumpToEnd() => _seekTo(_controller.endTrim);

  // ─── Undo 래핑: 편집 전에 스냅샷 저장 ──────────────
  void _withUndo(void Function() action) {
    ref.read(editorHistoryProvider.notifier).saveSnapshot();
    action();
  }

  // ─── 빠른 편집 액션 ────────────────────────────────
  void _trimFromStart() {
    _withUndo(() {
      _controller.updateTrim(_currentPosition.inMilliseconds /
          _controller.videoDuration.inMilliseconds, _controller.maxTrim);
    });
  }

  void _trimFromHere() {
    _withUndo(() {
      _controller.updateTrim(_currentPosition.inMilliseconds /
          _controller.videoDuration.inMilliseconds, _controller.maxTrim);
    });
  }

  void _trimToHere() {
    _withUndo(() {
      _controller.updateTrim(_controller.minTrim,
          _currentPosition.inMilliseconds /
              _controller.videoDuration.inMilliseconds);
    });
  }

  void _trimToEnd() {
    _withUndo(() {
      _controller.updateTrim(_controller.minTrim,
          _currentPosition.inMilliseconds /
              _controller.videoDuration.inMilliseconds);
    });
  }

  void _splitAtCurrent() {
    _withUndo(() {
      ref.read(speedSegmentsProvider.notifier).splitAt(_currentPosition);
    });
  }

  void _openFullscreen() {
    _controller.video.pause();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenVideoPage(
          controller: _controller.video,
          aspectRatio: _displayAspectRatio,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.video.removeListener(_onVideoPositionChanged);
    _controller.dispose();
    super.dispose();
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

  void _showOverlayStickers() {
    _controller.video.pause();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => OverlayStickerSheet(
        currentPosition: _currentPosition,
        videoDuration: _controller.videoDuration,
      ),
    );
  }

  void _showSubtitleEditor({SubtitleItem? existingItem}) {
    _controller.video.pause();
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

  Widget _buildUndoRedo() {
    final history = ref.watch(editorHistoryProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: history.canUndo
              ? () => ref.read(editorHistoryProvider.notifier).undo()
              : null,
          icon: Icon(
            Icons.undo_rounded,
            color: history.canUndo ? Colors.white70 : Colors.white24,
            size: 20,
          ),
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          onPressed: history.canRedo
              ? () => ref.read(editorHistoryProvider.notifier).redo()
              : null,
          icon: Icon(
            Icons.redo_rounded,
            color: history.canRedo ? Colors.white70 : Colors.white24,
            size: 20,
          ),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  /// 비율 텍스트 (9:16, 16:9 등)
  String get _aspectRatioLabel {
    if (_displayAspectRatio < 1) {
      const w = 9;
      const h = 16;
      return '$w:$h';
    }
    const w = 16;
    const h = 9;
    return '$w:$h';
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
    final currentSpeed = segments
            .where((s) =>
                _currentPosition >= s.start && _currentPosition < s.end)
            .firstOrNull
            ?.speed ??
        1.0;
    final selectedTab = ref.watch(selectedEditorTabProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ─── VLLO 스타일 상단 바 ─────────────────
            _buildVlloAppBar(),

            // ─── 영상 프리뷰 + 오버레이 (flex 3) ─────
            Expanded(
              flex: 3,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double videoWidth;
                  final double videoHeight;
                  if (constraints.maxWidth / constraints.maxHeight >
                      _displayAspectRatio) {
                    videoHeight = constraints.maxHeight;
                    videoWidth = videoHeight * _displayAspectRatio;
                  } else {
                    videoWidth = constraints.maxWidth;
                    videoHeight = videoWidth / _displayAspectRatio;
                  }
                  final videoSize = Size(videoWidth, videoHeight);

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(
                        child: AspectRatio(
                          aspectRatio: _displayAspectRatio,
                          child: GestureDetector(
                            onTap: _togglePlayPause,
                            child: VideoPlayer(_controller.video),
                          ),
                        ),
                      ),
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
                      Center(
                        child: SizedBox(
                          width: videoWidth,
                          height: videoHeight,
                          child: OverlayLayer(
                            previewSize: videoSize,
                            currentPosition: _currentPosition,
                          ),
                        ),
                      ),
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
                      // ─── 재생 / 최대화 버튼 (좌하단) ─────
                      Positioned(
                        left: 8,
                        bottom:
                            (constraints.maxHeight - videoHeight) / 2 + 8,
                        child: _VideoOverlayButton(
                          icon: Icons.fullscreen_rounded,
                          onTap: _openFullscreen,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // ─── VLLO 스타일 컴팩트 재생 바 ──────────
            PlaybackControlBar(
              currentPosition: _currentPosition,
              totalDuration: _controller.endTrim - _controller.startTrim,
              isPlaying: _controller.video.value.isPlaying,
              onPlayPause: _togglePlayPause,
              onStepForward: _stepForward,
              onStepBackward: _stepBackward,
              onJumpToStart: _jumpToStart,
              onJumpToEnd: _jumpToEnd,
            ),

            // ─── 트림 슬라이더 (트림 탭 선택 시) ─────
            // Visibility로 감싸서 GlobalKey 충돌 방지
            // (TrimSlider 내부의 GlobalKey가 트리에서 제거/재생성 시 충돌)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: TrimSlider(
                controller: _controller,
                height: 50,
                child: TrimTimeline(
                  controller: _controller,
                  padding: const EdgeInsets.only(top: 10),
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
              ),
            ),

            // ─── VLLO 멀티트랙 타임라인 (flex 2) ─────
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  // 좌측 트랙 라벨
                  const TrackLabelPanel(),
                  // 우측 스크롤 타임라인
                  Expanded(
                    child: VlloTimeline(
                      effectiveStart: _controller.startTrim,
                      effectiveDuration:
                          _controller.endTrim - _controller.startTrim,
                      currentPosition: _currentPosition,
                      thumbnailPaths: _timelineThumbnails,
                      onSeek: _seekTo,
                      onSplit: _splitAtCurrent,
                      onAddText: () => _showSubtitleEditor(),
                      onEditText: (sub) =>
                          _showSubtitleEditor(existingItem: sub),
                      onAddSticker: _showOverlayStickers,
                    ),
                  ),
                ],
              ),
            ),

            // ─── 탭별 컨텍스트 액션 바 (고정 높이) ────
            SizedBox(
              height: 40,
              child: _buildContextActionBar(selectedTab),
            ),

            // ─── VLLO 스타일 하단 필 버튼 탭 ─────────
            const EditorTabBar(),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  /// VLLO 스타일 상단 바: ← 제목 (비율) undo/redo [추출하기]
  Widget _buildVlloAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          // 제목 + 비율
          Expanded(
            child: Center(
              child: Text(
                '제목 없음 ($_aspectRatioLabel)',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          // Undo/Redo
          _buildUndoRedo(),
          // 추출하기 (내보내기)
          FilledButton.icon(
            onPressed: _isExporting ? null : _handleExport,
            icon: const Icon(Icons.file_upload_outlined, size: 16),
            label: const Text('추출하기', style: TextStyle(fontSize: 12)),
            style: FilledButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  /// 선택된 탭에 따른 컨텍스트 액션 바
  Widget _buildContextActionBar(EditorTab tab) {
    switch (tab) {
      case EditorTab.trim:
        return _buildTrimActions();
      case EditorTab.speed:
        return _buildSpeedActions();
      case EditorTab.text:
        return _buildPillAction('텍스트 추가', Icons.add, _showSubtitleEditor);
      case EditorTab.sticker:
        return _buildPillAction('스티커 추가', Icons.add, _showOverlayStickers);
    }
  }

  Widget _buildTrimActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionPill('처음부터', Icons.first_page_rounded, _trimFromStart),
          _ActionPill('여기부터', Icons.arrow_right_alt_rounded, _trimFromHere),
          _ActionPill('분할', Icons.content_cut_rounded, _splitAtCurrent,
              highlighted: true),
          _ActionPill('여기까지', Icons.arrow_left_rounded, _trimToHere),
          _ActionPill('끝까지', Icons.last_page_rounded, _trimToEnd),
        ],
      ),
    );
  }

  Widget _buildSpeedActions() {
    final segments = ref.watch(speedSegmentsProvider);
    final rawSelectedIdx = ref.watch(selectedSpeedSegmentProvider);
    final selectedIdx =
        rawSelectedIdx ?? (segments.length == 1 ? 0 : null);

    const speedOptions = [0.5, 1.0, 2.0, 4.0];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          ...speedOptions.map((speed) {
            final isActive = selectedIdx != null &&
                selectedIdx < segments.length &&
                (segments[selectedIdx].speed - speed).abs() < 0.01;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: selectedIdx != null
                    ? () => ref
                        .read(speedSegmentsProvider.notifier)
                        .updateSpeedAndMerge(selectedIdx, speed)
                    : null,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? _speedColor(speed)
                        : Colors.white
                            .withOpacity(selectedIdx != null ? 0.12 : 0.05),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${speed}x',
                    style: TextStyle(
                      color: isActive
                          ? Colors.white
                          : (selectedIdx != null
                              ? Colors.white70
                              : Colors.white24),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          GestureDetector(
            onTap: _splitAtCurrent,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.content_cut, size: 14, color: Colors.white70),
                  SizedBox(width: 4),
                  Text('분할',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillAction(
      String label, IconData icon, VoidCallback onTap) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: Colors.white70),
                const SizedBox(width: 4),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Color _speedColor(double speed) {
    if (speed <= 0.5) return const Color(0xFF42A5F5);
    if (speed <= 1.0) return const Color(0xFF66BB6A);
    if (speed <= 2.0) return const Color(0xFFFFA726);
    return const Color(0xFFEF5350);
  }
}

/// 컨텍스트 액션 바의 개별 버튼
class _ActionPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool highlighted;

  const _ActionPill(this.label, this.icon, this.onTap,
      {this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    final color = onTap != null
        ? (highlighted ? Colors.white : Colors.white70)
        : Colors.white24;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 영상 프리뷰 위 오버레이 버튼 (재생/최대화)
class _VideoOverlayButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _VideoOverlayButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

/// 전체 화면 영상 재생 페이지
class _FullscreenVideoPage extends StatefulWidget {
  final VideoPlayerController controller;
  final double aspectRatio;

  const _FullscreenVideoPage({
    required this.controller,
    required this.aspectRatio,
  });

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    widget.controller.pause();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          if (widget.controller.value.isPlaying) {
            widget.controller.pause();
          } else {
            widget.controller.play();
          }
        },
        child: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: widget.aspectRatio,
                child: VideoPlayer(widget.controller),
              ),
            ),
            // 닫기 버튼
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
