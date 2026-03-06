import 'dart:io';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../config/supabase_config.dart';
import '../models/climbing_record.dart';
import '../utils/constants.dart';
import 'video_editor_screen.dart';

class RecordDetailScreen extends StatefulWidget {
  final ClimbingRecord record;
  const RecordDetailScreen({super.key, required this.record});

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
      autoPlay: false,
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
      appBar: AppBar(
        title: Text(
          record.gymName ?? '등반 기록',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
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
                color: Colors.grey.shade200,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam_off, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('영상 파일이 삭제되었습니다',
                          style: TextStyle(color: Colors.grey)),
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
                  // 난이도 + 색상 + 상태
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Color(color.colorValue),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Color(color.colorValue).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            record.grade.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: color == DifficultyColor.white
                                  ? Colors.black87
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            color.korean,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            record.grade.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurface.withOpacity(0.45),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? const Color(0xFFEAF5EC)
                              : const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isCompleted
                                ? const Color(0xFFA5D6A7)
                                : const Color(0xFFFFCC80),
                          ),
                        ),
                        child: Text(
                          isCompleted ? '완등' : '도전중',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isCompleted
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFE65100),
                          ),
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
