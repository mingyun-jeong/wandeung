import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';

/// 암장 이름으로 instagram_url 조회
final gymInstagramProvider =
    FutureProvider.family<String?, String>((ref, gymName) async {
  try {
    final response = await SupabaseConfig.client
        .from('climbing_gyms')
        .select('instagram_url')
        .eq('name', gymName)
        .maybeSingle();
    return response?['instagram_url'] as String?;
  } catch (e) {
    debugPrint('[gymInstagramProvider] error: $e');
    return null;
  }
});
