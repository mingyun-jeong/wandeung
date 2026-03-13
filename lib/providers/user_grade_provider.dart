import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

const _prefKey = 'user_preferred_grade';

/// 사용자가 프로필에서 설정한 선호 등급.
/// SharedPreferences에 저장되어 앱 재시작 후에도 유지됨.
class UserGradeNotifier extends StateNotifier<ClimbingGrade?> {
  UserGradeNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_prefKey);
    if (name != null) {
      state = ClimbingGrade.values
          .where((g) => g.name == name)
          .firstOrNull;
    }
  }

  Future<void> setGrade(ClimbingGrade? grade) async {
    state = grade;
    final prefs = await SharedPreferences.getInstance();
    if (grade != null) {
      await prefs.setString(_prefKey, grade.name);
    } else {
      await prefs.remove(_prefKey);
    }
  }
}

final userGradeProvider =
    StateNotifierProvider<UserGradeNotifier, ClimbingGrade?>(
  (ref) => UserGradeNotifier(),
);
