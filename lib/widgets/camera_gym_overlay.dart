import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'instagram_icon.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/camera_settings_provider.dart';
import '../providers/gym_color_scale_provider.dart';
import '../providers/gym_instagram_provider.dart';
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
                Text(
                  gymName.length > 8 ? '${gymName.substring(0, 8)}..' : gymName,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
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

        // Instagram icon — opens instagram page (DB에서 place_id로 조회)
        if (settings.selectedGym?.googlePlaceId != null)
          _InstagramButton(placeId: settings.selectedGym!.googlePlaceId!),
      ],
    );
  }

  static void _openInstagram(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showGymSelection(BuildContext context, WidgetRef ref) {
    final settings = ref.read(cameraSettingsProvider);
    GymSelectionSheet.show(
      context,
      currentGym: settings.selectedGym,
      onGymSelected: (gym) {
        ref.read(cameraSettingsProvider.notifier).setGym(gym);
        // 브랜드 색상표가 있으면 Lv.1(최고 난이도) 색상으로 기본값 설정
        final colorScale = ref.read(gymColorScaleProvider(gym.name));
        if (colorScale != null && colorScale.levels.isNotEmpty) {
          final lv1 = colorScale.levels.first;
          ref.read(cameraSettingsProvider.notifier).setColor(lv1.color);
          ref.read(cameraSettingsProvider.notifier).setGrade(lv1.vMin);
        }
      },
    );
  }
}

class _InstagramButton extends ConsumerWidget {
  final String placeId;
  const _InstagramButton({required this.placeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instagramUrl = ref.watch(gymInstagramByPlaceIdProvider(placeId)).valueOrNull;
    if (instagramUrl == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: GestureDetector(
        onTap: () => CameraGymOverlay._openInstagram(instagramUrl),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: const InstagramIcon(size: 18),
        ),
      ),
    );
  }
}
