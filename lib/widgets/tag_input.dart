import 'package:flutter/material.dart';

class TagInput extends StatefulWidget {
  final List<String> tags;
  final ValueChanged<List<String>> onTagsChanged;
  final bool showLabel;

  static const recommendedTags = [
    '#다이나믹',
    '#슬랩',
    '#발컨',
    '#힐훅',
    '#토훅',
    '#맨틀링',
    '#캠퍼스',
    '#크림프',
    '#런지',
    '#볼더링',
  ];

  const TagInput({
    super.key,
    required this.tags,
    required this.onTagsChanged,
    this.showLabel = true,
  });

  @override
  State<TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<TagInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  List<String> get _customTags =>
      widget.tags.where((t) => !TagInput.recommendedTags.contains(t)).toList();

  void _addTag() {
    var text = _controller.text.trim();
    if (text.isEmpty) return;
    if (!text.startsWith('#')) text = '#$text';
    if (!widget.tags.contains(text)) {
      widget.onTagsChanged([...widget.tags, text]);
    }
    _controller.clear();
  }

  void _toggleRecommended(String tag) {
    final updated = List<String>.from(widget.tags);
    if (updated.contains(tag)) {
      updated.remove(tag);
    } else {
      updated.add(tag);
    }
    widget.onTagsChanged(updated);
  }

  void _removeCustomTag(String tag) {
    widget.onTagsChanged(widget.tags.where((t) => t != tag).toList());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customTags = _customTags;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showLabel) ...[
          Text('태그',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurface,
              )),
          const SizedBox(height: 10),
        ],

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TagInput.recommendedTags.map((tag) {
            final isSelected = widget.tags.contains(tag);
            final colorScheme = Theme.of(context).colorScheme;
            return GestureDetector(
              onTap: () => _toggleRecommended(tag),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary.withOpacity(0.08)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.primary.withOpacity(0.4)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      Icon(Icons.check_rounded,
                          size: 14, color: colorScheme.primary),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      tag,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface.withOpacity(0.55),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        if (customTags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: customTags
                .map((tag) {
                  final colorScheme = Theme.of(context).colorScheme;
                  return Container(
                    padding: const EdgeInsets.only(
                        left: 12, right: 6, top: 6, bottom: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: colorScheme.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tag,
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 2),
                        GestureDetector(
                          onTap: () => _removeCustomTag(tag),
                          child: Icon(Icons.close,
                              size: 15,
                              color: colorScheme.primary.withOpacity(0.5)),
                        ),
                      ],
                    ),
                  );
                })
                .toList(),
          ),
        ],

        const SizedBox(height: 10),

        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: '#태그 입력',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    hintStyle: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.3)),
                  ),
                  onSubmitted: (_) => _addTag(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: IconButton(
                  onPressed: _addTag,
                  icon: Icon(Icons.add_circle_rounded,
                      color: Theme.of(context).colorScheme.primary, size: 26),
                  tooltip: '태그 추가',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
