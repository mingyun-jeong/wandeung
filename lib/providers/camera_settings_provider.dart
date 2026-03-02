import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/climbing_gym.dart';
import '../utils/constants.dart';

class CameraSettings {
  final ClimbingGrade? grade;
  final DifficultyColor? color;
  final ClimbingGym? selectedGym;
  final String? manualGymName;

  const CameraSettings({
    this.grade,
    this.color,
    this.selectedGym,
    this.manualGymName,
  });

  CameraSettings copyWith({
    ClimbingGrade? grade,
    DifficultyColor? color,
    ClimbingGym? selectedGym,
    String? manualGymName,
    bool clearGym = false,
    bool clearManualGymName = false,
  }) {
    return CameraSettings(
      grade: grade ?? this.grade,
      color: color ?? this.color,
      selectedGym: clearGym ? null : (selectedGym ?? this.selectedGym),
      manualGymName:
          clearManualGymName ? null : (manualGymName ?? this.manualGymName),
    );
  }
}

class CameraSettingsNotifier extends StateNotifier<CameraSettings> {
  CameraSettingsNotifier()
      : super(const CameraSettings(grade: ClimbingGrade.v1));

  void setGrade(ClimbingGrade grade) => state = state.copyWith(grade: grade);
  void setColor(DifficultyColor color) => state = state.copyWith(color: color);

  void setGym(ClimbingGym gym) =>
      state = state.copyWith(selectedGym: gym, clearManualGymName: true);

  void setManualGymName(String name) =>
      state = state.copyWith(manualGymName: name, clearGym: true);

  void reset() => state = const CameraSettings();
}

final cameraSettingsProvider =
    StateNotifierProvider<CameraSettingsNotifier, CameraSettings>(
  (ref) => CameraSettingsNotifier(),
);

/// 하단 네비게이션 탭 인덱스
final bottomNavIndexProvider = StateProvider<int>((ref) => 0);
