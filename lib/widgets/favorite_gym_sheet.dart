import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/climbing_gym.dart';
import '../providers/favorite_gym_provider.dart';
import '../providers/gym_provider.dart';
import '../providers/gym_color_scale_provider.dart';
import '../providers/record_provider.dart';

class FavoriteGymSheet extends ConsumerStatefulWidget {
  const FavoriteGymSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const FavoriteGymSheet(),
    );
  }

  @override
  ConsumerState<FavoriteGymSheet> createState() => _FavoriteGymSheetState();
}

class _FavoriteGymSheetState extends ConsumerState<FavoriteGymSheet> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    // 시트 열릴 때 검색 상태 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(searchQueryProvider.notifier).state = '';
    });
    _searchController.addListener(() {
      final query = _searchController.text.trim();
      ref.read(searchQueryProvider.notifier).state = query;
      setState(() => _isSearching = query.isNotEmpty);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    // 시트 닫힐 때 검색 상태 초기화
    Future.microtask(() {
      ref.read(searchQueryProvider.notifier).state = '';
    });
    super.dispose();
  }

  Future<void> _addGym(ClimbingGym gym) async {
    // gym이 DB에 없을 수 있으므로 RecordService.findOrCreateGym 사용
    final scales = await ref.read(allColorScalesProvider.future);
    final gymId = await RecordService.findOrCreateGym(gym, scales: scales);
    await FavoriteGymService.addFavorite(gymId);
    ref.invalidate(favoriteGymsProvider);
    ref.invalidate(recommendedGymsProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 드래그 핸들
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 헤더
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('암장 추가',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, letterSpacing: -0.3)),
            ),
            const SizedBox(height: 12),
            // 검색 입력
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '암장 이름으로 검색',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _isSearching
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            // 검색 결과 또는 추천 목록
            Expanded(
              child: _isSearching ? _buildSearchResults() : _buildRecommendations(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    final gyms = ref.watch(gymsProvider);
    return gyms.when(
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('검색 결과가 없습니다.', style: TextStyle(color: Colors.grey)));
        }
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (_, i) => _GymTile(gym: list[i], onTap: () => _addGym(list[i])),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('검색 실패', style: TextStyle(color: Colors.red.shade700))),
    );
  }

  Widget _buildRecommendations() {
    final recommended = ref.watch(recommendedGymsProvider);
    return recommended.when(
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('기록된 암장이 없습니다.\n검색으로 암장을 추가해보세요.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('기록에서 추천',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4))),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) => _GymTile(gym: list[i], onTap: () => _addGym(list[i])),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const SizedBox.shrink(),
    );
  }
}

class _GymTile extends StatelessWidget {
  final ClimbingGym gym;
  final VoidCallback onTap;
  const _GymTile({required this.gym, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(gym.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  if (gym.address != null)
                    Text(gym.address!, style: const TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.add_rounded, size: 20,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }
}
