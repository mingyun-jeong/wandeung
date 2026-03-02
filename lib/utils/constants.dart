/// 클라이밍 난이도 등급
enum ClimbingGrade { v1, v2, v3, v4, v5 }

extension ClimbingGradeExt on ClimbingGrade {
  String get label => name.toUpperCase();
}

/// 난이도 색상 (Hard → Easy 순서)
enum DifficultyColor {
  brown('갈색', 0xFF6D4C41),
  gray('회색', 0xFF9E9E9E),
  purple('보라', 0xFF9C27B0),
  red('빨강', 0xFFF44336),
  blue('파랑', 0xFF2196F3),
  green('초록', 0xFF4CAF50),
  yellow('노랑', 0xFFFFEB3B),
  orange('주황', 0xFFFF9800),
  white('흰색', 0xFFFFFFFF);

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
