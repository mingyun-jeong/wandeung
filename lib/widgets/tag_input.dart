import 'package:flutter/material.dart';

class TagInput extends StatefulWidget {
  final List<String> tags;
  final ValueChanged<List<String>> onTagsChanged;

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
        const Text('태그',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 10),

        // 추천 태그 (토글 칩)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TagInput.recommendedTags.map((tag) {
            final isSelected = widget.tags.contains(tag);
            return GestureDetector(
              onTap: () => _toggleRecommended(tag),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color:
                      isSelected ? Colors.green.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? Colors.green.shade300
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      Icon(Icons.check,
                          size: 14, color: Colors.green.shade600),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      tag,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? Colors.green.shade700
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        // 커스텀 태그 (직접 입력한 것만)
        if (customTags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: customTags
                .map((tag) => Container(
                      padding: const EdgeInsets.only(
                          left: 12, right: 6, top: 6, bottom: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tag,
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 2),
                          GestureDetector(
                            onTap: () => _removeCustomTag(tag),
                            child: Icon(Icons.close,
                                size: 15, color: Colors.green.shade400),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],

        const SizedBox(height: 10),

        // 입력 필드
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
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
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                  ),
                  onSubmitted: (_) => _addTag(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: IconButton(
                  onPressed: _addTag,
                  icon: Icon(Icons.add_circle,
                      color: Colors.green.shade400, size: 26),
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
