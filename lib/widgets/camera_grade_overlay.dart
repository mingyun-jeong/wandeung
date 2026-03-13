import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/gym_color_scale.dart';
import '../providers/camera_settings_provider.dart';
import '../providers/gym_color_scale_provider.dart';
import '../utils/constants.dart';

class CameraGradeOverlay extends ConsumerWidget {
  const CameraGradeOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(cameraSettingsProvider);

    return GestureDetector(
      onTap: () => _showColorSheet(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: settings.color == DifficultyColor.rainbow
                    ? null
                    : settings.color != null
                        ? Color(settings.color!.colorValue)
                        : Colors.grey,
                gradient: settings.color == DifficultyColor.rainbow
                    ? const SweepGradient(colors: [
                        Colors.red, Colors.orange, Colors.yellow,
                        Colors.green, Colors.blue, Colors.purple, Colors.red,
                      ])
                    : null,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white54, width: 1.5),
              ),
              child: settings.color == DifficultyColor.star
                  ? const Icon(Icons.star_rounded, color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  void _showColorSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _ColorSheet(),
    );
  }
}

class _ColorSheet extends ConsumerWidget {
  const _ColorSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(cameraSettingsProvider);

    // 브랜드 색상표 조회
    final gymName = settings.selectedGym?.name;
    final GymColorScale? colorScale = gymName != null
        ? ref.watch(gymColorScaleProvider(gymName))
        : null;

    // 브랜드 색상표가 있으면 해당 색상만, 없으면 전체
    final colors = colorScale != null
        ? colorScale.levels.map((l) => l.color).toList()
        : DifficultyColor.values.toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 드래그 핸들
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Text('난이도 색상',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      letterSpacing: -0.3,
                      color: Theme.of(context).colorScheme.onSurface,
                    )),
                if (colorScale != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      colorScale.brandName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color:
                            Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: colors.map((dc) {
                final isSelected = dc == settings.color;
                final baseColor = Color(dc.colorValue);
                final level = colorScale?.levelForColor(dc);
                final isRainbow = dc == DifficultyColor.rainbow;
                final isStar = dc == DifficultyColor.star;

                return GestureDetector(
                  onTap: () {
                    ref.read(cameraSettingsProvider.notifier).setColor(dc);
                    // 브랜드 색상표가 있으면 등급 자동 추천
                    if (colorScale != null) {
                      final lvl = colorScale.levelForColor(dc);
                      if (lvl != null) {
                        ref
                            .read(cameraSettingsProvider.notifier)
                            .setGrade(lvl.vMin);
                      }
                    }
                    Navigator.pop(context);
                  },
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 46,
                        height: 46,
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
                                ? Theme.of(context).colorScheme.primary
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
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.white,
                                size: 24)
                            : isSelected
                                ? Icon(Icons.check_rounded,
                                    color: dc.needsDarkIcon
                                        ? Colors.black87
                                        : Colors.white,
                                    size: 22)
                                : null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        level != null ? 'Lv.${level.level}' : dc.korean,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.5),
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      if (level != null)
                        Text(
                          level.vRangeLabel,
                          style: TextStyle(
                            fontSize: 8,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.4),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
