import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/video_editor_provider.dart';

/// 크롭 줌 구간 타임라인 트랙
class CropTimelineTrack extends ConsumerWidget {
  final double trackHeight;
  final double totalWidth;
  final Duration totalDuration;

  const CropTimelineTrack({
    super.key,
    required this.trackHeight,
    required this.totalWidth,
    required this.totalDuration,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segments = ref.watch(cropSegmentsProvider);
    final selectedIdx = ref.watch(selectedCropSegmentProvider);
    final totalMs = totalDuration.inMilliseconds.toDouble();

    if (segments.isEmpty || totalMs <= 0) {
      return SizedBox(height: trackHeight, width: totalWidth);
    }

    return SizedBox(
      height: trackHeight,
      width: totalWidth,
      child: Stack(
        children: [
          // 배경
          Container(
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          // 구간 블록들
          ...List.generate(segments.length, (i) {
            final seg = segments[i];
            final leftFrac = seg.start.inMilliseconds / totalMs;
            final widthFrac = seg.originalDuration.inMilliseconds / totalMs;
            final isSelected = i == selectedIdx ||
                (selectedIdx == null && segments.length == 1);
            final hasCrop = seg.hasCrop;

            return Positioned(
              left: leftFrac * totalWidth,
              width: (widthFrac * totalWidth).clamp(16.0, totalWidth),
              top: 2,
              bottom: 2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  ref.read(selectedCropSegmentProvider.notifier).state =
                      (selectedIdx == i) ? null : i;
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: (hasCrop
                            ? const Color(0xFF7C4DFF)
                            : Colors.white24)
                        .withOpacity(isSelected ? 0.9 : 0.5),
                    borderRadius: BorderRadius.circular(3),
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 1.5)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: hasCrop
                      ? const Icon(Icons.crop, size: 12, color: Colors.white70)
                      : null,
                ),
              ),
            );
          }),
          // 경계선 드래그 핸들
          if (segments.length > 1)
            ...List.generate(segments.length - 1, (i) {
              final boundary = segments[i].end;
              final leftFrac = boundary.inMilliseconds / totalMs;

              return Positioned(
                left: leftFrac * totalWidth - 8,
                width: 16,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    final deltaMs =
                        (details.delta.dx / totalWidth * totalMs).round();
                    final newPos = Duration(
                      milliseconds: boundary.inMilliseconds + deltaMs,
                    );
                    ref
                        .read(cropSegmentsProvider.notifier)
                        .moveBoundary(i, newPos);
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeColumn,
                    child: Center(
                      child: Container(
                        width: 3,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white70,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
