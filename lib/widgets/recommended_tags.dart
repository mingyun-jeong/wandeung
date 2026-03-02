import 'package:flutter/material.dart';

class RecommendedTags extends StatelessWidget {
  final List<String> currentTags;
  final ValueChanged<List<String>> onTagsChanged;

  const RecommendedTags({
    super.key,
    required this.currentTags,
    required this.onTagsChanged,
  });

  static const recommendedTags = [
    '#다이나믹',
    '#슬랩',
    '#발컨',
    '#힐훅',
    '#토훅',
    '#맨틀링',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('추천 태그',
            style: TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: recommendedTags.map((tag) {
            final isSelected = currentTags.contains(tag);
            return GestureDetector(
              onTap: () {
                final updated = List<String>.from(currentTags);
                if (isSelected) {
                  updated.remove(tag);
                } else {
                  updated.add(tag);
                }
                onTagsChanged(updated);
              },
              child: Chip(
                label: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? Colors.green.shade700 : Colors.grey.shade600,
                  ),
                ),
                backgroundColor:
                    isSelected ? Colors.green.shade50 : Colors.grey.shade100,
                side: BorderSide(
                  color: isSelected ? Colors.green.shade300 : Colors.grey.shade300,
                ),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
