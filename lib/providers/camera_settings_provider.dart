import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// 하단 네비게이션 탭 인덱스 (0=촬영, 1=캘린더)
final bottomNavIndexProvider = StateProvider<int>((ref) => 0);
