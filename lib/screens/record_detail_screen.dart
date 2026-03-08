import 'dart:io';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../config/supabase_config.dart';
import '../models/climbing_record.dart';
import '../utils/constants.dart';
import '../widgets/wandeung_app_bar.dart';
import 'video_editor_screen.dart';

class RecordDetailScreen extends StatefulWidget {
  final ClimbingRecord record;
  final bool autoPlay;
  const RecordDetailScreen({super.key, required this.record, this.autoPlay = false});

  @override
  State<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends State<RecordDetailScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  double? _displayAspectRatio;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final path = widget.record.videoPath;
    if (path == null) return;

    // 절대 경로면 로컬 파일, 아니면 Supabase Storage (구 기록 호환)
    if (path.startsWith('/')) {
      if (!File(path).existsSync()) {
        // 캐시에 저장된 구 기록의 영상이 삭제된 경우
        if (mounted) {
          setState(() {}); // _videoController == null → 영상 없음 표시
        }
        return;
      }
      _videoController = VideoPlayerController.file(File(path));
    } else {
      final url = await SupabaseConfig.client.storage
          .from('climbing-videos')
          .createSignedUrl(path, 3600);
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
    }

    try {
      await _videoController!.initialize().timeout(
        const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('영상 초기화 실패: $e');
      _videoController?.dispose();
      _videoController = null;
      if (mounted) setState(() {});
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

    if (mounted) setState(() {});
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
      appBar: WandeungAppBar(
        title: record.gymName ?? '등반 기록',
        showBackButton: true,
        extraActions: [
          if (record.videoPath != null)
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VideoEditorScreen(
                      videoPath: record.videoPath!,
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 영상 플레이어
            if (_chewieController != null)
              LayoutBuilder(
                builder: (context, constraints) {
                  final maxHeight =
                      MediaQuery.of(context).size.height * 0.5;
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
                      child: AspectRatio(
                        aspectRatio: _displayAspectRatio!,
                        child: Chewie(controller: _chewieController!),
                      ),
                    ),
                  );
                },
              )
            else if (record.videoPath != null &&
                _videoController == null &&
                record.videoPath!.startsWith('/') &&
                !File(record.videoPath!).existsSync())
              Container(
                height: 200,
                color: const Color(0xFFE8ECF0),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam_off_rounded, size: 48,
                          color: colorScheme.onSurface.withOpacity(0.25)),
                      const SizedBox(height: 8),
                      Text('영상 파일이 삭제되었습니다',
                          style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.4))),
                    ],
                  ),
                ),
              )
            else if (record.videoPath != null)
              const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
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
                              ? const Color(0xFF14B8A6).withOpacity(0.1)
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
                                  ? const Color(0xFF0D9488)
                                  : const Color(0xFFE65100),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isCompleted ? '완등' : '도전중',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isCompleted
                                    ? const Color(0xFF0D9488)
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
    );
  }
}
