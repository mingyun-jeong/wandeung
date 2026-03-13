/// 클라이밍 난이도 등급 (낮은→높은 순서)
enum ClimbingGrade {
  vBbbbb,
  vBbb,
  vBb,
  vB,
  v0,
  v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15, v16;

  /// 정렬용 숫자 인덱스 (vBbbbb=−4, vBbb=−3, vBb=−2, vB=−1, v0=0, v1=1, …)
  int get sortIndex => index - 4;
}

extension ClimbingGradeExt on ClimbingGrade {
  String get label => switch (this) {
        ClimbingGrade.vBbbbb => 'Vbbbbb',
        ClimbingGrade.vBbb => 'Vbbb',
        ClimbingGrade.vBb => 'Vbb',
        ClimbingGrade.vB => 'Vb',
        ClimbingGrade.v0 => 'V0',
        _ => name.toUpperCase(),
      };

  String get korean => switch (this) {
        ClimbingGrade.vBbbbb => '펭수',
        ClimbingGrade.vBbb => '입문',
        ClimbingGrade.vBb => '입문',
        ClimbingGrade.vB => '초보',
        ClimbingGrade.v0 => '초보',
        _ => label,
      };
}

/// 난이도 색상 (Hard → Easy 기본 순서)
enum DifficultyColor {
  black('검정', 0xFF212121),
  brown('갈색', 0xFF6D4C41),
  gray('회색', 0xFF9E9E9E),
  purple('보라', 0xFF9C27B0),
  navy('남색', 0xFF1A237E),
  red('빨강', 0xFFF44336),
  blue('파랑', 0xFF2196F3),
  skyBlue('하늘', 0xFF03A9F4),
  green('초록', 0xFF4CAF50),
  yellow('노랑', 0xFFFFEB3B),
  orange('주황', 0xFFFF9800),
  pink('분홍', 0xFFE91E63),
  white('흰색', 0xFFFFFFFF),
  rainbow('무지개', 0xFF000000),
  star('별', 0xFFFFD700);

  final String korean;
  final int colorValue;
  const DifficultyColor(this.korean, this.colorValue);

  /// 체크 아이콘에 밝은색 사용해야 하는지
  bool get needsDarkIcon =>
      this == white || this == yellow || this == star || this == skyBlue;
}

/// 완등 상태
enum ClimbingStatus {
  completed('완등'),
  inProgress('도전중');

  final String label;
  const ClimbingStatus(this.label);
}
