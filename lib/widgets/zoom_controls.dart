import 'package:flutter/material.dart';

class ZoomControls extends StatelessWidget {
  final double currentZoom;
  final double minZoom;
  final double maxZoom;
  final ValueChanged<double> onZoomChanged;

  const ZoomControls({
    super.key,
    required this.currentZoom,
    required this.minZoom,
    required this.maxZoom,
    required this.onZoomChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // + 버튼
          _ZoomButton(
            icon: Icons.add,
            onTap: currentZoom < maxZoom
                ? () => onZoomChanged(
                    (currentZoom + 0.5).clamp(minZoom, maxZoom))
                : null,
          ),
          // 줌 레벨 표시
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '${currentZoom.toStringAsFixed(1)}x',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // - 버튼
          _ZoomButton(
            icon: Icons.remove,
            onTap: currentZoom > minZoom
                ? () => onZoomChanged(
                    (currentZoom - 0.5).clamp(minZoom, maxZoom))
                : null,
          ),
        ],
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _ZoomButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Colors.white24,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: onTap != null ? Colors.white : Colors.white38,
          size: 18,
        ),
      ),
    );
  }
}
