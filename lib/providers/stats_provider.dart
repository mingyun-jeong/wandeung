import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';
import '../models/climbing_record.dart';

enum StatsPeriod {
  week('7일', 7),
  month('30일', 30),
  quarter('90일', 90);

  final String label;
  final int days;
  const StatsPeriod(this.label, this.days);
}

final statsPeriodProvider =
    StateProvider<StatsPeriod>((ref) => StatsPeriod.month);

class GymStat {
  final String name;
  final int total;
  final int completed;
  final int prevTotal;
  final int prevCompleted;

  const GymStat({
    required this.name,
    required this.total,
    required this.completed,
    required this.prevTotal,
    required this.prevCompleted,
  });

  double get completionRate =>
      total > 0 ? completed / total * 100 : 0;
}

class ColorTimePoint {
  final String label;
  final Map<String, int> colorCounts;
  const ColorTimePoint({required this.label, required this.colorCounts});
}

class PeriodStatsData {
  final List<ClimbingRecord> current;
  final List<ClimbingRecord> previous;

  const PeriodStatsData({required this.current, required this.previous});

  int get totalClimbs => current.length;
  int get prevTotalClimbs => previous.length;

  int get totalCompleted =>
      current.where((r) => r.status == 'completed').length;
  int get prevTotalCompleted =>
      previous.where((r) => r.status == 'completed').length;

  int get totalInProgress =>
      current.where((r) => r.status == 'in_progress').length;

  double get completionRate =>
      totalClimbs > 0 ? totalCompleted / totalClimbs * 100 : 0;
  double get prevCompletionRate =>
      prevTotalClimbs > 0 ? prevTotalCompleted / prevTotalClimbs * 100 : 0;

  bool get hasPrevious => previous.isNotEmpty;

  /// 기간별 난이도 색상 시계열 데이터
  List<ColorTimePoint> getColorTimeSeries(StatsPeriod period) {
    if (current.isEmpty) return [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final colors = _usedColors;
    final result = <ColorTimePoint>[];

    switch (period) {
      case StatsPeriod.week:
        for (int i = 0; i < 7; i++) {
          final date = today.subtract(Duration(days: 6 - i));
          final nextDate = date.add(const Duration(days: 1));
          result.add(_buildColorPoint(date, nextDate, '${date.month}/${date.day}', colors));
        }
      case StatsPeriod.month:
        for (int i = 0; i < 4; i++) {
          final start = today.subtract(Duration(days: 27 - i * 7));
          final end = today.subtract(Duration(days: 20 - i * 7));
          result.add(_buildColorPoint(start, end, '${start.month}/${start.day}', colors));
        }
      case StatsPeriod.quarter:
        for (int i = 2; i >= 0; i--) {
          final month = DateTime(today.year, today.month - i, 1);
          final nextMonth = DateTime(month.year, month.month + 1, 1);
          result.add(_buildColorPoint(month, nextMonth, '${month.month}월', colors));
        }
    }

    return result;
  }

  /// 실제 사용된 색상만 추출
  List<String> get _usedColors {
    final used = current.map((r) => r.difficultyColor).toSet();
    const order = ['brown', 'gray', 'purple', 'red', 'blue', 'green', 'yellow', 'orange', 'white'];
    return order.where((c) => used.contains(c)).toList();
  }

  ColorTimePoint _buildColorPoint(
      DateTime start, DateTime end, String label, List<String> colors) {
    final inRange = current.where((r) {
      final d = DateTime(r.recordedAt.year, r.recordedAt.month, r.recordedAt.day);
      return !d.isBefore(start) && d.isBefore(end);
    });
    return ColorTimePoint(
      label: label,
      colorCounts: {
        for (final c in colors)
          c: inRange.where((r) => r.difficultyColor == c).length
      },
    );
  }

  List<GymStat> get gymBreakdown {
    final currentMap = <String, List<int>>{};
    final prevMap = <String, List<int>>{};

    for (final r in current) {
      final gym = r.gymName ?? '미지정';
      currentMap.putIfAbsent(gym, () => [0, 0]);
      currentMap[gym]![0]++;
      if (r.status == 'completed') currentMap[gym]![1]++;
    }

    for (final r in previous) {
      final gym = r.gymName ?? '미지정';
      prevMap.putIfAbsent(gym, () => [0, 0]);
      prevMap[gym]![0]++;
      if (r.status == 'completed') prevMap[gym]![1]++;
    }

    final allGyms = {...currentMap.keys, ...prevMap.keys};
    final result = allGyms.map((gym) => GymStat(
      name: gym,
      total: currentMap[gym]?[0] ?? 0,
      completed: currentMap[gym]?[1] ?? 0,
      prevTotal: prevMap[gym]?[0] ?? 0,
      prevCompleted: prevMap[gym]?[1] ?? 0,
    )).toList();

    result.sort((a, b) => b.total.compareTo(a.total));
    return result;
  }
}

final periodStatsProvider = FutureProvider<PeriodStatsData>((ref) async {
  final period = ref.watch(statsPeriodProvider);
  final userId = SupabaseConfig.client.auth.currentUser!.id;

  final response = await SupabaseConfig.client
      .from('climbing_records')
      .select('*, climbing_gyms(name)')
      .eq('user_id', userId)
      .isFilter('parent_record_id', null)
      .order('recorded_at', ascending: false);

  final allRecords = (response as List)
      .map((e) => ClimbingRecord.fromMap(e))
      .toList();

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final startDate = today.subtract(Duration(days: period.days));
  final prevStartDate = startDate.subtract(Duration(days: period.days));

  final current = allRecords.where((r) {
    final d = DateTime(r.recordedAt.year, r.recordedAt.month, r.recordedAt.day);
    return !d.isBefore(startDate);
  }).toList();

  final previous = allRecords.where((r) {
    final d = DateTime(r.recordedAt.year, r.recordedAt.month, r.recordedAt.day);
    return !d.isBefore(prevStartDate) && d.isBefore(startDate);
  }).toList();

  return PeriodStatsData(current: current, previous: previous);
});
