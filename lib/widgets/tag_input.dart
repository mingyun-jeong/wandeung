import 'package:flutter/material.dart';

class TagInput extends StatefulWidget {
  final List<String> tags;
  final ValueChanged<List<String>> onTagsChanged;

  const TagInput({super.key, required this.tags, required this.onTagsChanged});

  @override
  State<TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<TagInput> {
  final _controller = TextEditingController();

  void _addTag() {
    var text = _controller.text.trim();
    if (text.isEmpty) return;
    if (!text.startsWith('#')) text = '#$text';
    if (!widget.tags.contains(text)) {
      widget.onTagsChanged([...widget.tags, text]);
    }
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('태그',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        if (widget.tags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: widget.tags
                .map((tag) => Chip(
                      label: Text(tag),
                      onDeleted: () {
                        widget.onTagsChanged(
                            widget.tags.where((t) => t != tag).toList());
                      },
                    ))
                .toList(),
          ),
        if (widget.tags.isNotEmpty) const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: '#태그 입력 (예: #발컨, #슬탭)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _addTag(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(onPressed: _addTag, icon: const Icon(Icons.add)),
          ],
        ),
      ],
    );
  }
}
