import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/video_editor_provider.dart';

/// 속도 구간별 인터랙티브 타임라인
class SpeedSegmentTimeline extends ConsumerWidget {
  final Duration totalDuration;
  final Duration currentPosition;
  final VoidCallback onSplit;

  const SpeedSegmentTimeline({
    super.key,
    required this.totalDuration,
    required this.currentPosition,
    required this.onSplit,
  });

  static const _speedOptions = [0.5, 1.0, 2.0, 4.0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segments = ref.watch(speedSegmentsProvider);
    final rawSelectedIdx = ref.watch(selectedSpeedSegmentProvider);
    // 구간이 하나뿐이면 자동 선택
    final selectedIdx =
        rawSelectedIdx ?? (segments.length == 1 ? 0 : null);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 상단: 속도 버튼 + 분할 버튼
          Row(
            children: [
              ..._speedOptions.map((speed) {
                final isActive = selectedIdx != null &&
                    selectedIdx < segments.length &&
                    (segments[selectedIdx].speed - speed).abs() < 0.01;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: selectedIdx != null
                        ? () {
                            ref
                                .read(speedSegmentsProvider.notifier)
                                .updateSpeedAndMerge(selectedIdx, speed);
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive
                            ? _speedColor(speed)
                            : Colors.white.withOpacity(
                                selectedIdx != null ? 0.15 : 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isActive
                              ? _speedColor(speed)
                              : Colors.white24,
                        ),
                      ),
                      child: Text(
                        '${speed}x',
                        style: TextStyle(
                          color: isActive
                              ? Colors.white
                              : (selectedIdx != null
                                  ? Colors.white70
                                  : Colors.white24),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const Spacer(),
              // 분할 버튼
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSplit,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.content_cut, size: 16, color: Colors.white70),
                      SizedBox(width: 4),
                      Text(
                        '분할',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 타임라인 바
          SizedBox(
            height: 48,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trackWidth = constraints.maxWidth;
                final totalMs = totalDuration.inMilliseconds.toDouble();

                if (segments.isEmpty || totalMs <= 0) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  );
                }

                return Stack(
                  children: [
                    // 배경
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    // 구간 블록들
                    ...List.generate(segments.length, (i) {
                      final seg = segments[i];
                      final leftFrac = seg.start.inMilliseconds / totalMs;
                      final widthFrac =
                          seg.originalDuration.inMilliseconds / totalMs;
                      final isSelected = i == selectedIdx;

                      return Positioned(
                        left: leftFrac * trackWidth,
                        width: (widthFrac * trackWidth).clamp(20.0, trackWidth),
                        top: 2,
                        bottom: 2,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            ref
                                .read(selectedSpeedSegmentProvider.notifier)
                                .state = (selectedIdx == i) ? null : i;
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: _speedColor(seg.speed)
                                  .withOpacity(isSelected ? 0.9 : 0.5),
                              borderRadius: BorderRadius.circular(4),
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 2)
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${seg.speed}x',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSelected ? 14 : 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    // 경계선 드래그 핸들
                    if (segments.length > 1) ...List.generate(segments.length - 1, (i) {
                      final boundary = segments[i].end;
                      final leftFrac = boundary.inMilliseconds / totalMs;

                      return Positioned(
                        left: leftFrac * trackWidth - 8,
                        width: 16,
                        top: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onHorizontalDragUpdate: (details) {
                            final deltaMs =
                                (details.delta.dx / trackWidth * totalMs)
                                    .round();
                            final newPos = Duration(
                              milliseconds:
                                  boundary.inMilliseconds + deltaMs,
                            );
                            ref
                                .read(speedSegmentsProvider.notifier)
                                .moveBoundary(i, newPos);
                          },
                          child: MouseRegion(
                            cursor: SystemMouseCursors.resizeColumn,
                            child: Center(
                              child: Container(
                                width: 4,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white70,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    // 재생 위치 인디케이터
                    Positioned(
                      left: totalMs > 0
                          ? (currentPosition.inMilliseconds / totalMs) *
                                  trackWidth -
                              1
                          : 0,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 2, color: Colors.white),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static Color _speedColor(double speed) {
    if (speed <= 0.5) return const Color(0xFF42A5F5);
    if (speed <= 1.0) return const Color(0xFF66BB6A);
    if (speed <= 2.0) return const Color(0xFFFFA726);
    return const Color(0xFFEF5350);
  }
}
