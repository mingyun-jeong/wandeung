/// 클라이밍 난이도 등급
enum ClimbingGrade { v1, v2, v3, v4, v5 }

extension ClimbingGradeExt on ClimbingGrade {
  String get label => name.toUpperCase();
}

/// 난이도 색상
enum DifficultyColor {
  white('하얀', 0xFFFFFFFF),
  yellow('노랑', 0xFFFFEB3B),
  green('녹색', 0xFF4CAF50),
  blue('파랑', 0xFF2196F3),
  red('빨강', 0xFFF44336),
  purple('보라', 0xFF9C27B0),
  orange('주황', 0xFFFF9800),
  pink('핑크', 0xFFE91E63),
  black('검정', 0xFF212121);

  final String korean;
  final int colorValue;
  const DifficultyColor(this.korean, this.colorValue);
}

/// 완등 상태
enum ClimbingStatus {
  completed('완등'),
  inProgress('도전중');

  final String label;
  const ClimbingStatus(this.label);
}
