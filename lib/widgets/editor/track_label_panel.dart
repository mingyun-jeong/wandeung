import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/video_editor_provider.dart';

/// VLLO 스타일 좌측 트랙 라벨 패널
///
/// 각 트랙(미디어/속도/텍스트/스티커)의 이름을 세로로 표시하며,
/// 선택된 탭에 해당하는 트랙을 하이라이트한다.
class TrackLabelPanel extends ConsumerWidget {
  final double mediaTrackHeight;
  final double trackHeight;
  final double rulerHeight;
  final double trackGap;

  const TrackLabelPanel({
    super.key,
    this.mediaTrackHeight = 44,
    this.trackHeight = 28,
    this.rulerHeight = 20,
    this.trackGap = 2,
  });

  static const _labelWidth = 52.0;

  static const _tracks = [
    (EditorTab.trim, Icons.movie_outlined, '미디어'),
    (EditorTab.speed, Icons.speed, '속도'),
    (EditorTab.zoom, Icons.crop, '줌'),
    (EditorTab.text, Icons.title, '텍스트'),
    (EditorTab.sticker, Icons.emoji_emotions_outlined, '스티커'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(selectedEditorTabProvider);

    return SizedBox(
      width: _labelWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 룰러 높이만큼 빈 공간
          SizedBox(height: rulerHeight + trackGap),
          // 미디어 트랙 라벨
          _TrackLabel(
            icon: _tracks[0].$2,
            label: _tracks[0].$3,
            height: mediaTrackHeight,
            isActive: selectedTab == _tracks[0].$1,
            showAddButton: true,
          ),
          SizedBox(height: trackGap),
          // 속도/텍스트/스티커 라벨
          for (int i = 1; i < _tracks.length; i++) ...[
            _TrackLabel(
              icon: _tracks[i].$2,
              label: _tracks[i].$3,
              height: trackHeight,
              isActive: selectedTab == _tracks[i].$1,
            ),
            if (i < _tracks.length - 1) SizedBox(height: trackGap),
          ],
        ],
      ),
    );
  }
}

class _TrackLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final double height;
  final bool isActive;
  final bool showAddButton;

  const _TrackLabel({
    required this.icon,
    required this.label,
    required this.height,
    required this.isActive,
    this.showAddButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showAddButton)
            Icon(
              Icons.add_circle_outline,
              size: 12,
              color: isActive ? Colors.white54 : Colors.white24,
            )
          else
            const SizedBox(width: 12),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isActive ? Colors.white70 : Colors.white30,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
