import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_subscription.dart';
import 'app_config_provider.dart';

/// 사용자 구독 정보 (DB에서 조회)
final userSubscriptionProvider = FutureProvider<UserSubscription?>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return null;

  try {
    final response = await Supabase.instance.client
        .from('user_subscriptions')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;
    return UserSubscription.fromMap(response);
  } catch (_) {
    // user_subscriptions 테이블 마이그레이션 미적용 시 null 반환
    return null;
  }
});

/// 현재 사용자의 구독 티어
final subscriptionTierProvider = Provider<SubscriptionTier>((ref) {
  final subscription = ref.watch(userSubscriptionProvider);
  return subscription.when(
    data: (sub) => (sub != null && sub.isPro)
        ? SubscriptionTier.pro
        : SubscriptionTier.free,
    loading: () => SubscriptionTier.free,
    error: (_, __) => SubscriptionTier.free,
  );
});

/// 저장 모드 (cloud / local)
const _storageModeKey = 'storage_mode';

final storageModeProvider =
    StateNotifierProvider<StorageModeNotifier, StorageMode>((ref) {
  return StorageModeNotifier();
});

class StorageModeNotifier extends StateNotifier<StorageMode> {
  bool _loaded = false;

  StorageModeNotifier() : super(StorageMode.cloud) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_storageModeKey);
    if (value == 'local') {
      state = StorageMode.local;
    }
    _loaded = true;
  }

  Future<StorageMode> getValue() async {
    if (_loaded) return state;
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_storageModeKey);
    return value == 'local' ? StorageMode.local : StorageMode.cloud;
  }

  Future<void> setMode(StorageMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageModeKey, mode.name);
  }
}

/// 클라우드 사용량 (바이트) — DB에서 file_size_bytes 합산
final cloudUsageProvider = FutureProvider.autoDispose<int>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return 0;

  try {
    final response = await Supabase.instance.client
        .from('climbing_records')
        .select('file_size_bytes')
        .eq('user_id', userId)
        .eq('local_only', false);

    int total = 0;
    for (final row in response as List) {
      final size = row['file_size_bytes'];
      if (size != null) total += (size as num).toInt();
    }
    return total;
  } catch (_) {
    // file_size_bytes 컬럼 마이그레이션 미적용 시 0 반환
    return 0;
  }
});

/// 남은 용량 (바이트)
final remainingStorageProvider = Provider.autoDispose<int>((ref) {
  final tier = ref.watch(subscriptionTierProvider);
  final limitAsync = ref.watch(freeStorageLimitBytesProvider);
  final limit = limitAsync.valueOrNull ?? 500 * 1024 * 1024;

  if (tier == SubscriptionTier.pro) return limit; // 무제한

  final usage = ref.watch(cloudUsageProvider);
  return usage.when(
    data: (used) => limit - used,
    loading: () => limit,
    error: (_, __) => limit,
  );
});
