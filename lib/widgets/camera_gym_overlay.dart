import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/camera_settings_provider.dart';
import '../providers/gym_provider.dart';

class CameraGymOverlay extends ConsumerWidget {
  const CameraGymOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(cameraSettingsProvider);
    final gymName =
        settings.selectedGym?.name ?? settings.manualGymName ?? '암장 선택';

    return GestureDetector(
      onTap: () => _showGymSheet(context, ref),
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
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                gymName,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  void _showGymSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _GymSheet(ref: ref),
    );
  }
}

class _GymSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _GymSheet({required this.ref});

  @override
  ConsumerState<_GymSheet> createState() => _GymSheetState();
}

class _GymSheetState extends ConsumerState<_GymSheet> {
  bool _isManualMode = false;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    final settings = widget.ref.read(cameraSettingsProvider);
    if (settings.manualGymName != null) {
      _isManualMode = true;
      _controller.text = settings.manualGymName!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nearbyGyms = ref.watch(nearbyGymsProvider);
    final settings = ref.watch(cameraSettingsProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('암장',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              TextButton(
                onPressed: () => setState(() => _isManualMode = !_isManualMode),
                child: Text(_isManualMode ? '목록에서 선택' : '직접 입력'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isManualMode)
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: '클라이밍장 이름 입력',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (name) {
                ref.read(cameraSettingsProvider.notifier).setManualGymName(name);
              },
            )
          else
            nearbyGyms.when(
              data: (gyms) => gyms.isEmpty
                  ? const Text('등록된 클라이밍장이 없습니다. 직접 입력해주세요.',
                      style: TextStyle(color: Colors.grey))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: gyms.map((gym) {
                        final isSelected = gym.id == settings.selectedGym?.id;
                        return ChoiceChip(
                          label: Text(gym.name),
                          selected: isSelected,
                          onSelected: (_) {
                            ref
                                .read(cameraSettingsProvider.notifier)
                                .setGym(gym);
                            Navigator.pop(context);
                          },
                        );
                      }).toList(),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('위치 정보를 가져올 수 없습니다',
                  style: TextStyle(color: Colors.red.shade700)),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
