import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_editor_2/video_editor.dart';
import 'package:video_player/video_player.dart';

import 'package:gal/gal.dart';

import '../models/climbing_record.dart';
import '../models/video_edit_models.dart';
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
import '../utils/video_download_cache.dart';
import '../widgets/editor/export_progress_dialog.dart';
import '../widgets/editor/overlay_layer.dart';
import '../widgets/editor/overlay_sticker_sheet.dart';
import '../widgets/editor/editor_tab_bar.dart';
import '../widgets/editor/playback_control_bar.dart';
import '../widgets/editor/subtitle_editor_sheet.dart';
import '../widgets/editor/subtitle_overlay_layer.dart';
import '../widgets/editor/track_label_panel.dart';
import '../widgets/editor/crop_overlay.dart';
import '../widgets/editor/vllo_timeline.dart';
import '../app.dart';
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
  String _title = '제목 없음';
  bool _isEditingTitle = false;
  late final TextEditingController _titleController;
  final FocusNode _titleFocusNode = FocusNode();
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
    _titleController = TextEditingController(text: _title);
    _titleFocusNode.addListener(_onTitleFocusChanged);
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
        // 크롭 줌 구간 초기화 (전체 영상, 전체 영역)
        ref
            .read(cropSegmentsProvider.notifier)
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
      // 재생 중 구간 배속 실시간 적용
      if (_controller.video.value.isPlaying) {
        _applyPlaybackSpeed(pos);
      }
    }
  }

  /// 현재 위치의 구간 배속을 VideoPlayer에 적용
  double _lastAppliedSpeed = 1.0;
  void _applyPlaybackSpeed(Duration pos) {
    final segments = ref.read(speedSegmentsProvider);
    final speed = segments
            .where((s) => pos >= s.start && pos < s.end)
            .firstOrNull
            ?.speed ??
        1.0;
    if (speed != _lastAppliedSpeed) {
      _lastAppliedSpeed = speed;
      _controller.video.setPlaybackSpeed(speed);
    }
  }

  /// 타임라인에서 특정 위치로 seek
  void _seekTo(Duration position) {
    _controller.video.pause();
    _controller.video.seekTo(position);
    setState(() => _currentPosition = position);
  }

  Widget _buildCroppedPreview() {
    final cropSegments = ref.watch(cropSegmentsProvider);
    final currentCrop = cropSegments
        .where((s) => _currentPosition >= s.start && _currentPosition < s.end)
        .firstOrNull;

    if (currentCrop == null || !currentCrop.hasCrop) {
      return VideoPlayer(_controller.video);
    }

    final cr = currentCrop.cropRect;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        alignment: Alignment(
          // -1 to 1 범위로 변환
          (cr.left + cr.width / 2) * 2 - 1,
          (cr.top + cr.height / 2) * 2 - 1,
        ),
        child: SizedBox(
          width: _correctedVideoDimension.width * cr.width,
          height: _correctedVideoDimension.height * cr.height,
          child: Transform.scale(
            scale: 1.0 / cr.width, // 크롭 비율의 역수로 확대
            child: VideoPlayer(_controller.video),
          ),
        ),
      ),
    );
  }


  /// 주어진 위치에 해당하는 크롭 구간 인덱스
  static int? _findCropSegmentAt(
      List<CropSegment> segments, Duration position) {
    for (int i = 0; i < segments.length; i++) {
      if (position >= segments[i].start && position < segments[i].end) {
        return i;
      }
    }
    return null;
  }

  /// 현재 재생 위치의 크롭 구간을 자동 선택
  void _autoSelectCropSegment() {
    final segments = ref.read(cropSegmentsProvider);
    for (int i = 0; i < segments.length; i++) {
      if (_currentPosition >= segments[i].start &&
          _currentPosition < segments[i].end) {
        ref.read(selectedCropSegmentProvider.notifier).state = i;
        return;
      }
    }
  }


  void _togglePlayPause() {
    if (_controller.video.value.isPlaying) {
      _controller.video.pause();
      // 일시정지 시 배속 리셋
      _controller.video.setPlaybackSpeed(1.0);
      _lastAppliedSpeed = 1.0;
    } else {
      // 재생 시작 시 현재 구간 배속 적용
      _applyPlaybackSpeed(_currentPosition);
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
    final segments = ref.read(speedSegmentsProvider);
    final pos = _currentPosition;
    final canSplit = segments.any((seg) =>
        pos > seg.start && pos < seg.end);
    if (!canSplit) {
      // 디버그: 현재 위치와 구간 정보 표시
      final segInfo = segments.map((s) =>
          '${s.start.inMilliseconds}~${s.end.inMilliseconds}ms').join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '분할 불가: 현재 ${pos.inMilliseconds}ms / 구간: $segInfo'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    _withUndo(() {
      ref.read(speedSegmentsProvider.notifier).splitAt(pos);
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
    _titleFocusNode.removeListener(_onTitleFocusChanged);
    _titleFocusNode.dispose();
    _titleController.dispose();
    _controller.video.removeListener(_onVideoPositionChanged);
    _controller.dispose();
    super.dispose();
  }


  /// 내보내기 실행
  /// 내보내기 품질 선택 바텀시트
  Future<ExportQuality?> _showQualityPicker() async {
    return showModalBottomSheet<ExportQuality>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _ExportQualitySheet(),
    );
  }

  Future<void> _handleExport() async {
    if (_isExporting) return;

    // Wi-Fi 미연결 시 사용자 확인 (내보내기 후 업로드 발생)
    final wifiConfirmed = await confirmIfNotWifi(
      context,
      title: '영상 내보내기',
      message: '내보내기 후 영상이 서버에 업로드됩니다.\n\nWi-Fi에 연결되어 있지 않습니다. 모바일 데이터로 진행하시겠습니까?',
      confirmLabel: '진행',
    );
    if (!wifiConfirmed || !mounted) return;

    // 품질 선택
    final quality = await _showQualityPicker();
    if (quality == null || !mounted) return;

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
      final cropSegs = ref.read(cropSegmentsProvider);
      final overlays = ref.read(overlaysProvider);
      final subtitles = ref.read(subtitlesProvider);

      debugPrint('[Export] cropSegs count: ${cropSegs.length}');
      for (int i = 0; i < cropSegs.length; i++) {
        final s = cropSegs[i];
        debugPrint('[Export] cropSeg[$i] hasCrop=${s.hasCrop} '
            'rect=${s.cropRect} start=${s.start} end=${s.end}');
      }

      final result = await VideoExportService.exportVideo(
        inputPath: widget.videoPath,
        trimStart: _controller.startTrim,
        trimEnd: _controller.endTrim,
        speedSegments: segments,
        cropSegments: cropSegs,
        overlays: overlays,
        subtitles: subtitles,
        videoResolution: _correctedVideoDimension,
        quality: quality,
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
          final exportTitle = _title == '제목 없음' ? null : _title;
          final savedExport = await RecordService.saveExport(
            parentRecordId: widget.existingRecord!.id!,
            parentRecord: widget.existingRecord!,
            videoPath: result.outputPath,
            thumbnailPath: thumbnailPath,
            videoDurationSeconds: result.duration.inSeconds,
            memo: exportTitle,
            videoQuality: quality.label,
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

          // 업로드용 압축 후 큐에 등록
          String uploadPath = result.outputPath;
          try {
            uploadPath = await VideoExportService.compressForUpload(
              inputPath: result.outputPath,
            );
            debugPrint('업로드 압축 완료: $uploadPath');
          } catch (e) {
            debugPrint('업로드 압축 실패, 원본 사용: $e');
          }
          ref.read(uploadQueueProvider.notifier).enqueue(
            recordId: savedExport.id!,
            localVideoPath: uploadPath,
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
                videoQuality: quality.label,
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


  @override
  Widget build(BuildContext context) {
    // autoDispose provider를 로딩 중에도 구독하여 초기화 데이터 유지
    final segments = ref.watch(speedSegmentsProvider);
    ref.watch(overlaysProvider);
    ref.watch(cropSegmentsProvider);

    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
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
                        child: selectedTab == EditorTab.zoom
                            // 줌 탭: 제스처는 CropOverlay가 처리
                            ? AspectRatio(
                                aspectRatio: _displayAspectRatio,
                                child: _buildCroppedPreview(),
                              )
                            // 다른 탭: 영상 미리보기용 줌 (내보내기 무관)
                            : InteractiveViewer(
                                minScale: 1.0,
                                maxScale: 5.0,
                                child: AspectRatio(
                                  aspectRatio: _displayAspectRatio,
                                  child: GestureDetector(
                                    onTap: _togglePlayPause,
                                    child: _buildCroppedPreview(),
                                  ),
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
                      // 줌 탭에서는 오버레이/자막 레이어 터치 비활성화
                      // (핀치-줌 제스처가 하위 GestureDetector까지 전달되도록)
                      IgnorePointer(
                        ignoring: selectedTab == EditorTab.zoom,
                        child: Center(
                          child: SizedBox(
                            width: videoWidth,
                            height: videoHeight,
                            child: OverlayLayer(
                              previewSize: videoSize,
                              currentPosition: _currentPosition,
                              onOverlaySelected: () {
                                ref
                                    .read(selectedEditorTabProvider.notifier)
                                    .state = EditorTab.sticker;
                              },
                            ),
                          ),
                        ),
                      ),
                      IgnorePointer(
                        ignoring: selectedTab == EditorTab.zoom,
                        child: Center(
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
                      ),
                      if (selectedTab == EditorTab.zoom)
                        Center(
                          child: SizedBox(
                            width: videoWidth,
                            height: videoHeight,
                            child: CropOverlay(
                              previewSize: videoSize,
                              onTap: _togglePlayPause,
                            ),
                          ),
                        ),

                      // ─── 재생 / 최대화 버튼 (좌하단) ─────
                      Positioned(
                        left: 8,
                        bottom:
                            (constraints.maxHeight - videoHeight) / 2 + 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _VideoOverlayButton(
                              icon: _controller.video.value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              onTap: _togglePlayPause,
                            ),
                            const SizedBox(width: 6),
                            _VideoOverlayButton(
                              icon: Icons.fullscreen_rounded,
                              onTap: _openFullscreen,
                            ),
                          ],
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

  /// 제목 인라인 편집 모드 시작
  void _startEditingTitle() {
    _titleController.text = _title == '제목 없음' ? '' : _title;
    setState(() => _isEditingTitle = true);
    _titleFocusNode.requestFocus();
  }

  /// 제목 편집 확정
  void _commitTitle() {
    final value = _titleController.text.trim();
    setState(() {
      _title = value.isEmpty ? '제목 없음' : value;
      _isEditingTitle = false;
    });
  }

  /// 포커스 해제 시 편집 확정
  void _onTitleFocusChanged() {
    if (!_titleFocusNode.hasFocus && _isEditingTitle) {
      _commitTitle();
    }
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
          // 제목 + 비율 (탭하여 인라인 수정)
          Expanded(
            child: Center(
              child: _isEditingTitle
                  ? IntrinsicWidth(
                      child: TextField(
                        controller: _titleController,
                        focusNode: _titleFocusNode,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          hintText: '제목을 입력하세요',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 14,
                          ),
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white54),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        onSubmitted: (_) => _commitTitle(),
                      ),
                    )
                  : GestureDetector(
                      onTap: _startEditingTitle,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.edit,
                            color: Colors.white54,
                            size: 14,
                          ),
                        ],
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
      case EditorTab.zoom:
        return _buildZoomActions();
      case EditorTab.text:
        return _buildPillAction('텍스트 추가', Icons.add, _showSubtitleEditor);
      case EditorTab.sticker:
        return _buildStickerActions();
    }
  }

  Widget _buildZoomActions() {
    final segments = ref.watch(cropSegmentsProvider);
    final selectedIdx = ref.watch(selectedCropSegmentProvider);
    final idx = selectedIdx ??
        (segments.length == 1
            ? 0
            : _findCropSegmentAt(segments, _currentPosition));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // 분할
          Material(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                final segs = ref.read(cropSegmentsProvider);
                final canSplit = segs.any((s) =>
                    _currentPosition > s.start &&
                    _currentPosition < s.end);
                if (!canSplit) {
                  debugPrint('[Zoom] 분할 불가: position=$_currentPosition, '
                      'segments=${segs.map((s) => '${s.start}-${s.end}').join(', ')}');
                  return;
                }
                _withUndo(() {
                  ref
                      .read(cropSegmentsProvider.notifier)
                      .splitAt(_currentPosition);
                });
                // 분할 후 현재 위치 구간 자동 선택
                _autoSelectCropSegment();
                debugPrint('[Zoom] 분할 완료: position=$_currentPosition, '
                    'segments=${ref.read(cropSegmentsProvider).length}개');
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Row(
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
          ),
          const SizedBox(width: 6),
          // 전환 애니메이션 토글
          if (idx != null && idx < segments.length && idx > 0)
            Material(
              color: segments[idx].animateTransition
                  ? const Color(0xFF7C4DFF).withOpacity(0.8)
                  : Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  _withUndo(() {
                    ref.read(cropSegmentsProvider.notifier).toggleAnimation(
                          idx, !segments[idx].animateTransition);
                  });
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.animation, size: 14, color: Colors.white70),
                      SizedBox(width: 4),
                      Text('전환',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          const Spacer(),
          // 초기화
          if (idx != null && idx < segments.length && segments[idx].hasCrop)
            Material(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  _withUndo(() {
                    ref.read(cropSegmentsProvider.notifier).resetCrop(idx);
                  });
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, size: 14, color: Colors.white70),
                      SizedBox(width: 4),
                      Text('초기화',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStickerActions() {
    final selectedId = ref.watch(selectedOverlayIdProvider);
    final overlays = ref.watch(overlaysProvider);
    final selectedItem = selectedId != null
        ? overlays.where((o) => o.id == selectedId).firstOrNull
        : null;

    if (selectedItem == null) {
      return _buildPillAction('스티커 추가', Icons.add, _showOverlayStickers);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // 크기 조절
          const Icon(Icons.format_size, color: Colors.white54, size: 16),
          Expanded(
            child: SliderTheme(
              data: const SliderThemeData(
                trackHeight: 2,
                thumbShape:
                    RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape:
                    RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: Colors.white70,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: selectedItem.fontSize.clamp(12.0, 96.0),
                min: 12,
                max: 96,
                onChanged: (v) {
                  ref.read(overlaysProvider.notifier).updateOverlay(
                        selectedItem.id,
                        selectedItem.copyWith(fontSize: v),
                      );
                },
              ),
            ),
          ),
          const SizedBox(width: 4),
          // 각도 조절
          const Icon(Icons.rotate_right, color: Colors.white54, size: 16),
          Expanded(
            child: SliderTheme(
              data: const SliderThemeData(
                trackHeight: 2,
                thumbShape:
                    RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape:
                    RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: Colors.white70,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: selectedItem.rotation,
                min: -3.14159,
                max: 3.14159,
                onChanged: (v) {
                  ref.read(overlaysProvider.notifier).updateOverlay(
                        selectedItem.id,
                        selectedItem.copyWith(rotation: v),
                      );
                },
              ),
            ),
          ),
          // 삭제 버튼
          GestureDetector(
            onTap: () {
              ref
                  .read(overlaysProvider.notifier)
                  .removeOverlay(selectedItem.id);
              ref.read(selectedOverlayIdProvider.notifier).state = null;
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child:
                  Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
            ),
          ),
        ],
      ),
    );
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          ...speedOptions.map((speed) {
            final isActive = selectedIdx != null &&
                selectedIdx < segments.length &&
                (segments[selectedIdx].speed - speed).abs() < 0.01;
            final enabled = selectedIdx != null;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Material(
                color: isActive
                    ? _speedColor(speed)
                    : Colors.white
                        .withOpacity(enabled ? 0.12 : 0.05),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: enabled
                      ? () => ref
                          .read(speedSegmentsProvider.notifier)
                          .updateSpeedAndMerge(selectedIdx, speed)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    child: Text(
                      '${speed}x',
                      style: TextStyle(
                        color: isActive
                            ? Colors.white
                            : (enabled
                                ? Colors.white70
                                : Colors.white24),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          Material(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _splitAtCurrent,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Row(
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
    if (speed <= 0.5) return const Color(0x5542A5F5);
    if (speed <= 1.0) return const Color(0x5566BB6A);
    if (speed <= 2.0) return const Color(0x55FFA726);
    return const Color(0x55EF5350);
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
            // 재생/일시정지 버튼 (중앙)
            if (!widget.controller.value.isPlaying)
              Center(
                child: GestureDetector(
                  onTap: () => widget.controller.play(),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 36,
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

// ─── 내보내기 품질 선택 바텀시트 ────────────────────────────

class _ExportQualitySheet extends StatefulWidget {
  const _ExportQualitySheet();

  @override
  State<_ExportQualitySheet> createState() => _ExportQualitySheetState();
}

class _ExportQualitySheetState extends State<_ExportQualitySheet> {
  ExportQuality _selected = ExportQuality.fullHd;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 핸들
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: WandeungColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // 제목
              const Row(
                children: [
                  Icon(Icons.tune, size: 20, color: WandeungColors.textPrimary),
                  SizedBox(width: 8),
                  Text(
                    '내보내기 품질',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: WandeungColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 품질 카드들
              ...ExportQuality.values.map(_buildQualityCard),
              const SizedBox(height: 16),
              // 추출 버튼
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  child: Text(
                    '${_selected.label}로 추출하기',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQualityCard(ExportQuality q) {
    final isSelected = _selected == q;
    final is4K = q == ExportQuality.uhd4k;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selected = q),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? WandeungColors.accent.withOpacity(0.06)
                : WandeungColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? WandeungColors.accent : WandeungColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // 아이콘
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? WandeungColors.accent.withOpacity(0.12)
                      : WandeungColors.border.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  is4K ? Icons.four_k : Icons.hd,
                  size: 22,
                  color: isSelected
                      ? WandeungColors.accent
                      : WandeungColors.textSecondary,
                ),
              ),
              const SizedBox(width: 14),
              // 텍스트
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          q.label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: isSelected
                                ? WandeungColors.accent
                                : WandeungColors.textPrimary,
                          ),
                        ),
                        if (is4K) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: WandeungColors.inProgress.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '고화질',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: WandeungColors.inProgress,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${q.targetHeight}p · 선명한 화질',
                      style: const TextStyle(
                        fontSize: 12,
                        color: WandeungColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              // 라디오 체크
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? WandeungColors.accent : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? WandeungColors.accent
                        : WandeungColors.textTertiary,
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
