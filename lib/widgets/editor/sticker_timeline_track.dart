import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/video_edit_models.dart';
import '../../providers/video_editor_provider.dart';
import 'timeline_ruler.dart';

/// 스티커 멀티트랙 타임라인
class StickerTimelineTrack extends ConsumerWidget {
  final Duration totalDuration;
  final Duration currentPosition;
  final VoidCallback onAddSticker;

  const StickerTimelineTrack({
    super.key,
    required this.totalDuration,
    required this.currentPosition,
    required this.onAddSticker,
  });

  static const _trackHeight = 32.0;
  static const _minDurationMs = 300;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlays = ref.watch(overlaysProvider);
    final totalMs = totalDuration.inMilliseconds.toDouble();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 상단: 추가 버튼
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: onAddSticker,
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
                    Icon(Icons.add, size: 16, color: Colors.white70),
                    SizedBox(width: 4),
                    Text(
                      '스티커 추가',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),

          // 타임라인 눈금
          TimelineRuler(
            totalDuration: totalDuration,
            currentPosition: currentPosition,
          ),
          const SizedBox(height: 4),

          // 멀티트랙
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: overlays.length > 4
                  ? _trackHeight * 4 + 16
                  : _trackHeight * overlays.length.clamp(1, 99) + 16,
            ),
            child: overlays.isEmpty
                ? Container(
                    height: _trackHeight,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '스티커를 추가해보세요',
                      style: TextStyle(color: Colors.white24, fontSize: 12),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: overlays.map((item) {
                        return SizedBox(
                          height: _trackHeight,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final trackWidth = constraints.maxWidth;

                              // 시간이 없는 스티커는 전체 구간 표시
                              final startMs =
                                  item.startTime?.inMilliseconds ?? 0;
                              final endMs = item.endTime?.inMilliseconds ??
                                  totalDuration.inMilliseconds;
                              final leftFrac = startMs / totalMs;
                              final widthFrac = (endMs - startMs) / totalMs;
                              final blockLeft = leftFrac * trackWidth;
                              final blockWidth =
                                  (widthFrac * trackWidth).clamp(20.0, trackWidth);

                              return Stack(
                                children: [
                                  Container(
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  Positioned(
                                    left: blockLeft,
                                    width: blockWidth,
                                    top: 3,
                                    bottom: 3,
                                    child: _StickerBlock(
                                      item: item,
                                      trackWidth: trackWidth,
                                      totalMs: totalMs,
                                      totalDuration: totalDuration,
                                      onLongPress: () =>
                                          _showDeleteDialog(context, ref, item),
                                      onStartDrag: (deltaDx) {
                                        final deltaMs =
                                            (deltaDx / trackWidth * totalMs)
                                                .round();
                                        final newStart = Duration(
                                          milliseconds: (startMs + deltaMs)
                                              .clamp(
                                                  0,
                                                  endMs - _minDurationMs),
                                        );
                                        ref
                                            .read(overlaysProvider.notifier)
                                            .updateOverlay(
                                              item.id,
                                              item.copyWith(
                                                  startTime: newStart),
                                            );
                                      },
                                      onEndDrag: (deltaDx) {
                                        final deltaMs =
                                            (deltaDx / trackWidth * totalMs)
                                                .round();
                                        final newEnd = Duration(
                                          milliseconds: (endMs + deltaMs)
                                              .clamp(
                                            startMs + _minDurationMs,
                                            totalDuration.inMilliseconds,
                                          ),
                                        );
                                        ref
                                            .read(overlaysProvider.notifier)
                                            .updateOverlay(
                                              item.id,
                                              item.copyWith(endTime: newEnd),
                                            );
                                      },
                                      onBodyDrag: (deltaDx) {
                                        final deltaMs =
                                            (deltaDx / trackWidth * totalMs)
                                                .round();
                                        final duration = endMs - startMs;
                                        var newStartMs = startMs + deltaMs;
                                        newStartMs = newStartMs.clamp(
                                            0,
                                            totalDuration.inMilliseconds -
                                                duration);
                                        ref
                                            .read(overlaysProvider.notifier)
                                            .updateOverlay(
                                              item.id,
                                              item.copyWith(
                                                startTime: Duration(
                                                    milliseconds: newStartMs),
                                                endTime: Duration(
                                                    milliseconds:
                                                        newStartMs + duration),
                                              ),
                                            );
                                      },
                                    ),
                                  ),
                                  // 재생 위치
                                  Positioned(
                                    left: (currentPosition.inMilliseconds /
                                            totalMs) *
                                        trackWidth,
                                    top: 0,
                                    bottom: 0,
                                    child: Container(
                                        width: 1, color: Colors.white54),
                                  ),
                                ],
                              );
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(
      BuildContext context, WidgetRef ref, OverlayItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('스티커 삭제'),
        content: Text("'${item.text}' 스티커를 삭제할까요?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              ref.read(overlaysProvider.notifier).removeOverlay(item.id);
              Navigator.pop(ctx);
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _StickerBlock extends StatelessWidget {
  final OverlayItem item;
  final double trackWidth;
  final double totalMs;
  final Duration totalDuration;
  final VoidCallback onLongPress;
  final void Function(double) onStartDrag;
  final void Function(double) onEndDrag;
  final void Function(double) onBodyDrag;

  static const _handleWidth = 12.0;

  const _StickerBlock({
    required this.item,
    required this.trackWidth,
    required this.totalMs,
    required this.totalDuration,
    required this.onLongPress,
    required this.onStartDrag,
    required this.onEndDrag,
    required this.onBodyDrag,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onLongPress: onLongPress,
            onHorizontalDragUpdate: (d) => onBodyDrag(d.delta.dx),
            child: Container(
              decoration: BoxDecoration(
                color: (item.backgroundColor ?? Colors.purple)
                    .withOpacity(0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: _handleWidth + 2),
              child: Text(
                item.text,
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
        // 왼쪽 핸들
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: _handleWidth,
          child: GestureDetector(
            onHorizontalDragUpdate: (d) => onStartDrag(d.delta.dx),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.transparent,
                borderRadius:
                    BorderRadius.horizontal(left: Radius.circular(4)),
              ),
            ),
          ),
        ),
        // 오른쪽 핸들
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: _handleWidth,
          child: GestureDetector(
            onHorizontalDragUpdate: (d) => onEndDrag(d.delta.dx),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.transparent,
                borderRadius:
                    BorderRadius.horizontal(right: Radius.circular(4)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
