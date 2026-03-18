import 'package:flutter_test/flutter_test.dart';
import 'package:cling/models/gym_stats.dart';

void main() {
  group('GymStats.fromMap', () {
    test('parses valid response', () {
      final map = {
        'total_users': 42,
        'total_climbs': 150,
        'avg_completion_rate': 65.3,
        'grade_distribution': [
          {'grade': 'v3', 'count': 30, 'completion_rate': 70.0},
          {'grade': 'v4', 'count': 25, 'completion_rate': 55.5},
        ],
        'popular_grades': ['v3', 'v4', 'v2'],
      };

      final stats = GymStats.fromMap(map);

      expect(stats.totalUsers, 42);
      expect(stats.totalClimbs, 150);
      expect(stats.avgCompletionRate, 65.3);
      expect(stats.gradeDistribution.length, 2);
      expect(stats.gradeDistribution[0].grade, 'v3');
      expect(stats.gradeDistribution[0].count, 30);
      expect(stats.popularGrades, ['v3', 'v4', 'v2']);
    });
  });

  group('MyGymRanking.fromMap', () {
    test('parses valid response', () {
      final map = {
        'my_climbs': 15,
        'my_completion_rate': 73.3,
        'climbs_percentile': 25,
        'completion_percentile': 18,
        'highest_grade': 'v5',
        'grade_percentile': 30,
      };

      final ranking = MyGymRanking.fromMap(map);

      expect(ranking.myClimbs, 15);
      expect(ranking.myCompletionRate, 73.3);
      expect(ranking.climbsPercentile, 25);
      expect(ranking.completionPercentile, 18);
      expect(ranking.highestGrade, 'v5');
      expect(ranking.gradePercentile, 30);
    });
  });
}
