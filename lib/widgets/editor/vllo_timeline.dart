import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/subtitle_item.dart';
import '../../models/video_edit_models.dart';
import '../../providers/subtitle_provider.dart';
import '../../providers/video_editor_provider.dart';
import 'crop_timeline_track.dart';

/// VLLO 스타일 스크롤 기반 멀티트랙 타임라인
///
/// - 중앙 고정 플레이헤드
/// - 수평 스크롤로 타임라인 탐색
/// - 모든 트랙(미디어/속도/텍스트/스티커)을 동시에 표시
class VlloTimeline extends ConsumerStatefulWidget {
  final Duration effectiveStart;
  final Duration effectiveDuration;
  final Duration currentPosition;
  final List<String> thumbnailPaths;
  final void Function(Duration position) onSeek;

  // Speed
  final VoidCallback onSplit;

  // Text
  final VoidCallback onAddText;
  final void Function(SubtitleItem) onEditText;

  // Sticker
  final VoidCallback onAddSticker;

  const VlloTimeline({
    super.key,
    required this.effectiveStart,
    required this.effectiveDuration,
    required this.currentPosition,
    required this.thumbnailPaths,
    required this.onSeek,
    required this.onSplit,
    required this.onAddText,
    required this.onEditText,
    required this.onAddSticker,
  });

  @override
  ConsumerState<VlloTimeline> createState() => _VlloTimelineState();
}

class _VlloTimelineState extends ConsumerState<VlloTimeline> {
  late ScrollController _scrollController;
  double _pixelsPerSecond = 80.0;
  bool _isDragging = false;
  double _viewportWidth = 0;

  static const _mediaTrackHeight = 44.0;
  static const _trackHeight = 28.0;
  static const _rulerHeight = 20.0;
  static const _trackGap = 2.0;
  static const _minDurationMs = 300;

  /// 프로그래밍적 스크롤 중인지 (onSeek 콜백 차단용)
  bool _isProgrammaticScroll = false;

  double get _totalContentWidth =>
      (widget.effectiveDuration.inMilliseconds / 1000.0) * _pixelsPerSecond;

  // 중앙 고정 플레이헤드를 위한 좌우 패딩
  double get _halfViewport => _viewportWidth / 2;

  Duration get _effectiveEnd =>
      widget.effectiveStart + widget.effectiveDuration;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void didUpdateWidget(VlloTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 재생 중(사용자 드래그가 아닐 때) 스크롤 위치 동기화
    if (!_isDragging && _viewportWidth > 0 && _scrollController.hasClients) {
      final adjustedMs =
          (widget.currentPosition - widget.effectiveStart).inMilliseconds;
      final targetScroll = (adjustedMs / 1000.0) * _pixelsPerSecond;
      final maxScroll = _scrollController.position.maxScrollExtent;
      final clampedScroll = targetScroll.clamp(0.0, maxScroll);

      // 이미 올바른 위치면 스킵 (불필요한 재귀 방지)
      if ((_scrollController.offset - clampedScroll).abs() > 0.5) {
        _isProgrammaticScroll = true;
        _scrollController.jumpTo(clampedScroll);
        _isProgrammaticScroll = false;
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScrollUpdate() {
    // 프로그래밍적 스크롤이나 비-드래그 상태에서는 무시
    if (_isProgrammaticScroll || !_isDragging) return;
    final scrollOffset = _scrollController.offset;
    final ms = (scrollOffset / _pixelsPerSecond * 1000).round();
    final seekPos = widget.effectiveStart + Duration(milliseconds: ms);
    final clamped = Duration(
      milliseconds: seekPos.inMilliseconds
          .clamp(widget.effectiveStart.inMilliseconds,
              _effectiveEnd.inMilliseconds),
    );
    widget.onSeek(clamped);
  }

  /// 시간 → 타임라인 X 좌표 (콘텐츠 기준)
  double _timeToX(Duration time) {
    final ms = (time - widget.effectiveStart).inMilliseconds;
    return (ms / 1000.0) * _pixelsPerSecond;
  }

  // ─── 배속 색상 ──────────────────────────────────────
  static Color _speedColor(double speed) {
    if (speed <= 0.5) return const Color(0x5542A5F5);
    if (speed <= 1.0) return const Color(0x5566BB6A);
    if (speed <= 2.0) return const Color(0x55FFA726);
    return const Color(0x55EF5350);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportWidth = constraints.maxWidth;

        return GestureDetector(
          // 핀치 줌으로 타임라인 스케일 조절
          onScaleUpdate: (details) {
            if (details.scale != 1.0) {
              setState(() {
                _pixelsPerSecond =
                    (_pixelsPerSecond * details.scale).clamp(30.0, 300.0);
              });
            }
          },
          child: Stack(
            children: [
              // 스크롤 가능한 타임라인 콘텐츠
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollStartNotification) {
                    _isDragging = true;
                  } else if (notification is ScrollUpdateNotification) {
                    _onScrollUpdate();
                  } else if (notification is ScrollEndNotification) {
                    _isDragging = false;
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: SizedBox(
                    // 좌우 여백 = 뷰포트 절반 (플레이헤드가 양 끝에서도 중앙에 위치)
                    width: _totalContentWidth + _viewportWidth,
                    child: Padding(
                      padding:
                          EdgeInsets.only(left: _halfViewport, right: _halfViewport),
                      child: _buildTimelineTracks(),
                    ),
                  ),
                ),
              ),
              // 중앙 고정 플레이헤드
              Positioned(
                left: _halfViewport - 1,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // 플레이헤드 삼각형 표시
              Positioned(
                left: _halfViewport - 5,
                top: 0,
                child: IgnorePointer(
                  child: CustomPaint(
                    size: const Size(10, 8),
                    painter: _PlayheadTrianglePainter(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimelineTracks() {
    final effectiveMs = widget.effectiveDuration.inMilliseconds.toDouble();
    if (effectiveMs <= 0) return const SizedBox.shrink();

    final segments = ref.watch(speedSegmentsProvider);
    final subtitles = ref.watch(subtitlesProvider);
    final overlays = ref.watch(overlaysProvider);
    final selectedTab = ref.watch(selectedEditorTabProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 룰러 (시간 눈금)
        _buildRuler(effectiveMs),
        const SizedBox(height: _trackGap),
        // 미디어 트랙 (썸네일)
        _buildMediaTrack(),
        const SizedBox(height: _trackGap),
        // 속도 트랙
        _buildSpeedTrack(segments, effectiveMs,
            isActive: selectedTab == EditorTab.speed),
        const SizedBox(height: _trackGap),
        // 줌 트랙
        CropTimelineTrack(
          trackHeight: _trackHeight,
          totalWidth: _totalContentWidth,
          totalDuration: widget.effectiveDuration,
        ),
        const SizedBox(height: _trackGap),
        // 텍스트 트랙
        _buildTextTrack(subtitles, effectiveMs,
            isActive: selectedTab == EditorTab.text),
        const SizedBox(height: _trackGap),
        // 스티커 트랙
        _buildStickerTrack(overlays, effectiveMs,
            isActive: selectedTab == EditorTab.sticker),
      ],
    );
  }

  // ─── 룰러 ──────────────────────────────────────────
  Widget _buildRuler(double effectiveMs) {
    final totalSec = widget.effectiveDuration.inSeconds;
    final interval = totalSec <= 10 ? 1 : (totalSec <= 30 ? 5 : 10);

    return SizedBox(
      height: _rulerHeight,
      width: _totalContentWidth,
      child: CustomPaint(
        painter: _RulerPainter(
          totalDurationMs: effectiveMs,
          pixelsPerSecond: _pixelsPerSecond,
          interval: interval,
        ),
      ),
    );
  }

  // ─── 미디어 트랙 ──────────────────────────────────────
  Widget _buildMediaTrack() {
    return SizedBox(
      height: _mediaTrackHeight,
      width: _totalContentWidth,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: widget.thumbnailPaths.isEmpty
            ? Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
              )
            : Row(
                children: widget.thumbnailPaths.map((path) {
                  return Expanded(
                    child: Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      height: _mediaTrackHeight,
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

  // ─── 속도 트랙 ──────────────────────────────────────
  Widget _buildSpeedTrack(
      List<SpeedSegment> segments, double effectiveMs,
      {required bool isActive}) {
    final rawSelectedIdx = ref.watch(selectedSpeedSegmentProvider);
    final selectedIdx =
        rawSelectedIdx ?? (segments.length == 1 ? 0 : null);

    final visible = <(int, SpeedSegment)>[];
    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      if (seg.end > widget.effectiveStart && seg.start < _effectiveEnd) {
        visible.add((i, seg));
      }
    }

    return SizedBox(
      height: _trackHeight,
      width: _totalContentWidth,
      child: Stack(
        children: [
          // 배경
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(isActive ? 0.08 : 0.04),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          // 구간 블록
          ...visible.map((entry) {
            final (i, seg) = entry;
            final cStart = seg.start < widget.effectiveStart
                ? widget.effectiveStart
                : seg.start;
            final cEnd =
                seg.end > _effectiveEnd ? _effectiveEnd : seg.end;
            final left = _timeToX(cStart);
            final width = _timeToX(cEnd) - left;
            final isSelected = i == selectedIdx;

            return Positioned(
              left: left,
              width: width.clamp(12, _totalContentWidth),
              top: 2,
              bottom: 2,
              child: GestureDetector(
                onTap: () {
                  ref.read(selectedSpeedSegmentProvider.notifier).state =
                      (selectedIdx == i) ? null : i;
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: _speedColor(seg.speed),
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
                      fontSize: isSelected ? 11 : 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          }),
          // 구간 경계 핸들
          ...visible.where((e) {
            final (i, _) = e;
            return i < segments.length - 1 &&
                segments[i].end > widget.effectiveStart &&
                segments[i].end < _effectiveEnd;
          }).map((e) {
            final (i, _) = e;
            final boundary = segments[i].end;
            final left = _timeToX(boundary);
            return Positioned(
              left: left - 8,
              width: 16,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onHorizontalDragUpdate: (details) {
                  final deltaMs = (details.delta.dx /
                          _pixelsPerSecond *
                          1000)
                      .round();
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
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white70,
                      borderRadius: BorderRadius.circular(1.5),
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

  // ─── 텍스트 트랙 ──────────────────────────────────────
  Widget _buildTextTrack(
      List<SubtitleItem> subtitles, double effectiveMs,
      {required bool isActive}) {
    final selectedId = ref.watch(selectedSubtitleIdProvider);
    final visible = subtitles
        .where((s) =>
            s.endTime > widget.effectiveStart &&
            s.startTime < _effectiveEnd)
        .toList();

    final trackCount = math.max(1, visible.length);

    return SizedBox(
      height: _trackHeight * trackCount,
      width: _totalContentWidth,
      child: Stack(
        children: [
          // 배경
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(isActive ? 0.08 : 0.04),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: visible.isEmpty
                ? Text('텍스트',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.1), fontSize: 9))
                : null,
          ),
          // 텍스트 블록
          ...visible.asMap().entries.map((entry) {
            final idx = entry.key;
            final sub = entry.value;
            final isSelected = sub.id == selectedId;
            final cStart = sub.startTime < widget.effectiveStart
                ? widget.effectiveStart
                : sub.startTime;
            final cEnd = sub.endTime > _effectiveEnd
                ? _effectiveEnd
                : sub.endTime;
            final left = _timeToX(cStart);
            final width = _timeToX(cEnd) - left;

            return Positioned(
              left: left,
              width: width.clamp(16, _totalContentWidth),
              top: idx * _trackHeight + 2,
              height: _trackHeight - 4,
              child: _TimelineBlock(
                label: sub.text,
                color: isSelected ? Colors.blue : Colors.amber,
                isSelected: isSelected,
                onTap: () {
                  ref.read(selectedSubtitleIdProvider.notifier).state =
                      sub.id;
                  widget.onEditText(sub);
                },
                onStartDrag: (dx) {
                  final deltaMs =
                      (dx / _pixelsPerSecond * 1000).round();
                  final newStart = Duration(
                    milliseconds:
                        (sub.startTime.inMilliseconds + deltaMs).clamp(
                            0,
                            sub.endTime.inMilliseconds - _minDurationMs),
                  );
                  ref.read(subtitlesProvider.notifier).updateSubtitle(
                        sub.id,
                        sub.copyWith(startTime: newStart),
                      );
                },
                onEndDrag: (dx) {
                  final deltaMs =
                      (dx / _pixelsPerSecond * 1000).round();
                  final newEnd = Duration(
                    milliseconds:
                        (sub.endTime.inMilliseconds + deltaMs).clamp(
                      sub.startTime.inMilliseconds + _minDurationMs,
                      _effectiveEnd.inMilliseconds,
                    ),
                  );
                  ref.read(subtitlesProvider.notifier).updateSubtitle(
                        sub.id,
                        sub.copyWith(endTime: newEnd),
                      );
                },
                onBodyDrag: (dx) {
                  final deltaMs =
                      (dx / _pixelsPerSecond * 1000).round();
                  final duration = sub.endTime.inMilliseconds -
                      sub.startTime.inMilliseconds;
                  var newStartMs =
                      sub.startTime.inMilliseconds + deltaMs;
                  newStartMs = newStartMs.clamp(
                      0, _effectiveEnd.inMilliseconds - duration);
                  ref.read(subtitlesProvider.notifier).updateSubtitle(
                        sub.id,
                        sub.copyWith(
                          startTime:
                              Duration(milliseconds: newStartMs),
                          endTime: Duration(
                              milliseconds: newStartMs + duration),
                        ),
                      );
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── 스티커 트랙 ──────────────────────────────────────
  Widget _buildStickerTrack(
      List<OverlayItem> overlays, double effectiveMs,
      {required bool isActive}) {
    final totalMs = _effectiveEnd.inMilliseconds;
    final visible = overlays.where((item) {
      final startMs = item.startTime?.inMilliseconds ?? 0;
      final endMs = item.endTime?.inMilliseconds ?? totalMs;
      return endMs > widget.effectiveStart.inMilliseconds &&
          startMs < _effectiveEnd.inMilliseconds;
    }).toList();

    final trackCount = math.max(1, visible.length);

    return SizedBox(
      height: _trackHeight * trackCount,
      width: _totalContentWidth,
      child: Stack(
        children: [
          // 배경
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(isActive ? 0.08 : 0.04),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: visible.isEmpty
                ? Text('스티커',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.1), fontSize: 9))
                : null,
          ),
          // 스티커 블록
          ...visible.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final startMs = item.startTime?.inMilliseconds ?? 0;
            final endMs = item.endTime?.inMilliseconds ?? totalMs;

            final cStartMs = math.max(
                startMs, widget.effectiveStart.inMilliseconds);
            final cEndMs =
                math.min(endMs, _effectiveEnd.inMilliseconds);
            final left =
                _timeToX(Duration(milliseconds: cStartMs));
            final width =
                _timeToX(Duration(milliseconds: cEndMs)) - left;

            return Positioned(
              left: left,
              width: width.clamp(16, _totalContentWidth),
              top: idx * _trackHeight + 2,
              height: _trackHeight - 4,
              child: _TimelineBlock(
                label: item.text,
                color: item.backgroundColor ?? Colors.purple,
                isSelected: false,
                onTap: () {},
                onStartDrag: (dx) {
                  final deltaMs =
                      (dx / _pixelsPerSecond * 1000).round();
                  final newStart = Duration(
                    milliseconds: (startMs + deltaMs)
                        .clamp(0, endMs - _minDurationMs),
                  );
                  ref.read(overlaysProvider.notifier).updateOverlay(
                        item.id,
                        item.copyWith(startTime: newStart),
                      );
                },
                onEndDrag: (dx) {
                  final deltaMs =
                      (dx / _pixelsPerSecond * 1000).round();
                  final newEnd = Duration(
                    milliseconds: (endMs + deltaMs).clamp(
                      startMs + _minDurationMs,
                      _effectiveEnd.inMilliseconds,
                    ),
                  );
                  ref.read(overlaysProvider.notifier).updateOverlay(
                        item.id,
                        item.copyWith(endTime: newEnd),
                      );
                },
                onBodyDrag: (dx) {
                  final deltaMs =
                      (dx / _pixelsPerSecond * 1000).round();
                  final duration = endMs - startMs;
                  var newStartMs = startMs + deltaMs;
                  newStartMs = newStartMs.clamp(
                      0, _effectiveEnd.inMilliseconds - duration);
                  ref.read(overlaysProvider.notifier).updateOverlay(
                        item.id,
                        item.copyWith(
                          startTime:
                              Duration(milliseconds: newStartMs),
                          endTime: Duration(
                              milliseconds: newStartMs + duration),
                        ),
                      );
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── 타임라인 블록 (텍스트/스티커) ─────────────────────────

class _TimelineBlock extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final void Function(double) onStartDrag;
  final void Function(double) onEndDrag;
  final void Function(double) onBodyDrag;

  static const _handleWidth = 8.0;

  const _TimelineBlock({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
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
              padding: const EdgeInsets.symmetric(
                  horizontal: _handleWidth + 2),
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

// ─── 룰러 페인터 ──────────────────────────────────────

class _RulerPainter extends CustomPainter {
  final double totalDurationMs;
  final double pixelsPerSecond;
  final int interval;

  _RulerPainter({
    required this.totalDurationMs,
    required this.pixelsPerSecond,
    required this.interval,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;

    const textStyle = TextStyle(
      color: Colors.white38,
      fontSize: 9,
    );

    final totalSec = (totalDurationMs / 1000).ceil();

    for (int sec = 0; sec <= totalSec; sec += interval) {
      final x = sec * pixelsPerSecond;
      if (x > size.width) break;

      // 눈금선
      canvas.drawLine(
        Offset(x, size.height - 4),
        Offset(x, size.height),
        paint,
      );

      // 라벨
      final tp = TextPainter(
        text: TextSpan(text: _formatSec(sec), style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + 2, 2));
    }

    // 하단 선
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      paint..color = Colors.white12,
    );
  }

  String _formatSec(int sec) {
    if (sec < 60) return '${sec}s';
    final m = sec ~/ 60;
    final s = sec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  bool shouldRepaint(_RulerPainter oldDelegate) =>
      oldDelegate.totalDurationMs != totalDurationMs ||
      oldDelegate.pixelsPerSecond != pixelsPerSecond ||
      oldDelegate.interval != interval;
}

// ─── 플레이헤드 삼각형 ─────────────────────────────────

class _PlayheadTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
