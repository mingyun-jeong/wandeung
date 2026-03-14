import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/video_edit_models.dart';
import '../../providers/video_editor_provider.dart';

/// 비디오 프리뷰 위에 표시되는 드래그 가능한 오버레이 레이어
class OverlayLayer extends ConsumerWidget {
  final Size previewSize;
  final Duration currentPosition;

  const OverlayLayer({
    super.key,
    required this.previewSize,
    required this.currentPosition,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlays = ref.watch(overlaysProvider);
    final selectedId = ref.watch(selectedOverlayIdProvider);

    // 현재 시간에 보이는 오버레이만 필터링
    final visibleOverlays =
        overlays.where((o) => o.isVisibleAt(currentPosition)).toList();

    return Stack(
      children: visibleOverlays.map((item) {
        final left = item.position.dx * previewSize.width;
        final top = item.position.dy * previewSize.height;
        final isSelected = item.id == selectedId;

        return Positioned(
          left: left,
          top: top,
          child: FractionalTranslation(
            translation: const Offset(-0.5, -0.5),
            child: _InteractiveSticker(
              item: item,
              isSelected: isSelected,
              previewSize: previewSize,
              onTap: () {
                ref.read(selectedOverlayIdProvider.notifier).state =
                    isSelected ? null : item.id;
              },
              onPositionUpdate: (newDx, newDy) {
                ref.read(overlaysProvider.notifier).updatePosition(
                      item.id,
                      Offset(newDx.clamp(0.0, 1.0), newDy.clamp(0.0, 1.0)),
                    );
              },
              onScaleUpdate: (newFontSize, newRotation) {
                ref.read(overlaysProvider.notifier).updateOverlay(
                      item.id,
                      item.copyWith(
                        fontSize: newFontSize.clamp(12.0, 96.0),
                        rotation: newRotation,
                      ),
                    );
              },
              onLongPress: () {
                _showDeleteDialog(context, ref, item);
              },
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

/// 핀치 줌/회전 + 드래그를 지원하는 스티커 위젯
class _InteractiveSticker extends StatefulWidget {
  final OverlayItem item;
  final bool isSelected;
  final Size previewSize;
  final VoidCallback onTap;
  final void Function(double dx, double dy) onPositionUpdate;
  final void Function(double fontSize, double rotation) onScaleUpdate;
  final VoidCallback onLongPress;

  const _InteractiveSticker({
    required this.item,
    required this.isSelected,
    required this.previewSize,
    required this.onTap,
    required this.onPositionUpdate,
    required this.onScaleUpdate,
    required this.onLongPress,
  });

  @override
  State<_InteractiveSticker> createState() => _InteractiveStickerState();
}

class _InteractiveStickerState extends State<_InteractiveSticker> {
  double _baseScale = 1.0;
  double _baseRotation = 0.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onScaleStart: (details) {
        _baseScale = widget.item.fontSize;
        _baseRotation = widget.item.rotation;
      },
      onScaleUpdate: (details) {
        if (details.pointerCount == 1) {
          // 단일 터치: 드래그
          final left = widget.item.position.dx * widget.previewSize.width;
          final top = widget.item.position.dy * widget.previewSize.height;
          final newDx = (left + details.focalPointDelta.dx) /
              widget.previewSize.width;
          final newDy = (top + details.focalPointDelta.dy) /
              widget.previewSize.height;
          widget.onPositionUpdate(newDx, newDy);
        } else {
          // 멀티 터치: 핀치 줌 + 회전
          final newFontSize = _baseScale * details.scale;
          final newRotation = _baseRotation + details.rotation;
          widget.onScaleUpdate(newFontSize, newRotation);
        }
      },
      child: Transform.rotate(
        angle: widget.item.rotation,
        child: Container(
          decoration: widget.isSelected
              ? BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(16),
                )
              : null,
          padding: widget.isSelected ? const EdgeInsets.all(2) : null,
          child: _OverlaySticker(item: widget.item),
        ),
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
    final bgColor = item.backgroundColor;

    // 배경색이 없으면 이모지 전용: 배경/그림자 없이 텍스트만 표시
    if (bgColor == null) {
      return Text(
        item.text,
        style: TextStyle(
          fontSize: item.fontSize,
        ),
      );
    }

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
