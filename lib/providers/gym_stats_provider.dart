import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';
import '../models/gym_stats.dart';
import 'auth_provider.dart';

/// 현재 선택된 클라이밍장 ID (통계 탭용)
final selectedGymForStatsProvider = StateProvider<String?>((ref) => null);

Map<String, dynamic>? _extractMap(dynamic response) {
  if (response == null) return null;
  if (response is Map<String, dynamic>) return response;
  if (response is List && response.isNotEmpty) {
    return response.first as Map<String, dynamic>;
  }
  return null;
}

/// 클라이밍장 전체 통계 (최근 30일)
final gymStatsProvider =
    FutureProvider.family<GymStats?, String>((ref, gymId) async {
  try {
    final response = await SupabaseConfig.client.rpc(
      'get_gym_stats',
      params: {'p_gym_id': gymId},
    );
    final data = _extractMap(response);
    if (data == null) return null;
    return GymStats.fromMap(data);
  } catch (e) {
    debugPrint('[gymStatsProvider] error: $e');
    rethrow;
  }
});

/// 내 상대 순위 (최근 30일)
final myGymRankingProvider =
    FutureProvider.family<MyGymRanking?, String>((ref, gymId) async {
  final userId = ref.watch(authProvider).valueOrNull?.id;
  if (userId == null) return null;

  try {
    final response = await SupabaseConfig.client.rpc(
      'get_my_gym_ranking',
      params: {'p_gym_id': gymId, 'p_user_id': userId},
    );
    final data = _extractMap(response);
    if (data == null) return null;
    return MyGymRanking.fromMap(data);
  } catch (e) {
    debugPrint('[myGymRankingProvider] error: $e');
    rethrow;
  }
});
