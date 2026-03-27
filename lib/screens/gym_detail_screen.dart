import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/climbing_gym.dart';
import '../providers/gym_photo_provider.dart';
import '../providers/gym_stats_provider.dart';

class GymDetailScreen extends ConsumerWidget {
  final ClimbingGym gym;
  const GymDetailScreen({super.key, required this.gym});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasLocation = gym.latitude != null && gym.longitude != null;
    final latLng =
        hasLocation ? LatLng(gym.latitude!, gym.longitude!) : null;

    final activeUsers =
        gym.id != null ? ref.watch(gymCrowdednessProvider(gym.id!)) : null;

    final photosAsync = gym.googlePlaceId != null
        ? ref.watch(gymPhotoProvider(gym.googlePlaceId!))
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
          if (gym.googlePlaceId != null) {
            ref.invalidate(gymPhotoProvider(gym.googlePlaceId!));
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 썸네일 사진
              if (photosAsync != null)
                photosAsync.when(
                  data: (photos) {
                    if (photos.isEmpty) return const SizedBox.shrink();
                    return SizedBox(
                      height: 220,
                      child: PageView.builder(
                        itemCount: photos.length,
                        itemBuilder: (context, index) => Image.network(
                          photos[index],
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: const Color(0xFFF0F0F0),
                              child: const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFFF0F0F0),
                            child: const Center(
                              child: Icon(Icons.image_not_supported_outlined,
                                  size: 40, color: Color(0xFFBDBDBD)),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  loading: () => Container(
                    height: 220,
                    color: const Color(0xFFF0F0F0),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),

              // 암장 이름
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Text(
                  gym.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),

              // 실시간 활동 유저
              if (activeUsers != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: _ActiveUsersCard(activeUsers: activeUsers),
                ),

              const SizedBox(height: 16),
              const Divider(height: 1, indent: 20, endIndent: 20),
              const SizedBox(height: 8),

              // 정보 리스트
              if (gym.address != null)
                _InfoTile(
                  icon: Icons.location_on_outlined,
                  label: gym.address!,
                ),

              if (gym.instagramUrl != null)
                _InfoTile(
                  icon: Icons.camera_alt_outlined,
                  label: _extractInstagramHandle(gym.instagramUrl!),
                  subText: gym.instagramUrl!,
                  trailing: const Icon(
                    Icons.open_in_new,
                    size: 16,
                    color: Color(0xFF9E9E9E),
                  ),
                  onTap: () async {
                    final uri = Uri.parse(gym.instagramUrl!);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),

              // 지도 영역
              if (hasLocation) ...[
                const SizedBox(height: 8),
                const Divider(height: 1, indent: 20, endIndent: 20),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: const Text(
                    '위치',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF424242),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 200,
                      child: GoogleMap(
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
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _extractInstagramHandle(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final path = uri.path.replaceAll('/', '');
    return '@$path';
  }
}

/// 정보 타일 (구글맵 스타일 리스트 아이템)
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subText;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _InfoTile({
    required this.icon,
    required this.label,
    this.subText,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: const Color(0xFF757575)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: Color(0xFF424242),
                    ),
                  ),
                  if (subText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subText!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9E9E9E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
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
        height: 24,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (count) {
        return Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: count > 0
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFBDBDBD),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              count > 0
                  ? '지금 $count명이 등반 중'
                  : '현재 등반 중인 사람이 없어요',
              style: TextStyle(
                fontSize: 14,
                color: count > 0
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFF9E9E9E),
              ),
            ),
          ],
        );
      },
    );
  }
}
