import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/subtitle_item.dart';
import '../../providers/subtitle_provider.dart';

/// 비디오 프리뷰 위에 현재 시간에 해당하는 자막을 표시하고 드래그로 위치 조절
/// 선택된 자막에는 인라인 편집 툴바(크기/기울기/굵기) 표시
class SubtitleOverlayLayer extends ConsumerWidget {
  final Size previewSize;
  final Duration currentPosition;
  final VoidCallback? onSubtitleTap;

  const SubtitleOverlayLayer({
    super.key,
    required this.previewSize,
    required this.currentPosition,
    this.onSubtitleTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitles = ref.watch(subtitlesProvider);
    final selectedId = ref.watch(selectedSubtitleIdProvider);

    final visible =
        subtitles.where((s) => s.isVisibleAt(currentPosition)).toList();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ...visible.map((item) {
          final left = item.position.dx * previewSize.width;
          final top = item.position.dy * previewSize.height;
          final isSelected = item.id == selectedId;

          return Positioned(
            left: left,
            top: top,
            child: FractionalTranslation(
              translation: const Offset(-0.5, -0.5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onPanUpdate: (details) {
                      final newDx =
                          (left + details.delta.dx) / previewSize.width;
                      final newDy =
                          (top + details.delta.dy) / previewSize.height;
                      ref.read(subtitlesProvider.notifier).updatePosition(
                            item.id,
                            Offset(
                                newDx.clamp(0.0, 1.0), newDy.clamp(0.0, 1.0)),
                          );
                    },
                    onTap: () {
                      if (isSelected) {
                        ref.read(selectedSubtitleIdProvider.notifier).state =
                            null;
                      } else {
                        ref.read(selectedSubtitleIdProvider.notifier).state =
                            item.id;
                      }
                    },
                    onDoubleTap: () {
                      ref.read(selectedSubtitleIdProvider.notifier).state =
                          item.id;
                      onSubtitleTap?.call();
                    },
                    onLongPress: () {
                      _showDeleteDialog(context, ref, item);
                    },
                    child: Container(
                      decoration: isSelected
                          ? BoxDecoration(
                              border:
                                  Border.all(color: Colors.blue, width: 2),
                              borderRadius: BorderRadius.circular(4),
                            )
                          : null,
                      child: Transform.rotate(
                        angle: item.rotation,
                        child: _SubtitleDisplay(item: item),
                      ),
                    ),
                  ),
                  if (isSelected)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _InlineEditToolbar(
                        item: item,
                        onChanged: (updated) {
                          ref
                              .read(subtitlesProvider.notifier)
                              .updateSubtitle(item.id, updated);
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _showDeleteDialog(
      BuildContext context, WidgetRef ref, SubtitleItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Text 삭제'),
        content: Text("'${item.text}' 텍스트를 삭제할까요?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              ref.read(subtitlesProvider.notifier).removeSubtitle(item.id);
              Navigator.pop(ctx);
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// 자막 선택 시 표시되는 인라인 편집 툴바
class _InlineEditToolbar extends StatelessWidget {
  final SubtitleItem item;
  final ValueChanged<SubtitleItem> onChanged;

  const _InlineEditToolbar({
    required this.item,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 크기 줄이기
          _ToolButton(
            icon: Icons.text_decrease,
            onTap: () {
              final newSize = (item.fontSize - 2).clamp(12.0, 72.0);
              onChanged(item.copyWith(fontSize: newSize));
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${item.fontSize.round()}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
          // 크기 키우기
          _ToolButton(
            icon: Icons.text_increase,
            onTap: () {
              final newSize = (item.fontSize + 2).clamp(12.0, 72.0);
              onChanged(item.copyWith(fontSize: newSize));
            },
          ),
          const _ToolDivider(),
          // 반시계 회전
          _ToolButton(
            icon: Icons.rotate_left,
            onTap: () {
              final newRotation = item.rotation - (math.pi / 36); // -5°
              onChanged(item.copyWith(rotation: newRotation));
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${(item.rotation * 180 / math.pi).round()}°',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
          // 시계 회전
          _ToolButton(
            icon: Icons.rotate_right,
            onTap: () {
              final newRotation = item.rotation + (math.pi / 36); // +5°
              onChanged(item.copyWith(rotation: newRotation));
            },
          ),
          // 회전 리셋
          if (item.rotation != 0.0) ...[
            const SizedBox(width: 2),
            _ToolButton(
              icon: Icons.replay,
              onTap: () => onChanged(item.copyWith(rotation: 0.0)),
            ),
          ],
          const _ToolDivider(),
          // 굵기 토글
          _ToolButton(
            icon: Icons.format_bold,
            isActive: item.isBold,
            onTap: () => onChanged(item.copyWith(isBold: !item.isBold)),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;

  const _ToolButton({
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          size: 18,
          color: isActive ? Colors.blue : Colors.white70,
        ),
      ),
    );
  }
}

class _ToolDivider extends StatelessWidget {
  const _ToolDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.white24,
    );
  }
}

class _SubtitleDisplay extends StatelessWidget {
  final SubtitleItem item;
  const _SubtitleDisplay({required this.item});

  @override
  Widget build(BuildContext context) {
    // 항상 최소 그림자를 적용하여 영상 위에서 텍스트가 보이도록 함
    final shadows = item.hasShadow
        ? [
            const Shadow(
              color: Color(0x80000000),
              offset: Offset(1, 1),
              blurRadius: 2,
            ),
          ]
        : [
            const Shadow(
              color: Color(0xAA000000),
              offset: Offset(0.5, 0.5),
              blurRadius: 1,
            ),
          ];

    Widget text = Text(
      item.text,
      style: TextStyle(
        fontSize: item.fontSize,
        color: item.color,
        fontWeight: item.isBold ? FontWeight.w800 : FontWeight.normal,
        shadows: shadows,
      ),
    );

    if (item.strokeColor != null && item.strokeWidth > 0) {
      text = Stack(
        children: [
          Text(
            item.text,
            style: TextStyle(
              fontSize: item.fontSize,
              fontWeight: item.isBold ? FontWeight.w800 : FontWeight.normal,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = item.strokeWidth
                ..color = item.strokeColor!,
            ),
          ),
          text,
        ],
      );
    }

    if (item.backgroundColor != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: item.backgroundColor!.withOpacity(0.6),
          borderRadius: BorderRadius.circular(4),
        ),
        child: text,
      );
    }

    return text;
  }
}
