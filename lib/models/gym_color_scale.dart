import '../utils/constants.dart';

/// 브랜드 색상표의 개별 레벨 (Hard→Easy 순서)
class ColorLevel {
  final int level;
  final DifficultyColor color;
  final ClimbingGrade vMin;
  final ClimbingGrade vMax;

  const ColorLevel({
    required this.level,
    required this.color,
    required this.vMin,
    required this.vMax,
  });

  factory ColorLevel.fromMap(Map<String, dynamic> map) => ColorLevel(
        level: map['level'] as int,
        color: DifficultyColor.values.firstWhere(
          (c) => c.name == map['color'],
          orElse: () => DifficultyColor.white,
        ),
        vMin: ClimbingGrade.values.firstWhere(
          (g) => g.name == map['v_min'],
          orElse: () => ClimbingGrade.v1,
        ),
        vMax: ClimbingGrade.values.firstWhere(
          (g) => g.name == map['v_max'],
          orElse: () => ClimbingGrade.v1,
        ),
      );

  /// V-scale 범위 표시 (예: "V4~V6")
  String get vRangeLabel =>
      vMin == vMax ? vMin.label : '${vMin.label}~${vMax.label}';
}

/// 암장 브랜드별 난이도 색상표
class GymColorScale {
  final String? id;
  final String brandName;
  final List<ColorLevel> levels;

  const GymColorScale({
    this.id,
    required this.brandName,
    required this.levels,
  });

  factory GymColorScale.fromMap(Map<String, dynamic> map) {
    final levelsJson = map['levels'] as List;
    return GymColorScale(
      id: map['id'],
      brandName: map['brand_name'] as String,
      levels: levelsJson
          .map((e) => ColorLevel.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 색상으로 해당 레벨 찾기
  ColorLevel? levelForColor(DifficultyColor color) {
    for (final l in levels) {
      if (l.color == color) return l;
    }
    return null;
  }
}
