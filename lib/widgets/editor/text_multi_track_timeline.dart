import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/subtitle_item.dart';
import '../../providers/subtitle_provider.dart';
import 'timeline_ruler.dart';

/// 텍스트 멀티트랙 타임라인
class TextMultiTrackTimeline extends ConsumerWidget {
  final Duration totalDuration;
  final Duration currentPosition;
  final VoidCallback onAddText;
  final void Function(SubtitleItem) onEditText;

  const TextMultiTrackTimeline({
    super.key,
    required this.totalDuration,
    required this.currentPosition,
    required this.onAddText,
    required this.onEditText,
  });

  static const _trackHeight = 32.0;
  static const _minDurationMs = 300;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitles = ref.watch(subtitlesProvider);
    final selectedId = ref.watch(selectedSubtitleIdProvider);
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
              onTap: onAddText,
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
                      '텍스트 추가',
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

          // 멀티트랙 영역
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: subtitles.length > 4
                  ? _trackHeight * 4 + 16
                  : _trackHeight * subtitles.length + 16,
            ),
            child: subtitles.isEmpty
                ? Container(
                    height: _trackHeight,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '텍스트를 추가해보세요',
                      style: TextStyle(color: Colors.white24, fontSize: 12),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        ...subtitles.asMap().entries.map((entry) {
                          final sub = entry.value;
                          final isSelected = sub.id == selectedId;

                          return SizedBox(
                            height: _trackHeight,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final trackWidth = constraints.maxWidth;

                                return Stack(
                                  children: [
                                    // 트랙 배경
                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                    ),
                                    // 블록
                                    _TrackBlock(
                                      sub: sub,
                                      isSelected: isSelected,
                                      trackWidth: trackWidth,
                                      totalMs: totalMs,
                                      totalDuration: totalDuration,
                                      onTap: () {
                                        ref
                                            .read(selectedSubtitleIdProvider
                                                .notifier)
                                            .state = sub.id;
                                        onEditText(sub);
                                      },
                                      onLongPress: () {
                                        _showDeleteDialog(context, ref, sub);
                                      },
                                      onStartDrag: (deltaDx) {
                                        final deltaMs =
                                            (deltaDx / trackWidth * totalMs)
                                                .round();
                                        final newStart = Duration(
                                          milliseconds: (sub
                                                      .startTime
                                                      .inMilliseconds +
                                                  deltaMs)
                                              .clamp(
                                                  0,
                                                  sub.endTime
                                                          .inMilliseconds -
                                                      _minDurationMs),
                                        );
                                        ref
                                            .read(subtitlesProvider.notifier)
                                            .updateSubtitle(
                                              sub.id,
                                              sub.copyWith(
                                                  startTime: newStart),
                                            );
                                      },
                                      onEndDrag: (deltaDx) {
                                        final deltaMs =
                                            (deltaDx / trackWidth * totalMs)
                                                .round();
                                        final newEnd = Duration(
                                          milliseconds: (sub.endTime
                                                      .inMilliseconds +
                                                  deltaMs)
                                              .clamp(
                                            sub.startTime.inMilliseconds +
                                                _minDurationMs,
                                            totalDuration.inMilliseconds,
                                          ),
                                        );
                                        ref
                                            .read(subtitlesProvider.notifier)
                                            .updateSubtitle(
                                              sub.id,
                                              sub.copyWith(endTime: newEnd),
                                            );
                                      },
                                      onBodyDrag: (deltaDx) {
                                        final deltaMs =
                                            (deltaDx / trackWidth * totalMs)
                                                .round();
                                        final duration = sub.endTime
                                                .inMilliseconds -
                                            sub.startTime.inMilliseconds;
                                        var newStartMs =
                                            sub.startTime.inMilliseconds +
                                                deltaMs;
                                        newStartMs = newStartMs.clamp(
                                            0,
                                            totalDuration.inMilliseconds -
                                                duration);
                                        ref
                                            .read(subtitlesProvider.notifier)
                                            .updateSubtitle(
                                              sub.id,
                                              sub.copyWith(
                                                startTime: Duration(
                                                    milliseconds: newStartMs),
                                                endTime: Duration(
                                                    milliseconds:
                                                        newStartMs + duration),
                                              ),
                                            );
                                      },
                                    ),
                                    // 재생 위치
                                    Positioned(
                                      left: (currentPosition
                                                  .inMilliseconds /
                                              totalMs) *
                                          trackWidth,
                                      top: 0,
                                      bottom: 0,
                                      child: Container(
                                          width: 1,
                                          color: Colors.white54),
                                    ),
                                  ],
                                );
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(
      BuildContext context, WidgetRef ref, SubtitleItem sub) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('텍스트 삭제'),
        content: Text("'${sub.text}' 텍스트를 삭제할까요?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              ref.read(subtitlesProvider.notifier).removeSubtitle(sub.id);
              Navigator.pop(ctx);
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// 트랙 내 드래그 가능한 블록 (양쪽 핸들 + 본체 드래그)
class _TrackBlock extends StatelessWidget {
  final SubtitleItem sub;
  final bool isSelected;
  final double trackWidth;
  final double totalMs;
  final Duration totalDuration;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final void Function(double) onStartDrag;
  final void Function(double) onEndDrag;
  final void Function(double) onBodyDrag;

  static const _handleWidth = 12.0;

  const _TrackBlock({
    required this.sub,
    required this.isSelected,
    required this.trackWidth,
    required this.totalMs,
    required this.totalDuration,
    required this.onTap,
    required this.onLongPress,
    required this.onStartDrag,
    required this.onEndDrag,
    required this.onBodyDrag,
  });

  @override
  Widget build(BuildContext context) {
    final leftFrac = sub.startTime.inMilliseconds / totalMs;
    final widthFrac =
        (sub.endTime - sub.startTime).inMilliseconds / totalMs;
    final blockLeft = leftFrac * trackWidth;
    final blockWidth = (widthFrac * trackWidth).clamp(20.0, trackWidth);

    return Positioned(
      left: blockLeft,
      width: blockWidth,
      top: 3,
      bottom: 3,
      child: Stack(
        children: [
          // 본체 (좌우 드래그로 구간 이동)
          Positioned.fill(
            child: GestureDetector(
              onTap: onTap,
              onLongPress: onLongPress,
              onHorizontalDragUpdate: (d) => onBodyDrag(d.delta.dx),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.blue.withOpacity(0.8)
                      : Colors.amber.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4),
                  border: isSelected
                      ? Border.all(color: Colors.white, width: 1.5)
                      : null,
                ),
                alignment: Alignment.center,
                padding:
                    const EdgeInsets.symmetric(horizontal: _handleWidth + 2),
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
          // 왼쪽 핸들
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: _handleWidth,
            child: GestureDetector(
              onHorizontalDragUpdate: (d) => onStartDrag(d.delta.dx),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.3)
                      : Colors.transparent,
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(4)),
                ),
                child: isSelected
                    ? const Center(
                        child: Icon(Icons.drag_handle,
                            size: 10, color: Colors.white70))
                    : null,
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
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.3)
                      : Colors.transparent,
                  borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(4)),
                ),
                child: isSelected
                    ? const Center(
                        child: Icon(Icons.drag_handle,
                            size: 10, color: Colors.white70))
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
