import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/climbing_gym.dart';
import '../providers/gym_stats_provider.dart';

class GymDetailScreen extends ConsumerWidget {
  final ClimbingGym gym;
  const GymDetailScreen({super.key, required this.gym});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasLocation = gym.latitude != null && gym.longitude != null;
    final latLng = hasLocation
        ? LatLng(gym.latitude!, gym.longitude!)
        : null;

    final activeUsers = gym.id != null
        ? ref.watch(gymCrowdednessProvider(gym.id!))
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          gym.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (gym.id != null) {
            ref.invalidate(gymCrowdednessProvider(gym.id!));
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
        children: [
          // 지도 영역
          SizedBox(
            height: 300,
            child: hasLocation
                ? GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: latLng!,
                      zoom: 16,
                    ),
                    markers: {
                      Marker(
                        markerId: MarkerId(gym.id ?? gym.name),
                        position: latLng,
                        infoWindow: InfoWindow(title: gym.name),
                      ),
                    },
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: true,
                    mapToolbarEnabled: false,
                  )
                : Container(
                    color: const Color(0xFFF0F0F0),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_off_outlined,
                            size: 48,
                            color: colorScheme.onSurface.withOpacity(0.3),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '위치 정보가 없습니다',
                            style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          // 암장 정보
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        gym.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (gym.address != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.map_outlined,
                        size: 18,
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          gym.address!,
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurface.withOpacity(0.7),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // 실시간 활동 유저
                if (activeUsers != null) ...[
                  const SizedBox(height: 20),
                  _ActiveUsersCard(activeUsers: activeUsers),
                ],
              ],
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }
}

class _ActiveUsersCard extends StatelessWidget {
  final AsyncValue<int> activeUsers;
  const _ActiveUsersCard({required this.activeUsers});

  @override
  Widget build(BuildContext context) {
    return activeUsers.when(
      loading: () => const SizedBox(
        height: 56,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (count) {
        final dotColor = count == 0
            ? Colors.grey[400]!
            : const Color(0xFF4CAF50);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // 깜빡이는 점 (활동 중일 때)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  count > 0
                      ? '최근 1시간 동안 $count명이 등반을 기록 중이에요!'
                      : '최근 1시간 동안 등반 기록이 없네요ㅠ 주변 지인들에게 리클림 앱을 소개해보세요~!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
