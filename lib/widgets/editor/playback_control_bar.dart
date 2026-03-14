import 'package:flutter/material.dart';

/// 영상 프리뷰 아래 재생 컨트롤 바
///
/// ⏮ ◀ advancement 00:05 / 00:49 ▶ ⏭
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ⏮ 처음으로
          _ControlButton(
            icon: Icons.skip_previous_rounded,
            onTap: onJumpToStart,
            size: 22,
          ),
          const SizedBox(width: 8),
          // ◀ 프레임 뒤로
          _ControlButton(
            icon: Icons.fast_rewind_rounded,
            onTap: onStepBackward,
            size: 22,
          ),
          const SizedBox(width: 12),
          // 시간 표시
          Text(
            _formatDuration(currentPosition),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          // 재생/정지
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: GestureDetector(
              onTap: onPlayPause,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
          Text(
            _formatDuration(totalDuration),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 12),
          // ▶ 프레임 앞으로
          _ControlButton(
            icon: Icons.fast_forward_rounded,
            onTap: onStepForward,
            size: 22,
          ),
          const SizedBox(width: 8),
          // ⏭ 끝으로
          _ControlButton(
            icon: Icons.skip_next_rounded,
            onTap: onJumpToEnd,
            size: 22,
          ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final min = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$min:$sec';
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _ControlButton({
    required this.icon,
    required this.onTap,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, color: Colors.white70, size: size),
      ),
    );
  }
}
