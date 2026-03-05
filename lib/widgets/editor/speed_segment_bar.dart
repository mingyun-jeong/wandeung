import 'package:flutter/material.dart';

import '../../models/video_edit_models.dart';

/// 타임라인 위 배속 구간 색상 표시 바
class SpeedSegmentBar extends StatelessWidget {
  final List<SpeedSegment> segments;
  final Duration totalDuration;

  const SpeedSegmentBar({
    super.key,
    required this.segments,
    required this.totalDuration,
  });

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty || totalDuration.inMilliseconds == 0) {
      return const SizedBox(height: 6);
    }

    return Container(
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Row(
          children: segments.map((seg) {
            final fraction = seg.originalDuration.inMilliseconds /
                totalDuration.inMilliseconds;
            return Expanded(
              flex: (fraction * 1000).round().clamp(1, 1000),
              child: Container(
                color: _speedColor(seg.speed),
                margin: segments.length > 1
                    ? const EdgeInsets.symmetric(horizontal: 0.5)
                    : EdgeInsets.zero,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Color _speedColor(double speed) {
    if (speed < 0.75) return const Color(0xFF42A5F5); // 슬로우 — 파랑
    if (speed > 1.5) return const Color(0xFFEF5350); // 빠름 — 빨강
    return const Color(0xFF66BB6A); // 일반 — 초록
  }
}
