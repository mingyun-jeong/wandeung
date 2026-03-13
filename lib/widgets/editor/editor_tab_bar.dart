import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/video_editor_provider.dart';

/// 편집 화면 하단 탭 바
class EditorTabBar extends ConsumerWidget {
  const EditorTabBar({super.key});

  static const _tabs = [
    (EditorTab.trim, Icons.content_cut, '트림'),
    (EditorTab.speed, Icons.speed, '속도'),
    (EditorTab.text, Icons.title, '텍스트'),
    (EditorTab.sticker, Icons.emoji_emotions, '스티커'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedEditorTabProvider);

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: _tabs.map((tab) {
          final (type, icon, label) = tab;
          final isSelected = selected == type;

          return Expanded(
            child: GestureDetector(
              onTap: () =>
                  ref.read(selectedEditorTabProvider.notifier).state = type,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 24,
                      color: isSelected ? Colors.white : Colors.white38,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.normal,
                        color: isSelected ? Colors.white : Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
