import 'package:flutter/material.dart';
import '../models/gym_color_scale.dart';
import '../utils/constants.dart';

class DifficultySelector extends StatelessWidget {
  final DifficultyColor? selectedColor;
  final ValueChanged<DifficultyColor> onColorChanged;

  /// 브랜드 색상표가 있으면 해당 색상만 순서대로 표시
  final GymColorScale? colorScale;

  const DifficultySelector({
    super.key,
    this.selectedColor,
    required this.onColorChanged,
    this.colorScale,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // 브랜드 색상표가 있으면 해당 색상만, 없으면 전체 색상
    final colors = colorScale != null
        ? colorScale!.levels.map((l) => l.color).toList()
        : DifficultyColor.values.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('난이도 색상',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: colorScheme.onSurface,
                )),
            if (colorScale != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  colorScale!.brandName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: colors.map((dc) {
            final isSelected = dc == selectedColor;
            final baseColor = Color(dc.colorValue);
            final level = colorScale?.levelForColor(dc);

            // 무지개 색상은 그래디언트로 표시
            final isRainbow = dc == DifficultyColor.rainbow;
            // 별 색상은 별 아이콘으로 표시
            final isStar = dc == DifficultyColor.star;

            return GestureDetector(
              onTap: () => onColorChanged(dc),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isRainbow ? null : baseColor,
                      gradient: isRainbow
                          ? const SweepGradient(colors: [
                              Colors.red,
                              Colors.orange,
                              Colors.yellow,
                              Colors.green,
                              Colors.blue,
                              Colors.purple,
                              Colors.red,
                            ])
                          : null,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.primary
                            : Colors.black.withOpacity(0.08),
                        width: isSelected ? 3 : 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: baseColor.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: isStar
                        ? Icon(Icons.star_rounded,
                            color: isSelected ? colorScheme.primary : Colors.white,
                            size: 22)
                        : isSelected
                            ? Icon(Icons.check_rounded,
                                color: dc.needsDarkIcon
                                    ? Colors.black87
                                    : Colors.white,
                                size: 20)
                            : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    level != null
                        ? 'Lv.${colorScale!.levels.length - level.level + 1}'
                        : dc.korean,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  if (level != null)
                    Text(
                      level.vRangeLabel,
                      style: TextStyle(
                        fontSize: 8,
                        color: colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
