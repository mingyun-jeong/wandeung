import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/video_edit_models.dart';
import '../../providers/video_editor_provider.dart';

/// 비디오 프리뷰 위에 표시되는 드래그 가능한 오버레이 레이어
class OverlayLayer extends ConsumerWidget {
  final Size previewSize;

  const OverlayLayer({super.key, required this.previewSize});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlays = ref.watch(overlaysProvider);

    return Stack(
      children: overlays.map((item) {
        // 정규화 좌표(0~1)를 프리뷰 픽셀 좌표로 변환
        final left = item.position.dx * previewSize.width;
        final top = item.position.dy * previewSize.height;

        return Positioned(
          left: left,
          top: top,
          child: FractionalTranslation(
            translation: const Offset(-0.5, -0.5),
            child: GestureDetector(
              onPanUpdate: (details) {
                final newDx =
                    (left + details.delta.dx) / previewSize.width;
                final newDy =
                    (top + details.delta.dy) / previewSize.height;
                ref.read(overlaysProvider.notifier).updatePosition(
                      item.id,
                      Offset(newDx.clamp(0.0, 1.0), newDy.clamp(0.0, 1.0)),
                    );
              },
              onLongPress: () {
                _showDeleteDialog(context, ref, item);
              },
              child: _OverlaySticker(item: item),
            ),
          ),
        );
      }).toList(),
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

/// V-Grade 스티커 위젯 (record_card.dart의 _GradeBadge 스타일 기반)
class _OverlaySticker extends StatelessWidget {
  final OverlayItem item;
  const _OverlaySticker({required this.item});

  @override
  Widget build(BuildContext context) {
    final bgColor = item.backgroundColor ?? Colors.black54;
    final isLight = bgColor == const Color(0xFFFFFFFF) ||
        bgColor.computeLuminance() > 0.7;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        item.text,
        style: TextStyle(
          color: isLight ? Colors.black87 : Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: item.fontSize,
        ),
      ),
    );
  }
}
