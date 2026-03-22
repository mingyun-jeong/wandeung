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
import '../config/supabase_config.dart';
import '../models/user_subscription.dart';
import '../providers/subscription_provider.dart';
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

  /// 타임라인 드래그 중 seek 쓰로틀링
  bool _isSeeking = false;
  Duration? _pendingSeekPosition;
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
        // 미디어 세그먼트 초기화 (전체 영상, 단일 구간)
        ref
            .read(mediaSegmentsProvider.notifier)
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
      // 재생 중 삭제된 미디어 구간 스킵
      if (_controller.video.value.isPlaying) {
        final skipTo = _skipDeletedSegment(pos);
        if (skipTo != null) {
          // 다음 유효 구간이 트림 끝을 넘으면 정지
          if (skipTo >= _controller.endTrim) {
            _controller.video.pause();
            _controller.video.seekTo(_controller.endTrim);
            setState(() => _currentPosition = _controller.endTrim);
            return;
          }
          _controller.video.seekTo(skipTo);
          setState(() => _currentPosition = skipTo);
          return;
        }
        // 재생 중 구간 배속 실시간 적용
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

  /// 타임라인에서 특정 위치로 seek (쓰로틀링 적용)
  void _seekTo(Duration position) {
    _controller.video.pause();
    setState(() => _currentPosition = position);

    if (_isSeeking) {
      // 이전 seek이 아직 진행 중이면 대기열에 저장
      _pendingSeekPosition = position;
      return;
    }

    _isSeeking = true;
    _controller.video.seekTo(position).then((_) {
      if (!mounted) return;
      _isSeeking = false;

      // 대기 중인 seek이 있으면 마지막 위치로 이동
      if (_pendingSeekPosition != null) {
        final pending = _pendingSeekPosition!;
        _pendingSeekPosition = null;
        _seekTo(pending);
      }
    });
  }

  /// 전환 애니메이션 지속시간 (FFmpeg export의 transitionDurationSec와 동일)
  static const _cropTransitionDuration = Duration(milliseconds: 300);

  Widget _buildCroppedPreview() {
    final cropSegments = ref.watch(cropSegmentsProvider);

    // 현재 위치의 구간 인덱스 찾기
    int? currentIdx;
    for (int i = 0; i < cropSegments.length; i++) {
      if (_currentPosition >= cropSegments[i].start &&
          _currentPosition < cropSegments[i].end) {
        currentIdx = i;
        break;
      }
    }

    if (currentIdx == null) return VideoPlayer(_controller.video);

    final currentCrop = cropSegments[currentIdx];
    Rect cr = currentCrop.cropRect;

    // animateTransition이면 구간 시작 0.3초 동안 이전 구간에서 보간
    if (currentCrop.animateTransition && currentIdx > 0) {
      final elapsed = _currentPosition - currentCrop.start;
      if (elapsed < _cropTransitionDuration) {
        final t = elapsed.inMilliseconds / _cropTransitionDuration.inMilliseconds;
        // easeOut 커브 적용
        final curved = Curves.easeOut.transform(t.clamp(0.0, 1.0));
        final prevRect = cropSegments[currentIdx - 1].cropRect;
        cr = Rect.fromLTWH(
          _lerpDouble(prevRect.left, cr.left, curved),
          _lerpDouble(prevRect.top, cr.top, curved),
          _lerpDouble(prevRect.width, cr.width, curved),
          _lerpDouble(prevRect.height, cr.height, curved),
        );
      }
    }

    // 다음 구간이 animateTransition이면 구간 끝 0.3초 동안 다음 구간으로 보간
    if (currentIdx + 1 < cropSegments.length &&
        cropSegments[currentIdx + 1].animateTransition) {
      final remaining = currentCrop.end - _currentPosition;
      if (remaining < _cropTransitionDuration) {
        final t = 1.0 -
            remaining.inMilliseconds / _cropTransitionDuration.inMilliseconds;
        final curved = Curves.easeIn.transform(t.clamp(0.0, 1.0));
        final nextRect = cropSegments[currentIdx + 1].cropRect;
        cr = Rect.fromLTWH(
          _lerpDouble(cr.left, nextRect.left, curved),
          _lerpDouble(cr.top, nextRect.top, curved),
          _lerpDouble(cr.width, nextRect.width, curved),
          _lerpDouble(cr.height, nextRect.height, curved),
        );
      }
    }

    if (!_hasCrop(cr)) return VideoPlayer(_controller.video);

    return _buildCropTransform(cr);
  }

  static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;

  static bool _hasCrop(Rect cr) =>
      cr.left != 0 || cr.top != 0 || cr.width != 1 || cr.height != 1;

  Widget _buildCropTransform(Rect cr) {
    final alignX = cr.width >= 1.0
        ? 0.0
        : (cr.left / (1.0 - cr.width)) * 2.0 - 1.0;
    final alignY = cr.height >= 1.0
        ? 0.0
        : (cr.top / (1.0 - cr.height)) * 2.0 - 1.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final containerW = constraints.maxWidth;
        final containerH = constraints.maxHeight;

        final cropAR = (cr.width * _correctedVideoDimension.width) /
            (cr.height * _correctedVideoDimension.height);
        final containerAR = containerW / containerH;

        final double scale;
        if (cropAR > containerAR) {
          scale = 1.0 / cr.height;
        } else {
          scale = 1.0 / cr.width;
        }

        return ClipRect(
          child: OverflowBox(
            maxWidth: containerW * scale,
            maxHeight: containerH * scale,
            alignment: Alignment(alignX, alignY),
            child: VideoPlayer(_controller.video),
          ),
        );
      },
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


  /// "완료" 버튼 — 삭제된 구간을 확정하고 선택 해제
  void _applyMediaEdits() {
    // 선택 해제
    ref.read(selectedMediaSegmentProvider.notifier).state = null;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('미디어 편집이 적용되었습니다'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// 현재 위치가 삭제된 미디어 세그먼트에 있으면 다음 유효 구간으로 점프
  Duration? _skipDeletedSegment(Duration pos) {
    final segments = ref.read(mediaSegmentsProvider);
    if (segments.isEmpty) return null;

    // 현재 위치가 삭제된 세그먼트인지 확인
    for (final seg in segments) {
      if (seg.isDeleted && pos >= seg.start && pos < seg.end) {
        // 다음 유효(삭제되지 않은) 세그먼트 찾기
        final nextActive = segments
            .where((s) => !s.isDeleted && s.start >= seg.end)
            .toList();
        if (nextActive.isNotEmpty) {
          return nextActive.first.start;
        }
        // 뒤에 유효 구간이 없으면 재생 정지 위치 반환
        final lastActive = segments.where((s) => !s.isDeleted).lastOrNull;
        return lastActive?.end ?? pos;
      }
    }
    return null; // 스킵 불필요
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

  void _showStorageFullSheet(int currentUsage) {
    final usedMB = currentUsage / 1024 / 1024;
    final limitMB = freeStorageLimitBytes / 1024 / 1024;
    final ratio = (currentUsage / freeStorageLimitBytes).clamp(0.0, 1.0);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 32,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '저장 공간이 부족해요',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '클라우드 저장 공간을 모두 사용했어요.\n기존 영상을 삭제하면 공간을 확보할 수 있어요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('사용량',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                Text(
                  '${usedMB.toStringAsFixed(1)} MB / ${limitMB.toStringAsFixed(0)} MB',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: const Color(0xFFF0F0F0),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFFEF4444)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      )),
    );
  }

  /// 내보내기 실행
  Future<void> _handleExport() async {
    if (_isExporting) return;

    // 로컬 전용이 아닌 경우에만 Wi-Fi 미연결 시 사용자 확인
    final isLocalOnly = widget.existingRecord?.localOnly ?? false;
    if (!isLocalOnly) {
      final wifiConfirmed = await confirmIfNotWifi(
        context,
        title: '영상 내보내기',
        message: '내보내기 후 영상이 서버에 업로드됩니다.\n\nWi-Fi에 연결되어 있지 않습니다. 모바일 데이터로 진행하시겠습니까?',
        confirmLabel: '진행',
      );
      if (!wifiConfirmed || !mounted) return;
    }

    // Free 티어 클라우드 용량 체크
    if (!isLocalOnly) {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId != null) {
        final tier = ref.read(subscriptionTierProvider);
        if (tier == SubscriptionTier.free) {
          final currentUsage =
              await VideoUploadService.getCloudUsage(userId);
          if (currentUsage >= freeStorageLimitBytes) {
            if (mounted) _showStorageFullSheet(currentUsage);
            return;
          }
        }
      }
    }

    const quality = ExportQuality.original;

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

      final mediaSegs = ref.read(mediaSegmentsProvider);

      final result = await VideoExportService.exportVideo(
        inputPath: widget.videoPath,
        trimStart: _controller.startTrim,
        trimEnd: _controller.endTrim,
        speedSegments: segments,
        cropSegments: cropSegs,
        overlays: overlays,
        subtitles: subtitles,
        mediaSegments: mediaSegs,
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
            await Gal.putVideo(result.outputPath, album: '리클림');
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

          // 로컬 전용이 아닌 경우에만 업로드 큐 등록
          if (!isLocalOnly) {
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
              isExport: true,
            );
          }

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
    ref.watch(mediaSegmentsProvider);

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
                            // 줌 탭: 원본 전체 영상 표시 + CropOverlay가 제스처 처리
                            ? AspectRatio(
                                aspectRatio: _displayAspectRatio,
                                child: VideoPlayer(_controller.video),
                              )
                            // 다른 탭: 크롭 적용된 프리뷰 + 확대/축소 가능
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

  void _splitMediaAtCurrent() {
    final segments = ref.read(mediaSegmentsProvider);
    final pos = _currentPosition;
    final canSplit = segments.any((seg) =>
        !seg.isDeleted && pos > seg.start && pos < seg.end &&
        (pos - seg.start).inMilliseconds >= 200 &&
        (seg.end - pos).inMilliseconds >= 200);
    if (!canSplit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이 위치에서 분할할 수 없습니다'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    _withUndo(() {
      ref.read(mediaSegmentsProvider.notifier).splitAt(pos);
    });
  }

  void _deleteSelectedMediaSegment() {
    final selectedId = ref.read(selectedMediaSegmentProvider);
    if (selectedId == null) return;
    _withUndo(() {
      ref.read(mediaSegmentsProvider.notifier).toggleDelete(selectedId);
    });
  }

  void _restoreSelectedMediaSegment() {
    final selectedId = ref.read(selectedMediaSegmentProvider);
    if (selectedId == null) return;
    _withUndo(() {
      ref.read(mediaSegmentsProvider.notifier).restore(selectedId);
    });
  }

  Widget _buildTrimActions() {
    final mediaSegments = ref.watch(mediaSegmentsProvider);
    final selectedId = ref.watch(selectedMediaSegmentProvider);
    final selectedSeg = selectedId != null
        ? mediaSegments.where((s) => s.id == selectedId).firstOrNull
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // 분할 버튼 (항상 표시)
          Material(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _splitMediaAtCurrent,
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
          // 세그먼트 선택 시: 삭제 또는 복구
          if (selectedSeg != null) ...[
            if (selectedSeg.isDeleted)
              Material(
                color: Colors.green.withOpacity(0.3),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _restoreSelectedMediaSegment,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.restore, size: 14, color: Colors.white70),
                        SizedBox(width: 4),
                        Text('복구',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              )
            else
              Material(
                color: Colors.redAccent.withOpacity(0.3),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _deleteSelectedMediaSegment,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline, size: 14, color: Colors.white70),
                        SizedBox(width: 4),
                        Text('삭제',
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
          const Spacer(),
          // 완료 버튼 — 삭제된 구간이 있을 때만 표시
          if (mediaSegments.any((s) => s.isDeleted))
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _applyMediaEdits,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 14, color: Colors.black),
                      SizedBox(width: 4),
                      Text('완료',
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
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

