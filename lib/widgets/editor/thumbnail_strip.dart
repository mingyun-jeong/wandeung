import 'dart:io';
import 'package:flutter/material.dart';

/// 타임라인 배경에 표시할 영상 프레임 필름스트립
class ThumbnailStrip extends StatelessWidget {
  final List<String> thumbnailPaths;
  final double height;

  const ThumbnailStrip({
    super.key,
    required this.thumbnailPaths,
    this.height = 36,
  });

  @override
  Widget build(BuildContext context) {
    if (thumbnailPaths.isEmpty) {
      return SizedBox(
        height: height,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Row(
          children: thumbnailPaths.map((path) {
            return Expanded(
              child: Image.file(
                File(path),
                fit: BoxFit.cover,
                height: height,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
