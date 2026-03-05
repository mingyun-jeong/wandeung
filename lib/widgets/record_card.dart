import 'dart:io';
import 'package:flutter/material.dart';
import '../models/climbing_record.dart';
import '../screens/record_detail_screen.dart';
import '../utils/constants.dart';

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
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => RecordDetailScreen(record: record)),
        ),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // 썸네일 또는 난이도 뱃지
              _buildThumbnailOrBadge(color),
              const SizedBox(width: 14),
              // 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.gymName ?? '암장 미지정',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _StatusBadge(isCompleted: isCompleted),
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
              // 비디오 아이콘
              if (record.videoPath != null)
                Icon(
                  Icons.play_circle_outline_rounded,
                  color: colorScheme.onSurface.withOpacity(0.25),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailOrBadge(DifficultyColor color) {
    if (record.thumbnailPath != null &&
        File(record.thumbnailPath!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Image.file(
            File(record.thumbnailPath!),
            width: 46,
            height: 46,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _GradeBadge(
              grade: record.grade,
              color: color,
            ),
          ),
        ),
      );
    }
    return _GradeBadge(grade: record.grade, color: color);
  }
}

class _GradeBadge extends StatelessWidget {
  final String grade;
  final DifficultyColor color;
  const _GradeBadge({required this.grade, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Color(color.colorValue),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color(color.colorValue).withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          grade.toUpperCase(),
          style: TextStyle(
            color: color == DifficultyColor.white
                ? Colors.black87
                : Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isCompleted;
  const _StatusBadge({required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFFEAF5EC) : const Color(0xFFFFF3E0),
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
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isCompleted
              ? const Color(0xFF2E7D32)
              : const Color(0xFFE65100),
        ),
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
