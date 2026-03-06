import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/subtitle_item.dart';
import '../../providers/subtitle_provider.dart';

/// 자막 전용 타임라인 트랙 — 각 자막이 시간 구간에 해당하는 블록으로 표시
/// 블록 양쪽 끝을 드래그하여 시간 구간 조절 가능
class SubtitleTimelineTrack extends ConsumerWidget {
  final Duration totalDuration;
  final Duration currentPosition;
  final void Function(SubtitleItem) onSubtitleTap;

  const SubtitleTimelineTrack({
    super.key,
    required this.totalDuration,
    required this.currentPosition,
    required this.onSubtitleTap,
  });

  /// 최소 자막 길이 (밀리초)
  static const _minDurationMs = 300;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitles = ref.watch(subtitlesProvider);
    final selectedId = ref.watch(selectedSubtitleIdProvider);

    if (subtitles.isEmpty) {
      return const SizedBox(height: 36);
    }

    final totalMs = totalDuration.inMilliseconds.toDouble();

    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackWidth = constraints.maxWidth;
          return Stack(
            children: [
              // 배경
              Container(
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // 자막 블록들
              ...subtitles.map((sub) {
                final leftFrac = sub.startTime.inMilliseconds / totalMs;
                final widthFrac =
                    (sub.endTime - sub.startTime).inMilliseconds / totalMs;
                final isSelected = sub.id == selectedId;
                final blockLeft = leftFrac * trackWidth;
                final blockWidth =
                    (widthFrac * trackWidth).clamp(16.0, trackWidth);

                return Positioned(
                  left: blockLeft,
                  width: blockWidth,
                  top: 2,
                  bottom: 2,
                  child: _SubtitleBlock(
                    sub: sub,
                    isSelected: isSelected,
                    trackWidth: trackWidth,
                    totalMs: totalMs,
                    onTap: () {
                      ref.read(selectedSubtitleIdProvider.notifier).state =
                          sub.id;
                      onSubtitleTap(sub);
                    },
                    onStartDrag: (deltaDx) {
                      final deltaMs = (deltaDx / trackWidth * totalMs).round();
                      final newStart = Duration(
                        milliseconds: (sub.startTime.inMilliseconds + deltaMs)
                            .clamp(0, sub.endTime.inMilliseconds - _minDurationMs),
                      );
                      ref.read(subtitlesProvider.notifier).updateSubtitle(
                            sub.id,
                            sub.copyWith(startTime: newStart),
                          );
                    },
                    onEndDrag: (deltaDx) {
                      final deltaMs = (deltaDx / trackWidth * totalMs).round();
                      final newEnd = Duration(
                        milliseconds: (sub.endTime.inMilliseconds + deltaMs)
                            .clamp(
                              sub.startTime.inMilliseconds + _minDurationMs,
                              totalDuration.inMilliseconds,
                            ),
                      );
                      ref.read(subtitlesProvider.notifier).updateSubtitle(
                            sub.id,
                            sub.copyWith(endTime: newEnd),
                          );
                    },
                  ),
                );
              }),
              // 재생 위치 인디케이터
              Positioned(
                left: (currentPosition.inMilliseconds / totalMs) * trackWidth -
                    1,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 2,
                  color: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 드래그 가능한 양쪽 핸들이 있는 자막 블록
class _SubtitleBlock extends StatelessWidget {
  final SubtitleItem sub;
  final bool isSelected;
  final double trackWidth;
  final double totalMs;
  final VoidCallback onTap;
  final void Function(double deltaDx) onStartDrag;
  final void Function(double deltaDx) onEndDrag;

  static const _handleWidth = 10.0;

  const _SubtitleBlock({
    required this.sub,
    required this.isSelected,
    required this.trackWidth,
    required this.totalMs,
    required this.onTap,
    required this.onStartDrag,
    required this.onEndDrag,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 본체 (탭으로 선택/편집)
        Positioned.fill(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.blue.withOpacity(0.8)
                    : Colors.amber.withOpacity(0.6),
                borderRadius: BorderRadius.circular(3),
                border: isSelected
                    ? Border.all(color: Colors.white, width: 1)
                    : null,
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                sub.text,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        // 왼쪽 핸들 (시작 시간 조절)
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: _handleWidth,
          child: GestureDetector(
            onHorizontalDragUpdate: (d) => onStartDrag(d.delta.dx),
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.4)
                      : Colors.transparent,
                  borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(3)),
                ),
                child: isSelected
                    ? const Center(
                        child: Icon(Icons.drag_handle,
                            size: 10, color: Colors.white70),
                      )
                    : null,
              ),
            ),
          ),
        ),
        // 오른쪽 핸들 (끝 시간 조절)
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: _handleWidth,
          child: GestureDetector(
            onHorizontalDragUpdate: (d) => onEndDrag(d.delta.dx),
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.4)
                      : Colors.transparent,
                  borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(3)),
                ),
                child: isSelected
                    ? const Center(
                        child: Icon(Icons.drag_handle,
                            size: 10, color: Colors.white70),
                      )
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
