class GradeDistribution {
  final String grade;
  final int count;
  final double completionRate;

  const GradeDistribution({
    required this.grade,
    required this.count,
    required this.completionRate,
  });

  factory GradeDistribution.fromMap(Map<String, dynamic> map) =>
      GradeDistribution(
        grade: map['grade'] as String,
        count: (map['count'] as num).toInt(),
        completionRate: (map['completion_rate'] as num).toDouble(),
      );
}

class GymStats {
  final int totalUsers;
  final int totalClimbs;
  final double avgCompletionRate;
  final List<GradeDistribution> gradeDistribution;
  final List<String> popularGrades;

  const GymStats({
    required this.totalUsers,
    required this.totalClimbs,
    required this.avgCompletionRate,
    required this.gradeDistribution,
    required this.popularGrades,
  });

  factory GymStats.fromMap(Map<String, dynamic> map) => GymStats(
        totalUsers: (map['total_users'] as num).toInt(),
        totalClimbs: (map['total_climbs'] as num).toInt(),
        avgCompletionRate: (map['avg_completion_rate'] as num).toDouble(),
        gradeDistribution: (map['grade_distribution'] as List)
            .map((e) => GradeDistribution.fromMap(e as Map<String, dynamic>))
            .toList(),
        popularGrades: (map['popular_grades'] as List)
            .map((e) => e as String)
            .toList(),
      );
}

class MyGymRanking {
  final int myClimbs;
  final double myCompletionRate;
  final int climbsPercentile;
  final int completionPercentile;
  final String highestGrade;
  final int gradePercentile;

  const MyGymRanking({
    required this.myClimbs,
    required this.myCompletionRate,
    required this.climbsPercentile,
    required this.completionPercentile,
    required this.highestGrade,
    required this.gradePercentile,
  });

  factory MyGymRanking.fromMap(Map<String, dynamic> map) => MyGymRanking(
        myClimbs: (map['my_climbs'] as num).toInt(),
        myCompletionRate: (map['my_completion_rate'] as num).toDouble(),
        climbsPercentile: (map['climbs_percentile'] as num).toInt(),
        completionPercentile: (map['completion_percentile'] as num).toInt(),
        highestGrade: map['highest_grade'] as String,
        gradePercentile: (map['grade_percentile'] as num).toInt(),
      );
}
