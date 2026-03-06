import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/stats_provider.dart';
import '../widgets/wandeung_app_bar.dart';

class StatsTabScreen extends ConsumerWidget {
  const StatsTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(statsPeriodProvider);
    final statsAsync = ref.watch(periodStatsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const WandeungAppBar(),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(periodStatsProvider),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: StatsPeriod.values.map((p) {
                    final selected = p == period;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(p.label),
                        selected: selected,
                        onSelected: (_) =>
                            ref.read(statsPeriodProvider.notifier).state = p,
                        selectedColor: colorScheme.primary,
                        labelStyle: TextStyle(
                          color: selected
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface.withOpacity(0.6),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: selected
                              ? colorScheme.primary
                              : const Color(0xFFE8ECF0),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        showCheckmark: false,
                      ),
                    );
                  }).toList(),
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
                              color: colorScheme.surfaceContainerHighest
                                  .withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.bar_chart_rounded,
                              size: 32,
                              color: colorScheme.onSurface.withOpacity(0.25),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '아직 통계가 없어요',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurface.withOpacity(0.35),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '등반 기록을 추가해보세요!',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurface.withOpacity(0.25),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildListDelegate([
                    _SummarySection(stats: stats, period: period),
                    _ColorTrendSection(stats: stats, period: period),
                    if (stats.gymBreakdown
                        .where((g) => g.total > 0)
                        .isNotEmpty)
                      _GymSection(stats: stats),
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
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  final PeriodStatsData stats;
  final StatsPeriod period;
  const _SummarySection({required this.stats, required this.period});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const completedColor = Color(0xFF4ADE80);
    const inProgressColor = Color(0xFFFBBF24);

    final completedRatio = stats.totalClimbs > 0
        ? stats.totalCompleted / stats.totalClimbs
        : 0.0;
    final inProgressRatio = stats.totalClimbs > 0
        ? stats.totalInProgress / stats.totalClimbs
        : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary,
              colorScheme.primary.withOpacity(0.85),
              const Color(0xFF0D9488),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '최근 ${period.label}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onPrimary.withOpacity(0.7),
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.onPrimary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '총 ${stats.totalClimbs}건',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onPrimary.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            stats.completionRate.toStringAsFixed(0),
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onPrimary,
                              height: 1,
                              letterSpacing: -2,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6, left: 2),
                            child: Text(
                              '%',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onPrimary.withOpacity(0.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '완등률',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onPrimary.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 56,
                  color: colorScheme.onPrimary.withOpacity(0.2),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: completedColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '완등 ${stats.totalCompleted}건',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onPrimary.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: inProgressColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '도전중 ${stats.totalInProgress}건',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onPrimary.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 6,
                child: Row(
                  children: [
                    if (completedRatio > 0)
                      Expanded(
                        flex: (completedRatio * 1000).round(),
                        child: Container(color: completedColor),
                      ),
                    if (inProgressRatio > 0)
                      Expanded(
                        flex: (inProgressRatio * 1000).round(),
                        child: Container(color: inProgressColor),
                      ),
                    if ((1 - completedRatio - inProgressRatio) > 0)
                      Expanded(
                        flex:
                            ((1 - completedRatio - inProgressRatio) * 1000)
                                .round(),
                        child: Container(
                          color: colorScheme.onPrimary.withOpacity(0.15),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (stats.hasPrevious) ...[
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.onPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Text(
                      '이전 대비',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onPrimary.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _DiffChip(
                      label: '등반',
                      diff: stats.totalClimbs - stats.prevTotalClimbs,
                      suffix: '건',
                      onPrimaryColor: colorScheme.onPrimary,
                    ),
                    const SizedBox(width: 10),
                    _DiffChip(
                      label: '완등률',
                      diff: (stats.completionRate - stats.prevCompletionRate)
                          .round(),
                      suffix: '%p',
                      onPrimaryColor: colorScheme.onPrimary,
                    ),
                  ],
                ),
              ),
            ],
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
  final Color onPrimaryColor;

  const _DiffChip({
    required this.label,
    required this.diff,
    required this.suffix,
    required this.onPrimaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = diff > 0;
    final isNegative = diff < 0;
    final color = isPositive
        ? const Color(0xFF4ADE80)
        : isNegative
            ? const Color(0xFFF87171)
            : onPrimaryColor.withOpacity(0.5);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: onPrimaryColor.withOpacity(0.7),
          ),
        ),
        if (isPositive)
          Icon(Icons.arrow_upward_rounded, size: 12, color: color),
        if (isNegative)
          Icon(Icons.arrow_downward_rounded, size: 12, color: color),
        Text(
          '${isPositive ? '+' : ''}$diff$suffix',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

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

    final colorScheme = Theme.of(context).colorScheme;

    final activeColors = timeSeries
        .expand((p) => p.colorCounts.entries)
        .where((e) => e.value > 0)
        .map((e) => e.key)
        .toSet()
        .toList();

    if (activeColors.isEmpty) return const SizedBox.shrink();

    // Hard→Easy 순서 유지
    const order = ['brown', 'gray', 'purple', 'red', 'blue', 'green', 'yellow', 'orange', 'white'];
    activeColors.sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));

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
          border: Border.all(color: const Color(0xFFE8ECF0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '난이도 추이',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
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
                      color: Color(0xFFE8ECF0),
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
                              style: TextStyle(
                                fontSize: 11,
                                color:
                                    colorScheme.onSurface.withOpacity(0.4),
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
                              style: TextStyle(
                                fontSize: 10,
                                color:
                                    colorScheme.onSurface.withOpacity(0.4),
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
                      dotData: FlDotData(
                        show: timeSeries.length <= 7,
                      ),
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
                          const BorderSide(color: Color(0xFFE8ECF0)),
                      tooltipRoundedRadius: 8,
                      fitInsideHorizontally: true,
                      getTooltipItems: (spots) {
                        return spots.map((spot) {
                          final colorKey = activeColors[spot.barIndex];
                          final label = _colorLabels[colorKey] ?? colorKey;
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
                        border: colorKey == 'white' || colorKey == 'yellow'
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
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface.withOpacity(0.5),
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

class _GymSection extends StatelessWidget {
  final PeriodStatsData stats;
  const _GymSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final allGymStats = stats.gymBreakdown.where((g) => g.total > 0).toList();
    if (allGymStats.isEmpty) return const SizedBox.shrink();

    final gymStats = allGymStats.take(5).toList();
    final maxTotal =
        gymStats.map((g) => g.total).fold<int>(1, (a, b) => max(a, b));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8ECF0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '암장별 통계 TOP 5',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ...gymStats.map((gym) {
              final diff = gym.total - gym.prevTotal;
              final barFraction = gym.total / maxTotal;
              final completedFraction =
                  gym.total > 0 ? gym.completed / gym.total : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            gym.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${gym.total}건 · 완등 ${gym.completed}건 (${gym.completionRate.toStringAsFixed(0)}%)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                        if (stats.hasPrevious) ...[
                          const SizedBox(width: 6),
                          _buildDiffBadge(diff, colorScheme),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 8,
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: barFraction,
                            child: Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFBBF24),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: completedFraction,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4ADE80),
                                      borderRadius: completedFraction >= 1.0
                                          ? BorderRadius.circular(4)
                                          : const BorderRadius.only(
                                              topLeft: Radius.circular(4),
                                              bottomLeft: Radius.circular(4),
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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

  Widget _buildDiffBadge(int diff, ColorScheme colorScheme) {
    if (diff == 0) {
      return Text(
        '—',
        style: TextStyle(
          fontSize: 11,
          color: colorScheme.onSurface.withOpacity(0.3),
        ),
      );
    }
    final isPositive = diff > 0;
    final color =
        isPositive ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
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
