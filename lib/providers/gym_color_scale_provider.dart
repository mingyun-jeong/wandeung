import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';
import '../models/gym_color_scale.dart';

/// 전체 브랜드 색상표 캐시 (앱 시작 시 한 번 로드)
final allColorScalesProvider =
    FutureProvider<List<GymColorScale>>((ref) async {
  final response = await SupabaseConfig.client
      .from('gym_color_scales')
      .select()
      .order('brand_name');

  return (response as List)
      .map((e) => GymColorScale.fromMap(e as Map<String, dynamic>))
      .toList();
});

/// 암장 이름에서 브랜드 자동매칭
/// 예: "더클라이밍 강남점" → "더클라이밍"
final gymBrandProvider =
    Provider.family<String?, String>((ref, gymName) {
  final scales = ref.watch(allColorScalesProvider).valueOrNull;
  if (scales == null) return null;
  return matchBrand(gymName, scales);
});

/// 암장 이름으로 색상표 조회
final gymColorScaleProvider =
    Provider.family<GymColorScale?, String>((ref, gymName) {
  final scales = ref.watch(allColorScalesProvider).valueOrNull;
  if (scales == null) return null;
  final brand = matchBrand(gymName, scales);
  if (brand == null) return null;
  return scales.where((s) => s.brandName == brand).firstOrNull;
});

/// 암장 이름에서 브랜드명 매칭
/// Google Places 이름에 브랜드명이 포함되어 있는지 확인
String? matchBrand(String gymName, List<GymColorScale> scales) {
  // 정규화: 공백 제거 후 비교
  final normalized = gymName.replaceAll(' ', '');
  for (final scale in scales) {
    final brandNormalized = scale.brandName.replaceAll(' ', '');
    if (normalized.contains(brandNormalized)) {
      return scale.brandName;
    }
  }
  // "클라이밍파크" → "클라이밍 파크" 등 띄어쓰기 변형 대응
  for (final scale in scales) {
    if (gymName.contains(scale.brandName)) {
      return scale.brandName;
    }
  }
  return null;
}
