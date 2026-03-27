import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';
import '../models/climbing_gym.dart';
import 'auth_provider.dart';

/// 현재 유저의 즐겨찾기 암장 목록
final favoriteGymsProvider = FutureProvider<List<ClimbingGym>>((ref) async {
  final userId = ref.watch(authProvider).valueOrNull?.id;
  if (userId == null) return [];

  final response = await SupabaseConfig.client
      .from('user_favorite_gyms')
      .select('gym_id, climbing_gyms(id, name, address, latitude, longitude, google_place_id, brand_name, instagram_url)')
      .eq('user_id', userId)
      .order('created_at', ascending: false);

  return (response as List)
      .map((e) => ClimbingGym.fromMap(e['climbing_gyms'] as Map<String, dynamic>))
      .toList();
});

/// 기록 기반 추천 암장 (방문 횟수 상위 5개, 이미 즐겨찾기된 암장 제외)
final recommendedGymsProvider = FutureProvider<List<ClimbingGym>>((ref) async {
  final userId = ref.watch(authProvider).valueOrNull?.id;
  if (userId == null) return [];

  // 즐겨찾기된 gym_id 목록
  final favorites = await ref.watch(favoriteGymsProvider.future);
  final favoriteIds = favorites.map((g) => g.id).whereType<String>().toSet();

  // 기록에서 gym_id별 방문 횟수 집계
  final response = await SupabaseConfig.client
      .from('climbing_records')
      .select('gym_id, climbing_gyms(id, name, address, latitude, longitude, google_place_id, brand_name, instagram_url)')
      .eq('user_id', userId)
      .isFilter('parent_record_id', null)
      .not('gym_id', 'is', null);

  final countMap = <String, int>{};
  final gymMap = <String, ClimbingGym>{};
  for (final row in response as List) {
    final gymData = row['climbing_gyms'] as Map<String, dynamic>?;
    if (gymData == null) continue;
    final gymId = gymData['id'] as String;
    if (favoriteIds.contains(gymId)) continue;
    countMap[gymId] = (countMap[gymId] ?? 0) + 1;
    gymMap.putIfAbsent(gymId, () => ClimbingGym.fromMap(gymData));
  }

  final sorted = countMap.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return sorted.take(5).map((e) => gymMap[e.key]!).toList();
});

/// 즐겨찾기 추가/삭제 서비스
class FavoriteGymService {
  static final _supabase = SupabaseConfig.client;

  static Future<void> addFavorite(String gymId) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('user_favorite_gyms').upsert(
      {'user_id': userId, 'gym_id': gymId},
      onConflict: 'user_id, gym_id',
    );
  }

  static Future<void> removeFavorite(String gymId) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase
        .from('user_favorite_gyms')
        .delete()
        .eq('user_id', userId)
        .eq('gym_id', gymId);
  }
}
