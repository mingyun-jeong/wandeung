import 'package:flutter/material.dart';

/// 빠른 편집 액션 바
///
/// 처음부터 | 여기부터 | 분할 | 여기까지 | 끝까지
class QuickActionBar extends StatelessWidget {
  final VoidCallback? onFromStart;
  final VoidCallback? onFromHere;
  final VoidCallback? onSplit;
  final VoidCallback? onToHere;
  final VoidCallback? onToEnd;

  const QuickActionBar({
    super.key,
    this.onFromStart,
    this.onFromHere,
    this.onSplit,
    this.onToHere,
    this.onToEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionItem(
            icon: Icons.first_page_rounded,
            label: '처음부터',
            onTap: onFromStart,
          ),
          _ActionItem(
            icon: Icons.arrow_right_alt_rounded,
            label: '여기부터',
            onTap: onFromHere,
          ),
          _ActionItem(
            icon: Icons.content_cut_rounded,
            label: '분할',
            onTap: onSplit,
            highlighted: true,
          ),
          _ActionItem(
            icon: Icons.arrow_left_rounded,
            label: '여기까지',
            onTap: onToHere,
          ),
          _ActionItem(
            icon: Icons.last_page_rounded,
            label: '끝까지',
            onTap: onToEnd,
          ),
        ],
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool highlighted;

  const _ActionItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = enabled
        ? (highlighted ? Colors.white : Colors.white70)
        : Colors.white24;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
