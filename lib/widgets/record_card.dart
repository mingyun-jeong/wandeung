import 'dart:io';
import 'package:flutter/material.dart';
import '../config/r2_config.dart';
import '../models/climbing_record.dart';
import '../screens/record_save_screen.dart';
import '../screens/video_playback_screen.dart';
import '../utils/constants.dart';
import 'upload_status_indicator.dart';
import '../app.dart';

class RecordCard extends StatelessWidget {
  final ClimbingRecord record;
  const RecordCard({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = DifficultyColor.values.firstWhere(
      (c) => c.name == record.difficultyColor,
      orElse: () => DifficultyColor.white,
    );
    final isCompleted = record.status == 'completed';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => RecordSaveScreen(existingRecord: record)),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              _buildThumbnailOrBadge(color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.gymName ?? '암장 미지정',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        _StatusBadge(isCompleted: isCompleted),
                        _DifficultyBadge(color: color),
                        ...record.tags.map((tag) => _TagBadge(
                              tag: tag,
                              colorScheme: colorScheme,
                            )),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (record.videoPath != null)
                GestureDetector(
                  onTap: () {
                    final path = record.videoPath!;
                    if (path.startsWith('/') && !File(path).existsSync()) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('영상 파일을 찾을 수 없습니다. 촬영 영상은 기기에만 저장되므로, 파일을 삭제했거나 다른 기기에서 로그인한 경우 재생할 수 없습니다.'),
                        ),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            VideoPlaybackScreen(videoPath: path),
                      ),
                    );
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: colorScheme.primary,
                      size: 22,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailOrBadge(DifficultyColor color) {
    final path = record.thumbnailPath;
    if (path == null) return _GradeBadge(color: color);

    final isLocal = path.startsWith('/');
    final hasLocal = isLocal && File(path).existsSync();
    final isRemote = !isLocal;

    if (hasLocal || isRemote) {
      final imageWidget = isLocal
          ? Image.file(
              File(path),
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _GradeBadge(color: color),
            )
          : Image.network(
              R2Config.getPresignedUrl(path),
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _GradeBadge(color: color),
            );

      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageWidget,
              if (record.id != null)
                Positioned(
                  left: 2,
                  top: 2,
                  child: UploadStatusIndicator(
                    recordId: record.id!,
                    isLocalVideo: record.isLocalVideo,
                    localOnly: record.localOnly,
                  ),
                ),
              if (record.videoDurationSeconds != null)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: _DurationBadge(
                      seconds: record.videoDurationSeconds!),
                ),
            ],
          ),
        ),
      );
    }
    return _GradeBadge(color: color);
  }
}

class _GradeBadge extends StatelessWidget {
  final DifficultyColor color;
  const _GradeBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    final baseColor = Color(color.colorValue);
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor,
            baseColor.withOpacity(0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: baseColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const SizedBox.shrink(),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isCompleted;
  const _StatusBadge({required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isCompleted
            ? WandeungColors.success.withOpacity(0.1)
            : const Color(0xFFFF6B35).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isCompleted ? '완등' : '도전중',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isCompleted
              ? WandeungColors.success
              : const Color(0xFFE65100),
        ),
      ),
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  final DifficultyColor color;
  const _DifficultyBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    final baseColor = Color(color.colorValue);
    final isLight = color == DifficultyColor.white || color == DifficultyColor.yellow;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: baseColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: baseColor.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: baseColor,
              shape: BoxShape.circle,
              border: isLight
                  ? Border.all(color: Colors.black.withOpacity(0.15), width: 0.5)
                  : null,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            color.korean,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isLight ? Colors.black87 : baseColor.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagBadge extends StatelessWidget {
  final String tag;
  final ColorScheme colorScheme;
  const _TagBadge({required this.tag, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 11,
          color: colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
    );
  }
}

class _QualityBadge extends StatelessWidget {
  final String quality;
  const _QualityBadge({required this.quality});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        quality,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
      ),
    );
  }
}

class _DurationBadge extends StatelessWidget {
  final int seconds;
  const _DurationBadge({required this.seconds});

  @override
  Widget build(BuildContext context) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    final label = '$minutes:${secs.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
      ),
    );
  }
}
