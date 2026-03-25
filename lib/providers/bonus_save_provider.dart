import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _bonusSavesKey = 'bonus_saves_remaining';
const bonusSavesPerAd = 3;

/// 광고 시청으로 획득한 남은 보너스 저장 횟수
final bonusSaveProvider =
    StateNotifierProvider<BonusSaveNotifier, int>((ref) {
  return BonusSaveNotifier();
});

class BonusSaveNotifier extends StateNotifier<int> {
  BonusSaveNotifier() : super(0) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt(_bonusSavesKey) ?? 0;
  }

  /// 광고 시청 완료 → 보너스 3건 추가
  Future<void> grantBonus() async {
    state += bonusSavesPerAd;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_bonusSavesKey, state);
  }

  /// 저장 시 1건 차감
  Future<void> consume() async {
    if (state <= 0) return;
    state -= 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_bonusSavesKey, state);
  }

  /// 보너스 사용 가능 여부
  bool get hasBonus => state > 0;
}
