import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/camera_settings_provider.dart';
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
                color: settings.color != null
                    ? Color(settings.color!.colorValue)
                    : Colors.grey,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white54, width: 1.5),
              ),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ColorSheet(ref: ref),
    );
  }
}

class _ColorSheet extends StatelessWidget {
  final WidgetRef ref;
  const _ColorSheet({required this.ref});

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(cameraSettingsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('난이도 색상',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: DifficultyColor.values.map((dc) {
              final isSelected = dc == settings.color;
              return GestureDetector(
                onTap: () {
                  ref.read(cameraSettingsProvider.notifier).setColor(dc);
                  Navigator.pop(context);
                },
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Color(dc.colorValue),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade300,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: isSelected
                          ? Icon(Icons.check,
                              color: dc == DifficultyColor.white
                                  ? Colors.black
                                  : Colors.white,
                              size: 22)
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(dc.korean,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade600,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        )),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
