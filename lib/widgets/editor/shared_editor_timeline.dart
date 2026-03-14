import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/subtitle_item.dart';
import '../../models/video_edit_models.dart';
import '../../providers/subtitle_provider.dart';
import '../../providers/video_editor_provider.dart';
import 'thumbnail_strip.dart';
import 'timeline_ruler.dart';

/// 속도/텍스트/스티커 탭에서 공유하는 통합 타임라인
///
/// 트림된 영역(effectiveStart ~ effectiveStart+effectiveDuration)만 표시하며,
/// 속도·텍스트·스티커 트랙을 항상 함께 보여준다.
class SharedEditorTimeline extends ConsumerWidget {
  final Duration effectiveStart;
  final Duration effectiveDuration;
  final Duration currentPosition;
  final EditorTab activeTab;

  // Speed
  final VoidCallback onSplit;

  // Text
  final VoidCallback onAddText;
  final void Function(SubtitleItem) onEditText;

  // Sticker
  final VoidCallback onAddSticker;

  // Seek
  final void Function(Duration position)? onSeek;

  // Thumbnails
  final List<String> thumbnailPaths;

  const SharedEditorTimeline({
    super.key,
    required this.effectiveStart,
    required this.effectiveDuration,
    required this.currentPosition,
    required this.activeTab,
    required this.onSplit,
    required this.onAddText,
    required this.onEditText,
    required this.onAddSticker,
    this.onSeek,
    this.thumbnailPaths = const [],
  });

  static const _trackHeight = 26.0;
  static const _minDurationMs = 300;
  static const _speedOptions = [0.5, 1.0, 2.0, 4.0];

  Duration get _effectiveEnd => effectiveStart + effectiveDuration;

  Duration get _adjustedPosition => Duration(
        milliseconds: (currentPosition - effectiveStart)
            .inMilliseconds
            .clamp(0, effectiveDuration.inMilliseconds),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 탭별 액션 바
          _buildActionBar(ref),
          const SizedBox(height: 4),
          // 공유 타임라인 눈금
          TimelineRuler(
            totalDuration: effectiveDuration,
            currentPosition: _adjustedPosition,
            onSeek: onSeek != null
                ? (adjustedPos) => onSeek!(effectiveStart + adjustedPos)
                : null,
          ),
          const SizedBox(height: 2),
          // 트랙들
          Expanded(child: _buildTracks(context, ref)),
        ],
      ),
    );
  }

  // ─── 액션 바 ─────────────────────────────────────────

  Widget _buildActionBar(WidgetRef ref) {
    switch (activeTab) {
      case EditorTab.speed:
        return _buildSpeedActions(ref);
      case EditorTab.text:
        return _buildPillButton('텍스트 추가', Icons.add, onAddText);
      case EditorTab.sticker:
        return _buildPillButton('스티커 추가', Icons.add, onAddSticker);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSpeedActions(WidgetRef ref) {
    final segments = ref.watch(speedSegmentsProvider);
    final selectedIdx = ref.watch(selectedSpeedSegmentProvider);

    return Row(
      children: [
        ..._speedOptions.map((speed) {
          final isActive = selectedIdx != null &&
              selectedIdx < segments.length &&
              (segments[selectedIdx].speed - speed).abs() < 0.01;

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: selectedIdx != null
                  ? () => ref
                      .read(speedSegmentsProvider.notifier)
                      .updateSpeedAndMerge(selectedIdx, speed)
                  : null,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? _speedColor(speed)
                      : Colors.white
                          .withOpacity(selectedIdx != null ? 0.15 : 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isActive ? _speedColor(speed) : Colors.white24,
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
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }),
        const Spacer(),
        GestureDetector(
          onTap: onSplit,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.content_cut, size: 14, color: Colors.white70),
                SizedBox(width: 4),
                Text('분할',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPillButton(String label, IconData icon, VoidCallback onTap) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.white70),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 트랙 영역 ───────────────────────────────────────

  Widget _buildTracks(BuildContext context, WidgetRef ref) {
    final effectiveMs = effectiveDuration.inMilliseconds.toDouble();
    if (effectiveMs <= 0) return const SizedBox.shrink();

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 썸네일 필름스트립
          if (thumbnailPaths.isNotEmpty) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                return Stack(
                  children: [
                    ThumbnailStrip(thumbnailPaths: thumbnailPaths),
                    // 재생 위치 표시
                    Positioned(
                      left: (_adjustedPosition.inMilliseconds / effectiveMs) *
                              w -
                          0.5,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 1.5, color: Colors.white),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 2),
          ],
          _buildSpeedTrack(ref, effectiveMs),
          const SizedBox(height: 2),
          _buildTextTracks(context, ref, effectiveMs),
          const SizedBox(height: 2),
          _buildStickerTracks(context, ref, effectiveMs),
        ],
      ),
    );
  }

  // ─── 속도 트랙 ───────────────────────────────────────

  Widget _buildSpeedTrack(WidgetRef ref, double effectiveMs) {
    final segments = ref.watch(speedSegmentsProvider);
    final selectedIdx = ref.watch(selectedSpeedSegmentProvider);

    // 유효 범위와 겹치는 구간만
    final visible = <(int, SpeedSegment)>[];
    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      if (seg.end > effectiveStart && seg.start < _effectiveEnd) {
        visible.add((i, seg));
      }
    }

    return SizedBox(
      height: _trackHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          return Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) =>
                    _handleTrackSeek(d.localPosition.dx, w, effectiveMs),
                onHorizontalDragStart: (d) =>
                    _handleTrackSeek(d.localPosition.dx, w, effectiveMs),
                onHorizontalDragUpdate: (d) =>
                    _handleTrackSeek(d.localPosition.dx, w, effectiveMs),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              // 구간 블록
              ...visible.map((entry) {
                final (i, seg) = entry;
                final cStart = seg.start < effectiveStart
                    ? effectiveStart
                    : seg.start;
                final cEnd =
                    seg.end > _effectiveEnd ? _effectiveEnd : seg.end;
                final leftFrac =
                    (cStart - effectiveStart).inMilliseconds / effectiveMs;
                final widthFrac =
                    (cEnd - cStart).inMilliseconds / effectiveMs;
                final isSelected = i == selectedIdx;

                return Positioned(
                  left: leftFrac * w,
                  width: (widthFrac * w).clamp(16.0, w),
                  top: 2,
                  bottom: 2,
                  child: GestureDetector(
                    onTap: () {
                      ref.read(selectedSpeedSegmentProvider.notifier).state =
                          (selectedIdx == i) ? null : i;
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: _speedColor(seg.speed)
                            .withOpacity(isSelected ? 0.9 : 0.5),
                        borderRadius: BorderRadius.circular(3),
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 1.5)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${seg.speed}x',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSelected ? 12 : 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              // 경계선 핸들
              ...visible.where((e) {
                final (i, _) = e;
                return i < segments.length - 1 &&
                    segments[i].end > effectiveStart &&
                    segments[i].end < _effectiveEnd;
              }).map((e) {
                final (i, _) = e;
                final boundary = segments[i].end;
                final leftFrac =
                    (boundary - effectiveStart).inMilliseconds / effectiveMs;
                return Positioned(
                  left: leftFrac * w - 8,
                  width: 16,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      final deltaMs =
                          (details.delta.dx / w * effectiveMs).round();
                      final newPos = Duration(
                          milliseconds:
                              boundary.inMilliseconds + deltaMs);
                      ref
                          .read(speedSegmentsProvider.notifier)
                          .moveBoundary(i, newPos);
                    },
                    child: Center(
                      child: Container(
                        width: 3,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.white70,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                    ),
                  ),
                );
              }),
              // 재생 위치
              Positioned(
                left: (_adjustedPosition.inMilliseconds / effectiveMs) * w -
                    0.5,
                top: 0,
                bottom: 0,
                child: Container(width: 1.5, color: Colors.white),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── 텍스트 트랙 ─────────────────────────────────────

  Widget _buildTextTracks(
      BuildContext context, WidgetRef ref, double effectiveMs) {
    final subtitles = ref.watch(subtitlesProvider);
    final selectedId = ref.watch(selectedSubtitleIdProvider);

    final visible = subtitles
        .where(
            (s) => s.endTime > effectiveStart && s.startTime < _effectiveEnd)
        .toList();

    if (visible.isEmpty) {
      return SizedBox(
        height: _trackHeight,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: const Text('텍스트',
              style: TextStyle(color: Colors.white12, fontSize: 10)),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: visible.map((sub) {
        final isSelected = sub.id == selectedId;
        return SizedBox(
          height: _trackHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final cStart =
                  sub.startTime < effectiveStart ? effectiveStart : sub.startTime;
              final cEnd = sub.endTime > _effectiveEnd
                  ? _effectiveEnd
                  : sub.endTime;
              final leftFrac =
                  (cStart - effectiveStart).inMilliseconds / effectiveMs;
              final widthFrac =
                  (cEnd - cStart).inMilliseconds / effectiveMs;

              return Stack(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) =>
                        _handleTrackSeek(d.localPosition.dx, w, effectiveMs),
                    onHorizontalDragStart: (d) =>
                        _handleTrackSeek(d.localPosition.dx, w, effectiveMs),
                    onHorizontalDragUpdate: (d) =>
                        _handleTrackSeek(d.localPosition.dx, w, effectiveMs),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Positioned(
                    left: leftFrac * w,
                    width: (widthFrac * w).clamp(20.0, w),
                    top: 2,
                    bottom: 2,
                    child: _DragBlock(
                      label: sub.text,
                      color:
                          isSelected ? Colors.blue : Colors.amber,
                      isSelected: isSelected,
                      onTap: () {
                        ref
                            .read(selectedSubtitleIdProvider.notifier)
                            .state = sub.id;
                        onEditText(sub);
                      },
                      onLongPress: () =>
                          _showDeleteTextDialog(context, ref, sub),
                      onStartDrag: (dx) {
                        final deltaMs =
                            (dx / w * effectiveMs).round();
                        final newStart = Duration(
                          milliseconds:
                              (sub.startTime.inMilliseconds + deltaMs)
                                  .clamp(
                                      0,
                                      sub.endTime.inMilliseconds -
                                          _minDurationMs),
                        );
                        ref
                            .read(subtitlesProvider.notifier)
                            .updateSubtitle(
                              sub.id,
                              sub.copyWith(startTime: newStart),
                            );
                      },
                      onEndDrag: (dx) {
                        final deltaMs =
                            (dx / w * effectiveMs).round();
                        final newEnd = Duration(
                          milliseconds:
                              (sub.endTime.inMilliseconds + deltaMs)
                                  .clamp(
                            sub.startTime.inMilliseconds +
                                _minDurationMs,
                            _effectiveEnd.inMilliseconds,
                          ),
                        );
                        ref
                            .read(subtitlesProvider.notifier)
                            .updateSubtitle(
                              sub.id,
                              sub.copyWith(endTime: newEnd),
                            );
                      },
                      onBodyDrag: (dx) {
                        final deltaMs =
                            (dx / w * effectiveMs).round();
                        final duration = sub.endTime.inMilliseconds -
                            sub.startTime.inMilliseconds;
                        var newStartMs =
                            sub.startTime.inMilliseconds + deltaMs;
                        newStartMs = newStartMs.clamp(
                            0,
                            _effectiveEnd.inMilliseconds - duration);
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
                  ),
                  // 재생 위치
                  Positioned(
                    left: (_adjustedPosition.inMilliseconds /
                            effectiveMs) *
                        w,
                    top: 0,
                    bottom: 0,
                    child:
                        Container(width: 1, color: Colors.white54),
                  ),
                ],
              );
            },
          ),
        );
      }).toList(),
    );
  }

  // ─── 스티커 트랙 ─────────────────────────────────────

  Widget _buildStickerTracks(
      BuildContext context, WidgetRef ref, double effectiveMs) {
    final overlays = ref.watch(overlaysProvider);
    final totalMs = (effectiveStart + effectiveDuration).inMilliseconds;

    final visible = overlays.where((item) {
      final startMs = item.startTime?.inMilliseconds ?? 0;
      final endMs = item.endTime?.inMilliseconds ?? totalMs;
      return endMs > effectiveStart.inMilliseconds &&
          startMs < _effectiveEnd.inMilliseconds;
    }).toList();

    if (visible.isEmpty) {
      return SizedBox(
        height: _trackHeight,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: const Text('스티커',
              style: TextStyle(color: Colors.white12, fontSize: 10)),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: visible.map((item) {
        final startMs = item.startTime?.inMilliseconds ?? 0;
        final endMs = item.endTime?.inMilliseconds ?? totalMs;

        return SizedBox(
          height: _trackHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final cStartMs = math.max(
                  startMs, effectiveStart.inMilliseconds);
              final cEndMs =
                  math.min(endMs, _effectiveEnd.inMilliseconds);
              final leftFrac =
                  (cStartMs - effectiveStart.inMilliseconds) /
                      effectiveMs;
              final widthFrac = (cEndMs - cStartMs) / effectiveMs;

              return Stack(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) =>
                        _handleTrackSeek(d.localPosition.dx, w, effectiveMs),
                    onHorizontalDragStart: (d) =>
                        _handleTrackSeek(d.localPosition.dx, w, effectiveMs),
                    onHorizontalDragUpdate: (d) =>
                        _handleTrackSeek(d.localPosition.dx, w, effectiveMs),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Positioned(
                    left: leftFrac * w,
                    width: (widthFrac * w).clamp(20.0, w),
                    top: 2,
                    bottom: 2,
                    child: _DragBlock(
                      label: item.text,
                      color: item.backgroundColor ?? Colors.purple,
                      isSelected: false,
                      onTap: () {},
                      onLongPress: () =>
                          _showDeleteStickerDialog(context, ref, item),
                      onStartDrag: (dx) {
                        final deltaMs =
                            (dx / w * effectiveMs).round();
                        final newStart = Duration(
                          milliseconds: (startMs + deltaMs).clamp(
                              0, endMs - _minDurationMs),
                        );
                        ref
                            .read(overlaysProvider.notifier)
                            .updateOverlay(
                              item.id,
                              item.copyWith(startTime: newStart),
                            );
                      },
                      onEndDrag: (dx) {
                        final deltaMs =
                            (dx / w * effectiveMs).round();
                        final newEnd = Duration(
                          milliseconds: (endMs + deltaMs).clamp(
                            startMs + _minDurationMs,
                            _effectiveEnd.inMilliseconds,
                          ),
                        );
                        ref
                            .read(overlaysProvider.notifier)
                            .updateOverlay(
                              item.id,
                              item.copyWith(endTime: newEnd),
                            );
                      },
                      onBodyDrag: (dx) {
                        final deltaMs =
                            (dx / w * effectiveMs).round();
                        final duration = endMs - startMs;
                        var newStartMs = startMs + deltaMs;
                        newStartMs = newStartMs.clamp(
                            0,
                            _effectiveEnd.inMilliseconds - duration);
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
                    left: (_adjustedPosition.inMilliseconds /
                            effectiveMs) *
                        w,
                    top: 0,
                    bottom: 0,
                    child:
                        Container(width: 1, color: Colors.white54),
                  ),
                ],
              );
            },
          ),
        );
      }).toList(),
    );
  }

  // ─── 삭제 다이얼로그 ─────────────────────────────────

  void _showDeleteTextDialog(
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

  void _showDeleteStickerDialog(
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

  // ─── seek 유틸 ─────────────────────────────────────

  /// 타임라인 배경에서 탭/드래그 시 seek 위치를 계산하여 콜백 호출
  void _handleTrackSeek(double localX, double trackWidth, double effectiveMs) {
    if (onSeek == null) return;
    final ratio = (localX / trackWidth).clamp(0.0, 1.0);
    final seekPos = effectiveStart +
        Duration(milliseconds: (ratio * effectiveMs).round());
    onSeek!(seekPos);
  }

  // ─── 유틸 ────────────────────────────────────────────

  static Color _speedColor(double speed) {
    if (speed <= 0.5) return const Color(0xFF42A5F5);
    if (speed <= 1.0) return const Color(0xFF66BB6A);
    if (speed <= 2.0) return const Color(0xFFFFA726);
    return const Color(0xFFEF5350);
  }
}

/// 드래그 가능한 트랙 블록 (좌/우 핸들 + 본체 드래그)
class _DragBlock extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final void Function(double) onStartDrag;
  final void Function(double) onEndDrag;
  final void Function(double) onBodyDrag;

  static const _handleWidth = 10.0;

  const _DragBlock({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onStartDrag,
    required this.onEndDrag,
    required this.onBodyDrag,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 본체
        Positioned.fill(
          child: GestureDetector(
            onTap: onTap,
            onLongPress: onLongPress,
            onHorizontalDragUpdate: (d) => onBodyDrag(d.delta.dx),
            child: Container(
              decoration: BoxDecoration(
                color: color.withOpacity(isSelected ? 0.8 : 0.6),
                borderRadius: BorderRadius.circular(3),
                border: isSelected
                    ? Border.all(color: Colors.white, width: 1.5)
                    : null,
              ),
              alignment: Alignment.center,
              padding:
                  const EdgeInsets.symmetric(horizontal: _handleWidth + 2),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
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
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(3)),
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
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.3)
                    : Colors.transparent,
                borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(3)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
