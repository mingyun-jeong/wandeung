import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/climbing_gym.dart';
import '../utils/constants.dart';
import 'user_grade_provider.dart';

class CameraSettings {
  final ClimbingGrade? grade;
  final DifficultyColor? color;
  final ClimbingGym? selectedGym;
  final bool persistTags;
  final List<String> tags;

  const CameraSettings({
    this.grade,
    this.color,
    this.selectedGym,
    this.persistTags = false,
    this.tags = const [],
  });

  CameraSettings copyWith({
    ClimbingGrade? grade,
    DifficultyColor? color,
    ClimbingGym? selectedGym,
    bool clearGym = false,
    bool? persistTags,
    List<String>? tags,
  }) {
    return CameraSettings(
      grade: grade ?? this.grade,
      color: color ?? this.color,
      selectedGym: clearGym ? null : (selectedGym ?? this.selectedGym),
      persistTags: persistTags ?? this.persistTags,
      tags: tags ?? this.tags,
    );
  }
}

class CameraSettingsNotifier extends StateNotifier<CameraSettings> {
  CameraSettingsNotifier(ClimbingGrade? userGrade)
      : super(CameraSettings(
            grade: userGrade ?? ClimbingGrade.v1,
            color: userGrade?.defaultColor ?? DifficultyColor.yellow));

  void setGrade(ClimbingGrade grade) => state = state.copyWith(grade: grade);
  void setColor(DifficultyColor color) => state = state.copyWith(color: color);

  void setGym(ClimbingGym gym) =>
      state = state.copyWith(selectedGym: gym);

  void clearGym() =>
      state = state.copyWith(clearGym: true);

  void setPersistTags(bool value) =>
      state = state.copyWith(persistTags: value);

  void setTags(List<String> tags) =>
      state = state.copyWith(tags: tags);

  void reset() => state = const CameraSettings();
}

final cameraSettingsProvider =
    StateNotifierProvider<CameraSettingsNotifier, CameraSettings>(
  (ref) {
    final userGrade = ref.read(userGradeProvider);
    return CameraSettingsNotifier(userGrade);
  },
);

/// 하단 네비게이션 탭 인덱스 (0=홈, 1=기록, 2=촬영, 3=세팅일정, 4=통계)
final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

/// 진입 모드 설정 — 앱 시작 시 바로 촬영 모드로 진입할지 여부
const _entryModeKey = 'entry_mode_camera';

final entryModeCameraProvider =
    StateNotifierProvider<EntryModeCameraNotifier, bool>((ref) {
  return EntryModeCameraNotifier();
});

class EntryModeCameraNotifier extends StateNotifier<bool> {
  EntryModeCameraNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_entryModeKey) ?? true;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_entryModeKey, state);
  }
}
