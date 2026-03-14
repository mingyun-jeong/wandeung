import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/video_editor_provider.dart';

/// VLLO 스타일 하단 필(pill) 버튼 탭 바
///
/// [ 트림 ] [ 속도 ] [ 텍스트 ] [ 스티커 ]
class EditorTabBar extends ConsumerWidget {
  const EditorTabBar({super.key});

  static const _tabs = [
    (EditorTab.trim, '트림'),
    (EditorTab.speed, '속도'),
    (EditorTab.text, '텍스트'),
    (EditorTab.sticker, '스티커'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedEditorTabProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _tabs.map((tab) {
          final (type, label) = tab;
          final isSelected = selected == type;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () =>
                  ref.read(selectedEditorTabProvider.notifier).state = type,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white54,
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
