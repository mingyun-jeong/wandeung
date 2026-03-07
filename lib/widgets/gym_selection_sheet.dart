import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../models/climbing_gym.dart';
import '../providers/gym_provider.dart';
import 'gym_map_sheet.dart';

/// Result from GymSelectionSheet: either a gym pick, manual name, or open-map request.
enum _GymSelectionResult { gym, manual, openMap }

class _GymSelectionData {
  final _GymSelectionResult type;
  final ClimbingGym? gym;
  final String? manualName;
  const _GymSelectionData.gym(this.gym)
      : type = _GymSelectionResult.gym,
        manualName = null;
  const _GymSelectionData.manual(this.manualName)
      : type = _GymSelectionResult.manual,
        gym = null;
  const _GymSelectionData.openMap()
      : type = _GymSelectionResult.openMap,
        gym = null,
        manualName = null;
}

class GymSelectionSheet extends ConsumerStatefulWidget {
  final ClimbingGym? currentGym;
  final String? currentManualName;

  const GymSelectionSheet({
    super.key,
    this.currentGym,
    this.currentManualName,
  });

  /// Shows the gym selection sheet. Handles map picker flow internally.
  static Future<void> show(
    BuildContext context, {
    ClimbingGym? currentGym,
    String? currentManualName,
    required ValueChanged<ClimbingGym> onGymSelected,
    required ValueChanged<String> onManualInput,
  }) async {
    final result = await showModalBottomSheet<_GymSelectionData>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => GymSelectionSheet(
        currentGym: currentGym,
        currentManualName: currentManualName,
      ),
    );

    if (result == null) return;

    switch (result.type) {
      case _GymSelectionResult.gym:
        if (result.gym != null) onGymSelected(result.gym!);
      case _GymSelectionResult.manual:
        if (result.manualName != null) onManualInput(result.manualName!);
      case _GymSelectionResult.openMap:
        if (!context.mounted) return;
        final gym = await GymMapSheet.pick(context);
        if (gym != null) onGymSelected(gym);
    }
  }

  @override
  ConsumerState<GymSelectionSheet> createState() => _GymSelectionSheetState();
}

class _GymSelectionSheetState extends ConsumerState<GymSelectionSheet> {
  bool _isManualMode = false;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.currentManualName != null) {
      _isManualMode = true;
      _controller.text = widget.currentManualName!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  @override
  Widget build(BuildContext context) {
    final nearbyGyms = ref.watch(nearbyGymsProvider);
    final position = ref.watch(userPositionProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        32 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('암장 선택',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    letterSpacing: -0.3,
                    color: Theme.of(context).colorScheme.onSurface,
                  )),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(
                      context, const _GymSelectionData.openMap());
                },
                icon: const Icon(Icons.map_outlined, size: 16),
                label: const Text('지도에서 찾기'),
              ),
              TextButton(
                onPressed: () =>
                    setState(() => _isManualMode = !_isManualMode),
                child: Text(_isManualMode ? '목록에서 선택' : '직접 입력'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isManualMode)
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '클라이밍장 이름 입력 후 엔터',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (value) {
                final trimmed = value.trim();
                if (trimmed.isNotEmpty) {
                  Navigator.pop(
                      context, _GymSelectionData.manual(trimmed));
                }
              },
            )
          else
            nearbyGyms.when(
              data: (gyms) {
                if (gyms.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('주변 클라이밍장을 찾을 수 없습니다. 직접 입력해주세요.',
                        style: TextStyle(color: Colors.grey)),
                  );
                }
                final pos = position.valueOrNull;
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: gyms.length,
                    itemBuilder: (_, i) {
                      final gym = gyms[i];
                      final isSelected = (gym.googlePlaceId != null &&
                              widget.currentGym?.googlePlaceId != null)
                          ? gym.googlePlaceId ==
                              widget.currentGym!.googlePlaceId
                          : gym.name == widget.currentGym?.name;
                      String? distText;
                      if (pos != null &&
                          gym.latitude != null &&
                          gym.longitude != null) {
                        final dist = Geolocator.distanceBetween(
                          pos.latitude,
                          pos.longitude,
                          gym.latitude!,
                          gym.longitude!,
                        );
                        distText = _formatDistance(dist);
                      }
                      return InkWell(
                        onTap: () {
                          Navigator.pop(
                              context, _GymSelectionData.gym(gym));
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      gym.name,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Colors.black87,
                                      ),
                                    ),
                                    if (gym.address != null)
                                      Text(
                                        gym.address!,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              if (distText != null)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Text(
                                    distText,
                    style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.4),
                                  ),
                                  ),
                                ),
                              if (isSelected)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Icon(Icons.check,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      size: 20),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('위치 정보를 가져올 수 없습니다',
                    style: TextStyle(color: Colors.red.shade700)),
              ),
            ),
        ],
      ),
    );
  }
}
