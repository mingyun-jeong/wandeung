import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/stats_provider.dart';
import '../widgets/gym_stats_tab.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/reclim_app_bar.dart';
import '../app.dart';

class StatsTabScreen extends ConsumerStatefulWidget {
  const StatsTabScreen({super.key});

  @override
  ConsumerState<StatsTabScreen> createState() => _StatsTabScreenState();
}

class _StatsTabScreenState extends ConsumerState<StatsTabScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ReclimAppBar(
        extraActions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '새로고침',
            onPressed: () => ref.invalidate(periodStatsProvider),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: ReclimColors.accent,
          unselectedLabelColor: ReclimColors.textTertiary,
          indicatorColor: ReclimColors.accent,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          tabs: const [
            Tab(text: '내 통계'),
            Tab(text: '암장 통계'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMyStatsTab(),
                const GymStatsTab(),
              ],
            ),
          ),
          const SafeArea(
            top: false,
            child: BannerAdWidget(),
          ),
        ],
      ),
    );
  }

  Widget _buildMyStatsTab() {
    final period = ref.watch(statsPeriodProvider);
    final statsAsync = ref.watch(periodStatsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(periodStatsProvider),
      child: CustomScrollView(
        slivers: [
          // 기간 필터 — SegmentedButton 스타일
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _PeriodSelector(
                current: period,
                onChanged: (p) =>
                    ref.read(statsPeriodProvider.notifier).state = p,
              ),
            ),
          ),

          statsAsync.when(
            data: (stats) {
              if (stats.totalClimbs == 0 && stats.prevTotalClimbs == 0) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: ReclimColors.border.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.bar_chart_rounded,
                            size: 32,
                            color: ReclimColors.textTertiary
                                .withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '아직 통계가 없어요',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: ReclimColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '등반 기록을 추가해보세요!',
                          style: TextStyle(
                            fontSize: 13,
                            color: ReclimColors.textTertiary
                                .withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildListDelegate([
                  _SummaryGrid(stats: stats, period: period),
                  _TrendBanner(stats: stats),
                  if (stats.gymBreakdown
                      .where((g) => g.total > 0)
                      .isNotEmpty)
                    _GymSection(stats: stats),
                  _DailyClimbChartSection(stats: stats, period: period),
                  _ColorTrendSection(stats: stats, period: period),
                  const SizedBox(height: 24),
                ]),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('통계를 불러올 수 없습니다'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 기간 필터 ────────────────────────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  final StatsPeriod current;
  final ValueChanged<StatsPeriod> onChanged;
  const _PeriodSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: StatsPeriod.values.map((p) {
          final selected = p == current;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  p.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? ReclimColors.textPrimary
                        : ReclimColors.textTertiary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── [1] 2x2 요약 그리드 ─────────────────────────────────────────────────────

class _SummaryGrid extends StatelessWidget {
  final PeriodStatsData stats;
  final StatsPeriod period;
  const _SummaryGrid({required this.stats, required this.period});

  @override
  Widget build(BuildContext context) {
    // 등반 일수 계산
    final activeDays = stats.current
        .map((r) => DateTime(
            r.recordedAt.year, r.recordedAt.month, r.recordedAt.day))
        .toSet()
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.terrain_rounded,
                  label: '총 등반',
                  value: '${stats.totalClimbs}',
                  accent: ReclimColors.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle_rounded,
                  label: '완등',
                  value: '${stats.totalCompleted}',
                  accent: ReclimColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.percent_rounded,
                  label: '완등률',
                  value: '${stats.completionRate.toStringAsFixed(0)}%',
                  accent: ReclimColors.secondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  icon: Icons.calendar_today_rounded,
                  label: '등반 일수',
                  value: '$activeDays일',
                  accent: ReclimColors.inProgress,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ReclimColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: ReclimColors.textPrimary,
                    height: 1,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: ReclimColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── [2] 트렌드 배너 ─────────────────────────────────────────────────────────

class _TrendBanner extends StatelessWidget {
  final PeriodStatsData stats;
  const _TrendBanner({required this.stats});

  @override
  Widget build(BuildContext context) {
    if (!stats.hasPrevious) return const SizedBox.shrink();

    final climbDiff = stats.totalClimbs - stats.prevTotalClimbs;
    final rateDiff =
        (stats.completionRate - stats.prevCompletionRate).round();

    // 인사이트 메시지
    String? insight;
    if (rateDiff > 0) {
      insight = '완등률이 이전보다 $rateDiff%p 올랐어요!';
    } else if (climbDiff > 0) {
      insight = '등반 횟수가 $climbDiff건 늘었어요!';
    } else if (rateDiff < 0) {
      insight = '완등률이 이전보다 ${rateDiff.abs()}%p 내렸어요';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // 인사이트 텍스트
            if (insight != null)
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      rateDiff >= 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 18,
                      color: rateDiff >= 0
                          ? ReclimColors.success
                          : ReclimColors.accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        insight,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ReclimColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (insight == null) const Spacer(),
            const SizedBox(width: 8),
            // Diff 칩들
            _DiffChip(label: '등반', diff: climbDiff, suffix: '건'),
            const SizedBox(width: 6),
            _DiffChip(label: '완등률', diff: rateDiff, suffix: '%p'),
          ],
        ),
      ),
    );
  }
}

class _DiffChip extends StatelessWidget {
  final String label;
  final int diff;
  final String suffix;
  const _DiffChip({
    required this.label,
    required this.diff,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = diff > 0;
    final isNegative = diff < 0;
    final color = isPositive
        ? ReclimColors.success
        : isNegative
            ? ReclimColors.accent
            : ReclimColors.textTertiary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${isPositive ? '+' : ''}$diff$suffix',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ─── [3] 일별 등반 차트 ───────────────────────────────────────────────────────

class _DailyClimbChartSection extends StatelessWidget {
  final PeriodStatsData stats;
  final StatsPeriod period;
  const _DailyClimbChartSection({required this.stats, required this.period});

  @override
  Widget build(BuildContext context) {
    final series = stats.getDailyClimbSeries(period);
    if (series.isEmpty) return const SizedBox.shrink();

    double maxY = 1;
    for (final p in series) {
      if (p.count > maxY) maxY = p.count.toDouble();
    }
    final interval = max(1.0, (maxY / 4).ceilToDouble());
    maxY = interval * 4;

    int labelInterval;
    if (series.length <= 7) {
      labelInterval = 1;
    } else if (series.length <= 14) {
      labelInterval = 2;
    } else if (series.length <= 31) {
      labelInterval = 5;
    } else {
      labelInterval = 10;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ReclimColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '일별 등반 횟수',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: ReclimColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (value) => const FlLine(
                      color: ReclimColors.border,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: interval,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max || value < 0) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              value.toInt().toString(),
                              style: const TextStyle(
                                fontSize: 11,
                                color: ReclimColors.textTertiary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= series.length) {
                            return const SizedBox.shrink();
                          }
                          if (value != idx.toDouble()) {
                            return const SizedBox.shrink();
                          }
                          if (idx % labelInterval != 0 &&
                              idx != series.length - 1) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              series[idx].label,
                              style: const TextStyle(
                                fontSize: 10,
                                color: ReclimColors.textTertiary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (series.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(series.length, (i) {
                        return FlSpot(
                            i.toDouble(), series[i].count.toDouble());
                      }),
                      isCurved: true,
                      curveSmoothness: 0.3,
                      preventCurveOverShooting: true,
                      color: ReclimColors.accent,
                      barWidth: 2.5,
                      dotData: FlDotData(show: series.length <= 7),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            ReclimColors.accent.withOpacity(0.15),
                            ReclimColors.accent.withOpacity(0.02),
                          ],
                        ),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => Colors.white,
                      tooltipBorder:
                          const BorderSide(color: ReclimColors.border),
                      tooltipRoundedRadius: 8,
                      fitInsideHorizontally: true,
                      getTooltipItems: (spots) {
                        return spots.map((spot) {
                          final idx = spot.x.toInt();
                          final label =
                              idx < series.length ? series[idx].label : '';
                          return LineTooltipItem(
                            '$label: ${spot.y.toInt()}건',
                            const TextStyle(
                              color: ReclimColors.accent,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── [4] 암장별 통계 ──────────────────────────────────────────────────────────

class _GymSection extends StatelessWidget {
  final PeriodStatsData stats;
  const _GymSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    final allGymStats =
        stats.gymBreakdown.where((g) => g.total > 0).toList();
    if (allGymStats.isEmpty) return const SizedBox.shrink();

    final gymStats = allGymStats.take(5).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ReclimColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '암장별 통계 TOP 5',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: ReclimColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ...gymStats.map((gym) {
              final completedFraction =
                  gym.total > 0 ? gym.completed / gym.total : 0.0;
              final inProgressFraction =
                  gym.total > 0
                      ? (gym.total - gym.completed) / gym.total
                      : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: ReclimColors.accent,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            gym.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: ReclimColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${gym.total}건 · 완등 ${gym.completed}건 (${gym.completionRate.toStringAsFixed(0)}%)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: ReclimColors.textTertiary,
                          ),
                        ),
                        if (stats.hasPrevious) ...[
                          const SizedBox(width: 6),
                          _buildDiffBadge(
                              gym.total - gym.prevTotal),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 8,
                        child: Row(
                          children: [
                            if (completedFraction > 0)
                              Expanded(
                                flex:
                                    (completedFraction * 1000).round(),
                                child: Container(
                                    color: ReclimColors.success),
                              ),
                            if (inProgressFraction > 0)
                              Expanded(
                                flex: (inProgressFraction * 1000)
                                    .round(),
                                child: Container(
                                    color: ReclimColors.inProgress),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDiffBadge(int diff) {
    if (diff == 0) {
      return const Text(
        '—',
        style: TextStyle(
          fontSize: 11,
          color: ReclimColors.textTertiary,
        ),
      );
    }
    final isPositive = diff > 0;
    final color =
        isPositive ? ReclimColors.success : ReclimColors.accent;
    return Text(
      '${isPositive ? '+' : ''}$diff',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }
}

// ─── [5] 난이도 추이 차트 ─────────────────────────────────────────────────────

class _ColorTrendSection extends StatelessWidget {
  final PeriodStatsData stats;
  final StatsPeriod period;
  const _ColorTrendSection({required this.stats, required this.period});

  static const _difficultyColors = <String, Color>{
    'brown': Color(0xFF6D4C41),
    'gray': Color(0xFF9E9E9E),
    'purple': Color(0xFF9C27B0),
    'red': Color(0xFFF44336),
    'blue': Color(0xFF2196F3),
    'green': Color(0xFF4CAF50),
    'yellow': Color(0xFFDAC600),
    'orange': Color(0xFFFF9800),
    'white': Color(0xFFBDBDBD),
  };

  static const _colorLabels = <String, String>{
    'brown': '갈색',
    'gray': '회색',
    'purple': '보라',
    'red': '빨강',
    'blue': '파랑',
    'green': '초록',
    'yellow': '노랑',
    'orange': '주황',
    'white': '흰색',
  };

  @override
  Widget build(BuildContext context) {
    final timeSeries = stats.getColorTimeSeries(period);
    if (timeSeries.length < 2) return const SizedBox.shrink();

    final activeColors = timeSeries
        .expand((p) => p.colorCounts.entries)
        .where((e) => e.value > 0)
        .map((e) => e.key)
        .toSet()
        .toList();

    if (activeColors.isEmpty) return const SizedBox.shrink();

    const order = [
      'brown', 'gray', 'purple', 'red', 'blue', 'green', 'yellow',
      'orange', 'white',
    ];
    activeColors
        .sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));

    double maxY = 1;
    for (final point in timeSeries) {
      for (final count in point.colorCounts.values) {
        if (count > maxY) maxY = count.toDouble();
      }
    }
    final interval = max(1.0, (maxY / 4).ceilToDouble());
    maxY = interval * 4;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ReclimColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '난이도 추이',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: ReclimColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (value) => const FlLine(
                      color: ReclimColors.border,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: interval,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max || value < 0) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              value.toInt().toString(),
                              style: const TextStyle(
                                fontSize: 11,
                                color: ReclimColors.textTertiary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= timeSeries.length) {
                            return const SizedBox.shrink();
                          }
                          if (value != idx.toDouble()) {
                            return const SizedBox.shrink();
                          }
                          if (timeSeries.length > 8 && idx % 2 != 0) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              timeSeries[idx].label,
                              style: const TextStyle(
                                fontSize: 10,
                                color: ReclimColors.textTertiary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (timeSeries.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxY,
                  lineBarsData: activeColors.map((colorKey) {
                    final lineColor = _difficultyColors[colorKey]!;
                    return LineChartBarData(
                      spots: List.generate(timeSeries.length, (i) {
                        return FlSpot(
                          i.toDouble(),
                          (timeSeries[i].colorCounts[colorKey] ?? 0)
                              .toDouble(),
                        );
                      }),
                      isCurved: true,
                      curveSmoothness: 0.3,
                      preventCurveOverShooting: true,
                      color: lineColor,
                      barWidth: 2.5,
                      dotData: FlDotData(show: timeSeries.length <= 7),
                      belowBarData: BarAreaData(
                        show: true,
                        color: lineColor.withOpacity(0.06),
                      ),
                    );
                  }).toList(),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => Colors.white,
                      tooltipBorder:
                          const BorderSide(color: ReclimColors.border),
                      tooltipRoundedRadius: 8,
                      fitInsideHorizontally: true,
                      getTooltipItems: (spots) {
                        return spots.map((spot) {
                          final colorKey = activeColors[spot.barIndex];
                          final label =
                              _colorLabels[colorKey] ?? colorKey;
                          return LineTooltipItem(
                            '$label: ${spot.y.toInt()}건',
                            TextStyle(
                              color: _difficultyColors[colorKey],
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: activeColors.map((colorKey) {
                final lineColor = _difficultyColors[colorKey]!;
                final label = _colorLabels[colorKey] ?? colorKey;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: lineColor,
                        shape: BoxShape.circle,
                        border:
                            colorKey == 'white' || colorKey == 'yellow'
                                ? Border.all(
                                    color: const Color(0xFFBDBDBD),
                                    width: 0.5,
                                  )
                                : null,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: ReclimColors.textTertiary,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
