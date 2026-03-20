import 'dart:io';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:video_player/video_player.dart';
import '../config/r2_config.dart';
import '../models/climbing_record.dart';
import '../providers/record_provider.dart';
import '../providers/upload_queue_provider.dart';
import '../utils/constants.dart';
import '../utils/video_download_cache.dart';
import '../widgets/climpick_app_bar.dart';
import 'video_compare_screen.dart';
import 'video_editor_screen.dart';
import '../widgets/record_select_bottom_sheet.dart';
import '../app.dart';

class RecordDetailScreen extends ConsumerStatefulWidget {
  final ClimbingRecord record;
  final bool autoPlay;
  const RecordDetailScreen({super.key, required this.record, this.autoPlay = false});

  @override
  ConsumerState<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends ConsumerState<RecordDetailScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  double? _displayAspectRatio;
  bool _videoInitDone = false;
  bool _videoFileMissing = false;

  @override
  void initState() {
    super.initState();
    final path = widget.record.videoPath;
    if (path != null && path.startsWith('/') && !File(path).existsSync()) {
      _videoFileMissing = true;
      _videoInitDone = true;
    } else {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    final path = widget.record.videoPath;
    if (path == null) return;

    // 절대 경로면 로컬 파일, 아니면 Supabase Storage (구 기록 호환)
    if (path.startsWith('/')) {
      if (!File(path).existsSync()) {
        if (mounted) {
          setState(() {
            _videoFileMissing = true;
            _videoInitDone = true;
          });
        }
        return;
      }
      _videoController = VideoPlayerController.file(File(path));
    } else {
      final url = R2Config.getPresignedUrl(path);
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
    }

    try {
      await _videoController!.initialize();
    } catch (e) {
      debugPrint('영상 초기화 실패: $e');
      _videoController?.dispose();
      _videoController = null;
      if (mounted) setState(() => _videoInitDone = true);
      return;
    }

    // 세로 촬영 영상의 회전 메타데이터를 반영한 비율 계산
    final size = _videoController!.value.size;
    final rotation = _videoController!.value.rotationCorrection;
    if (size.width > 0 && size.height > 0 && (rotation == 90 || rotation == 270)) {
      _displayAspectRatio = size.height / size.width;
    } else {
      _displayAspectRatio = _videoController!.value.aspectRatio;
    }

    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      aspectRatio: _displayAspectRatio,
      autoPlay: widget.autoPlay,
      looping: false,
      allowFullScreen: true,
      allowedScreenSleep: false,
      deviceOrientationsOnEnterFullScreen: [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitUp,
      ],
      deviceOrientationsAfterFullScreen: [
        DeviceOrientation.portraitUp,
      ],
    );

    if (mounted) setState(() => _videoInitDone = true);
  }

  bool _saving = false;

  Future<void> _saveVideoToGallery(String videoPath, bool isLocal) async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      String localPath;
      if (isLocal) {
        if (!File(videoPath).existsSync()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('영상 파일을 찾을 수 없습니다')),
            );
          }
          return;
        }
        localPath = videoPath;
      } else {
        final downloaded =
            await downloadRemoteVideoWithDialog(context, videoPath);
        if (downloaded == null) return;
        localPath = downloaded;
      }

      await Gal.putVideo(localPath, album: '클림픽');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('갤러리에 저장되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장에 실패했습니다')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final colorScheme = Theme.of(context).colorScheme;
    final color = DifficultyColor.values.firstWhere(
      (c) => c.name == record.difficultyColor,
      orElse: () => DifficultyColor.white,
    );
    final isCompleted = record.status == 'completed';

    return Scaffold(
      appBar: ClimpickAppBar(
        title: record.gymName ?? '등반 기록',
        showBackButton: true,
        extraActions: [
          if (record.videoPath != null)
            TextButton.icon(
              onPressed: () async {
                final selectedRecord = await showRecordSelectBottomSheet(
                  context,
                  excludeRecordId: record.id,
                );
                if (selectedRecord == null || !context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VideoCompareScreen(
                      record1: record,
                      record2: selectedRecord,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.compare_arrows, size: 18),
              label: const Text('비교모드', style: TextStyle(fontSize: 13)),
            ),
          if (record.videoPath != null && !record.isLocalVideo && !record.localOnly)
            IconButton(
              onPressed: _saving
                  ? null
                  : () => _saveVideoToGallery(
                        record.videoPath!,
                        record.isLocalVideo,
                      ),
              icon: Icon(
                _saving
                    ? Icons.hourglass_top_rounded
                    : Icons.download_rounded,
              ),
              tooltip: '갤러리에 저장',
            ),
          if (record.videoPath != null)
            IconButton(
              onPressed: () async {
                final videoPath = record.videoPath!;
                String localPath;

                if (record.isLocalVideo) {
                  if (!File(videoPath).existsSync()) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('영상 파일을 찾을 수 없습니다')),
                      );
                    }
                    return;
                  }
                  localPath = videoPath;
                } else {
                  final downloaded = await downloadRemoteVideoWithDialog(context, videoPath);
                  if (downloaded == null) return;
                  localPath = downloaded;
                }

                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VideoEditorScreen(
                      videoPath: localPath,
                      existingRecord: record,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.edit),
              tooltip: '편집',
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 영상 플레이어
            if (record.videoPath != null && _videoFileMissing)
              Container(
                height: 240,
                color: const Color(0xFFE8ECF0),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam_off_rounded, size: 48,
                          color: colorScheme.onSurface.withOpacity(0.25)),
                      const SizedBox(height: 8),
                      Text('영상 파일을 찾을 수 없습니다.\n촬영 영상은 기기에만 저장되므로,\n파일 삭제·이동 또는 다른 기기에서\n로그인한 경우 재생할 수 없습니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.4))),
                    ],
                  ),
                ),
              )
            else if (record.videoPath != null && _chewieController != null)
              LayoutBuilder(
                builder: (context, constraints) {
                  final maxHeight =
                      MediaQuery.of(context).size.height * 0.7;
                  final naturalHeight =
                      constraints.maxWidth / _displayAspectRatio!;
                  final playerHeight =
                      naturalHeight > maxHeight ? maxHeight : naturalHeight;

                  return SizedBox(
                    width: double.infinity,
                    height: playerHeight,
                    child: Container(
                      color: Colors.black,
                      alignment: Alignment.center,
                      child: Chewie(controller: _chewieController!),
                    ),
                  );
                },
              )
            else if (record.videoPath != null && !_videoInitDone)
              const SizedBox(
                width: double.infinity,
                child: ColoredBox(
                  color: Colors.black,
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

            // 로컬 영상 업로드 버튼
            if (record.isLocalVideo &&
                record.id != null &&
                !_videoFileMissing)
              Builder(builder: (context) {
                final uploadStatus =
                    ref.watch(uploadStatusProvider(record.id!));
                if (uploadStatus != null) return const SizedBox.shrink();
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ref.read(uploadQueueProvider.notifier).enqueue(
                              recordId: record.id!,
                              localVideoPath: record.videoPath!,
                            );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('업로드 대기열에 추가됨')),
                        );
                      },
                      icon: const Icon(Icons.cloud_upload, size: 18),
                      label: const Text('서버에 업로드'),
                    ),
                  ),
                );
              }),

            // 내보내기 영상 목록
            if (record.id != null)
              _ExportedVideosSection(
                parentRecordId: record.id!,
                onSave: _saveVideoToGallery,
                saving: _saving,
              ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(color.colorValue),
                              Color(color.colorValue).withOpacity(0.85),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Color(color.colorValue).withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const SizedBox.shrink(),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            color.korean,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? ClimpickColors.success.withOpacity(0.1)
                              : const Color(0xFFFF6B35).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isCompleted
                                  ? Icons.check_circle_rounded
                                  : Icons.sports_kabaddi_rounded,
                              size: 16,
                              color: isCompleted
                                  ? ClimpickColors.success
                                  : const Color(0xFFE65100),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isCompleted ? '완등' : '도전중',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isCompleted
                                    ? ClimpickColors.success
                                    : const Color(0xFFE65100),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (record.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Divider(
                          height: 1,
                          color: colorScheme.outline.withOpacity(0.15)),
                    ),

                  // 태그
                  if (record.tags.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      '태그',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface.withOpacity(0.4),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: record.tags
                          .map((tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest
                                      .withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colorScheme.onSurface
                                        .withOpacity(0.7),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _ExportedVideosSection extends ConsumerWidget {
  final String parentRecordId;
  final Future<void> Function(String videoPath, bool isLocal) onSave;
  final bool saving;

  const _ExportedVideosSection({
    required this.parentRecordId,
    required this.onSave,
    required this.saving,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncExports = ref.watch(exportedRecordsProvider(parentRecordId));
    return asyncExports.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (exports) {
        if (exports.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                '내보내기 영상',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.4),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              ...exports
                  .where((export) => !export.isLocalVideo && !export.localOnly)
                  .map((export) {
                final hasVideo = export.videoPath != null;
                final label = export.memo ?? '내보내기 영상';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: !hasVideo || saving
                          ? null
                          : () => onSave(
                                export.videoPath!,
                                export.isLocalVideo,
                              ),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }
}
