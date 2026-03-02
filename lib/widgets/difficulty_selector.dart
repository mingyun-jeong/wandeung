import 'package:flutter/material.dart';
import '../utils/constants.dart';

class DifficultySelector extends StatelessWidget {
  final ClimbingGrade? selectedGrade;
  final DifficultyColor? selectedColor;
  final ValueChanged<ClimbingGrade> onGradeChanged;
  final ValueChanged<DifficultyColor> onColorChanged;

  const DifficultySelector({
    super.key,
    this.selectedGrade,
    this.selectedColor,
    required this.onGradeChanged,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('난이도 등급',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ClimbingGrade.values.map((grade) {
            final isSelected = grade == selectedGrade;
            return ChoiceChip(
              label: Text(grade.label),
              selected: isSelected,
              onSelected: (_) => onGradeChanged(grade),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        const Text('난이도 색상',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: DifficultyColor.values.map((dc) {
            final isSelected = dc == selectedColor;
            return GestureDetector(
              onTap: () => onColorChanged(dc),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(dc.colorValue),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.green : Colors.grey.shade300,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: isSelected
                        ? Icon(Icons.check,
                            color: dc == DifficultyColor.white
                                ? Colors.black
                                : Colors.white,
                            size: 20)
                        : null,
                  ),
                  const SizedBox(height: 2),
                  Text(dc.korean,
                      style: const TextStyle(fontSize: 10)),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
