import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _defaultFreeStorageLimitBytes = 500 * 1024 * 1024; // 500 MB fallback

/// 서버에서 가져온 Free 티어 스토리지 제한 (바이트)
final freeStorageLimitBytesProvider = FutureProvider<int>((ref) async {
  try {
    final response = await Supabase.instance.client
        .from('app_config')
        .select('value')
        .eq('key', 'free_storage_limit_bytes')
        .single();

    final value = response['value'];
    debugPrint('[AppConfig] raw value=$value (${value.runtimeType})');
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? _defaultFreeStorageLimitBytes;
  } catch (e) {
    debugPrint('[AppConfig] free_storage_limit_bytes 조회 실패, 기본값 사용: $e');
    return _defaultFreeStorageLimitBytes;
  }
});
