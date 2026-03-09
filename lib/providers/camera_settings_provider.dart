import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/climbing_gym.dart';
import '../utils/constants.dart';

class CameraSettings {
  final ClimbingGrade? grade;
  final DifficultyColor? color;
  final ClimbingGym? selectedGym;

  const CameraSettings({
    this.grade,
    this.color,
    this.selectedGym,
  });

  CameraSettings copyWith({
    ClimbingGrade? grade,
    DifficultyColor? color,
    ClimbingGym? selectedGym,
    bool clearGym = false,
  }) {
    return CameraSettings(
      grade: grade ?? this.grade,
      color: color ?? this.color,
      selectedGym: clearGym ? null : (selectedGym ?? this.selectedGym),
    );
  }
}

class CameraSettingsNotifier extends StateNotifier<CameraSettings> {
  CameraSettingsNotifier()
      : super(const CameraSettings(
            grade: ClimbingGrade.v1, color: DifficultyColor.yellow));

  void setGrade(ClimbingGrade grade) => state = state.copyWith(grade: grade);
  void setColor(DifficultyColor color) => state = state.copyWith(color: color);

  void setGym(ClimbingGym gym) =>
      state = state.copyWith(selectedGym: gym);

  void clearGym() =>
      state = state.copyWith(clearGym: true);

  void reset() => state = const CameraSettings();
}

final cameraSettingsProvider =
    StateNotifierProvider<CameraSettingsNotifier, CameraSettings>(
  (ref) => CameraSettingsNotifier(),
);

/// 하단 네비게이션 탭 인덱스 (0=촬영, 1=캘린더)
final bottomNavIndexProvider = StateProvider<int>((ref) => 0);
