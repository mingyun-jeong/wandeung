import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/camera_settings_provider.dart';
import '../utils/constants.dart';

class CameraGradeOverlay extends ConsumerWidget {
  const CameraGradeOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(cameraSettingsProvider);
    final hasSelection = settings.grade != null && settings.color != null;

    return GestureDetector(
      onTap: () => _showGradeColorSheet(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 색상 원
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: settings.color != null
                    ? Color(settings.color!.colorValue)
                    : Colors.grey,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white54, width: 1),
              ),
            ),
            const SizedBox(width: 8),
            // 등급 텍스트
            Text(
              hasSelection ? settings.grade!.label : '난이도',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  void _showGradeColorSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _GradeColorSheet(ref: ref),
    );
  }
}

class _GradeColorSheet extends StatelessWidget {
  final WidgetRef ref;
  const _GradeColorSheet({required this.ref});

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(cameraSettingsProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('난이도 등급',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ClimbingGrade.values.map((grade) {
              final isSelected = grade == settings.grade;
              return ChoiceChip(
                label: Text(grade.label),
                selected: isSelected,
                onSelected: (_) =>
                    ref.read(cameraSettingsProvider.notifier).setGrade(grade),
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
              final isSelected = dc == settings.color;
              return GestureDetector(
                onTap: () {
                  ref.read(cameraSettingsProvider.notifier).setColor(dc);
                },
                child: Container(
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
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ),
        ],
      ),
    );
  }
}
