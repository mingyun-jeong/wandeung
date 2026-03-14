import 'package:flutter/material.dart';

/// VLLO 스타일 재생 컨트롤 바
///
/// ⏮ ◁ 00:04:10 |||타임코드바||| 01:33 ▷ ⏭
class PlaybackControlBar extends StatelessWidget {
  final Duration currentPosition;
  final Duration totalDuration;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onStepForward;
  final VoidCallback onStepBackward;
  final VoidCallback onJumpToStart;
  final VoidCallback onJumpToEnd;

  const PlaybackControlBar({
    super.key,
    required this.currentPosition,
    required this.totalDuration,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onStepForward,
    required this.onStepBackward,
    required this.onJumpToStart,
    required this.onJumpToEnd,
  });

  @override
  Widget build(BuildContext context) {
    final totalMs = totalDuration.inMilliseconds.toDouble();
    final progress = totalMs > 0
        ? (currentPosition.inMilliseconds / totalMs).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // ⏮ 처음으로
          _ControlIcon(Icons.skip_previous_rounded, onJumpToStart),
          // ◁ 프레임 뒤로
          _ControlIcon(Icons.chevron_left_rounded, onStepBackward),
          const SizedBox(width: 4),
          // 현재 시간
          Text(
            _formatDuration(currentPosition),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 6),
          // 중앙 타임코드 바 + 재생 버튼
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 배경 바
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                // 진행 바
                Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white54,
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ),
                ),
                // 재생/정지 버튼 (중앙)
                GestureDetector(
                  onTap: onPlayPause,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // 총 시간
          Text(
            _formatDuration(totalDuration),
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 4),
          // ▷ 프레임 앞으로
          _ControlIcon(Icons.chevron_right_rounded, onStepForward),
          // ⏭ 끝으로
          _ControlIcon(Icons.skip_next_rounded, onJumpToEnd),
        ],
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final totalSeconds = d.inSeconds;
    if (totalSeconds >= 3600) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
    final min = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$min:$sec';
  }
}

class _ControlIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ControlIcon(this.icon, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(icon, color: Colors.white54, size: 20),
      ),
    );
  }
}
