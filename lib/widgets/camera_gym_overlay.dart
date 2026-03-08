import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/camera_settings_provider.dart';
import 'gym_map_sheet.dart';
import 'gym_selection_sheet.dart';

class CameraGymOverlay extends ConsumerWidget {
  const CameraGymOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(cameraSettingsProvider);
    final gymName = settings.selectedGym?.name ?? '암장 선택';
    final hasCoords = settings.selectedGym?.latitude != null &&
        settings.selectedGym?.longitude != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main chip — opens gym selection
        GestureDetector(
          onTap: () => _showGymSelection(context, ref),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(
                    gymName,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down,
                    color: Colors.white, size: 20),
              ],
            ),
          ),
        ),

        // Map icon — opens map confirmation (only when gym has coordinates)
        if (hasCoords) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => GymMapSheet.show(
              context,
              selectedGym: settings.selectedGym!,
            ),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.map_outlined,
                  color: Colors.white, size: 18),
            ),
          ),
        ],
      ],
    );
  }

  void _showGymSelection(BuildContext context, WidgetRef ref) {
    final settings = ref.read(cameraSettingsProvider);
    GymSelectionSheet.show(
      context,
      currentGym: settings.selectedGym,
      onGymSelected: (gym) {
        ref.read(cameraSettingsProvider.notifier).setGym(gym);
      },
    );
  }
}
