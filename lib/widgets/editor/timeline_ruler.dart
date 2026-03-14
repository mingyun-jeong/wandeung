import 'package:flutter/material.dart';

/// 시간 눈금 + 재생 위치를 보여주는 타임라인 룰러
class TimelineRuler extends StatelessWidget {
  final Duration totalDuration;
  final Duration currentPosition;
  final void Function(Duration position)? onSeek;

  const TimelineRuler({
    super.key,
    required this.totalDuration,
    required this.currentPosition,
    this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final totalMs = totalDuration.inMilliseconds.toDouble();

    return SizedBox(
      height: 20,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          if (totalMs <= 0) return const SizedBox.shrink();

          // 눈금 간격 계산 (약 5초 간격, 짧은 영상은 1초)
          final totalSec = totalDuration.inSeconds;
          final interval = totalSec <= 10 ? 1 : (totalSec <= 30 ? 5 : 10);

          final tickCount = totalSec ~/ interval;
          final labels = <Widget>[];
          for (int i = 0; i <= tickCount; i++) {
            final sec = i * interval;
            final frac = sec / (totalMs / 1000);
            if (frac > 1.0) break;
            labels.add(
              Positioned(
                left: frac * width,
                top: 0,
                child: Transform.translate(
                  offset: Offset(i == 0 ? 0 : -12, 0),
                  child: Text(
                    _formatSec(sec),
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                    ),
                  ),
                ),
              ),
            );
          }

          // 재생 위치
          final playheadLeft =
              (currentPosition.inMilliseconds / totalMs) * width;

          void handleSeek(double localX) {
            if (onSeek == null) return;
            final ratio = (localX / width).clamp(0.0, 1.0);
            onSeek!(Duration(
              milliseconds: (ratio * totalMs).round(),
            ));
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => handleSeek(details.localPosition.dx),
            onHorizontalDragStart: (details) =>
                handleSeek(details.localPosition.dx),
            onHorizontalDragUpdate: (details) =>
                handleSeek(details.localPosition.dx),
            child: Stack(
              children: [
                // 배경선
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(height: 1, color: Colors.white12),
                ),
                // 눈금 라벨
                ...labels,
                // 재생 위치
                Positioned(
                  left: playheadLeft - 0.5,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 1, color: Colors.white70),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _formatSec(int sec) {
    if (sec < 60) return '${sec}s';
    final m = sec ~/ 60;
    final s = sec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
