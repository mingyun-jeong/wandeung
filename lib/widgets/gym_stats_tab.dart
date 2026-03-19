import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app.dart';
import '../models/climbing_gym.dart';
import '../models/gym_color_scale.dart';
import '../models/gym_stats.dart';
import '../providers/favorite_gym_provider.dart';
import '../providers/gym_color_scale_provider.dart';
import '../providers/gym_stats_provider.dart';
import '../providers/record_provider.dart';
import '../utils/constants.dart';
import '../widgets/gym_selection_sheet.dart';

class GymStatsTab extends ConsumerWidget {
  const GymStatsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedGymId = ref.watch(selectedGymForStatsProvider);
    final favoriteGyms = ref.watch(favoriteGymsProvider);

    return favoriteGyms.when(
      data: (gyms) {
        final gymId =
            selectedGymId ?? (gyms.isNotEmpty ? gyms.first.id : null);
        final selectedGym =
            gyms.where((g) => g.id == gymId).firstOrNull;

        return Column(
          children: [
            // 암장 선택 (고정)
            _GymPickerBar(
              gyms: gyms,
              selectedGymId: gymId,
              onChanged: (id) => ref
                  .read(selectedGymForStatsProvider.notifier)
                  .state = id,
              onSearch: () => _openGymSearch(context, ref),
            ),

            // 콘텐츠
            Expanded(
              child: gymId == null
                  ? _buildEmptyState(context, ref)
                  : RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(gymStatsProvider(gymId));
                        ref.invalidate(myGymRankingProvider(gymId));
                      },
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        children: [
                          _GymStatsContent(
                            gymId: gymId,
                            gymName: selectedGym?.name,
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류가 발생했습니다: $e')),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: WandeungColors.border.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.store_outlined,
              size: 32,
              color: WandeungColors.textTertiary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '암장을 검색해보세요',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: WandeungColors.textTertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '암장별 통계와 내 순위를 확인할 수 있어요',
            style: TextStyle(
              fontSize: 13,
              color: WandeungColors.textTertiary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  void _openGymSearch(BuildContext context, WidgetRef ref) {
    GymSelectionSheet.show(
      context,
      onGymSelected: (gym) async {
        final gymId =
            gym.id ?? await RecordService.findOrCreateGym(gym);
        ref.read(selectedGymForStatsProvider.notifier).state = gymId;
      },
    );
  }
}

// ─── 암장 선택 바 (고정) ──────────────────────────────────────────────────────

class _GymPickerBar extends StatelessWidget {
  final List<ClimbingGym> gyms;
  final String? selectedGymId;
  final ValueChanged<String?> onChanged;
  final VoidCallback onSearch;
  const _GymPickerBar({
    required this.gyms,
    required this.selectedGymId,
    required this.onChanged,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          // 셀렉트박스
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: WandeungColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: gyms.any((g) => g.id == selectedGymId)
                      ? selectedGymId
                      : null,
                  hint: const Text(
                    '내 암장 선택',
                    style: TextStyle(
                      fontSize: 15,
                      color: WandeungColors.textTertiary,
                    ),
                  ),
                  isExpanded: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: WandeungColors.textTertiary,
                  ),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: WandeungColors.textPrimary,
                  ),
                  items: gyms
                      .where((g) => g.id != null)
                      .map((gym) => DropdownMenuItem(
                            value: gym.id,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 16,
                                  color: WandeungColors.accent,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    gym.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 검색 버튼
          GestureDetector(
            onTap: onSearch,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: WandeungColors.accent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.search_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 통계 콘텐츠 ──────────────────────────────────────────────────────────────

class _GymStatsContent extends ConsumerWidget {
  final String gymId;
  final String? gymName;
  const _GymStatsContent({required this.gymId, this.gymName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(gymStatsProvider(gymId));
    final rankingAsync = ref.watch(myGymRankingProvider(gymId));

    return statsAsync.when(
      data: (stats) {
        if (stats == null || stats.totalClimbs == 0) {
          return const Padding(
            padding: EdgeInsets.only(top: 48),
            child: Center(
              child: Text(
                '최근 30일간 기록이 없습니다',
                style: TextStyle(color: WandeungColors.textTertiary),
              ),
            ),
          );
        }

        final ranking = rankingAsync.valueOrNull;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // [1] 암장 전체 통계
            _GymSummaryCard(stats: stats),

            // [2] 나의 포지션
            if (ranking != null && ranking.myClimbs > 0) ...[
              const SizedBox(height: 12),
              _MyPositionCard(stats: stats, ranking: ranking),
            ],

            // [3] 등급 분포
            const SizedBox(height: 12),
            _GradeDistributionCard(stats: stats, gymName: gymName),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 36,
                  color: WandeungColors.textTertiary.withOpacity(0.5)),
              const SizedBox(height: 8),
              const Text(
                '통계를 불러올 수 없습니다',
                style: TextStyle(color: WandeungColors.textTertiary),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  ref.invalidate(gymStatsProvider(gymId));
                  ref.invalidate(myGymRankingProvider(gymId));
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── [1] 암장 전체 통계 ───────────────────────────────────────────────────────

class _GymSummaryCard extends StatelessWidget {
  final GymStats stats;
  const _GymSummaryCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final topGrades = stats.popularGrades.take(3).join(', ');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WandeungColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '암장 통계',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: WandeungColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '최근 30일',
                style: TextStyle(
                  fontSize: 11,
                  color: WandeungColors.textTertiary.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 3칸 수치
          Row(
            children: [
              _SummaryValue(
                value: '${stats.totalUsers}',
                unit: '명',
                label: '방문자',
              ),
              _divider(),
              _SummaryValue(
                value: '${stats.totalClimbs}',
                unit: '개',
                label: '전체 기록',
              ),
              _divider(),
              _SummaryValue(
                value: stats.avgCompletionRate.toStringAsFixed(0),
                unit: '%',
                label: '평균 완등률',
              ),
            ],
          ),

          // 인기 등급
          if (topGrades.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded,
                      size: 16, color: WandeungColors.inProgress),
                  const SizedBox(width: 8),
                  const Text(
                    '인기 등급',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: WandeungColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      topGrades,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: WandeungColors.textPrimary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: WandeungColors.border,
    );
  }
}

class _SummaryValue extends StatelessWidget {
  final String value;
  final String unit;
  final String label;
  const _SummaryValue({
    required this.value,
    required this.unit,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: WandeungColors.textPrimary,
                  height: 1,
                  letterSpacing: -1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 2, left: 1),
                child: Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: WandeungColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: WandeungColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── [2] 나의 포지션 ─────────────────────────────────────────────────────────

class _MyPositionCard extends StatelessWidget {
  final GymStats stats;
  final MyGymRanking ranking;
  const _MyPositionCard({required this.stats, required this.ranking});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: WandeungColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '이 암장에서 나는',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),

          // 3열: 기록수 | 완등률 | 최고등급
          Row(
            children: [
              // 기록수
              Expanded(
                child: _PositionItem(
                  value: '${ranking.myClimbs}건',
                  label: '기록',
                  percentile: ranking.climbsPercentile,
                ),
              ),
              Container(
                width: 1,
                height: 64,
                color: Colors.white.withOpacity(0.1),
              ),
              // 완등률
              Expanded(
                child: _PositionItem(
                  value:
                      '${ranking.myCompletionRate.toStringAsFixed(0)}%',
                  label: '완등률',
                  percentile: ranking.completionPercentile,
                  highlight: true,
                ),
              ),
              Container(
                width: 1,
                height: 64,
                color: Colors.white.withOpacity(0.1),
              ),
              // 최고등급
              Expanded(
                child: _PositionItem(
                  value: ranking.highestGrade.isNotEmpty
                      ? ranking.highestGrade
                      : '-',
                  label: '최고 등급',
                  percentile: ranking.highestGrade.isNotEmpty
                      ? ranking.gradePercentile
                      : null,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 평균 대비 바
          _ComparisonBar(
            myRate: ranking.myCompletionRate,
            avgRate: stats.avgCompletionRate,
          ),
        ],
      ),
    );
  }
}

class _PositionItem extends StatelessWidget {
  final String value;
  final String label;
  final int? percentile;
  final bool highlight;
  const _PositionItem({
    required this.value,
    required this.label,
    this.percentile,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: highlight ? 26 : 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
        if (percentile != null) ...[
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _percentileColor(percentile!).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '상위 $percentile%',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _percentileColor(percentile!),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Color _percentileColor(int p) {
    if (p <= 10) return const Color(0xFFFFD700);
    if (p <= 30) return const Color(0xFF4ADE80);
    if (p <= 60) return const Color(0xFF60A5FA);
    return Colors.white70;
  }
}

class _ComparisonBar extends StatelessWidget {
  final double myRate;
  final double avgRate;
  const _ComparisonBar({required this.myRate, required this.avgRate});

  @override
  Widget build(BuildContext context) {
    final myNorm = (myRate / 100).clamp(0.0, 1.0);
    final avgNorm = (avgRate / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          // 라벨 Row
          Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: WandeungColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '나 ${myRate.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: WandeungColors.success,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '평균 ${avgRate.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 바
          SizedBox(
            height: 8,
            child: Stack(
              children: [
                // 배경
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // 평균 바
                FractionallySizedBox(
                  widthFactor: avgNorm,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                // 내 바
                FractionallySizedBox(
                  widthFactor: myNorm,
                  child: Container(
                    decoration: BoxDecoration(
                      color: WandeungColors.success,
                      borderRadius: BorderRadius.circular(4),
                    ),
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

// ─── [3] 등급 분포 ────────────────────────────────────────────────────────────

class _GradeDistributionCard extends ConsumerWidget {
  final GymStats stats;
  final String? gymName;
  const _GradeDistributionCard({required this.stats, this.gymName});

  static ClimbingGrade? _parseGrade(String grade) {
    final normalized =
        grade.trim().toLowerCase().replaceAll('-', '');
    for (final g in ClimbingGrade.values) {
      if (g.label.toLowerCase() == normalized ||
          g.name.toLowerCase() == normalized) {
        return g;
      }
    }
    return null;
  }

  static Color _barColor(String grade, GymColorScale? colorScale) {
    final g = _parseGrade(grade);
    if (g == null) return const Color(0xFF9E9E9E);

    if (colorScale != null) {
      for (final level in colorScale.levels) {
        if (g.sortIndex >= level.vMin.sortIndex &&
            g.sortIndex <= level.vMax.sortIndex) {
          return Color(level.color.colorValue);
        }
      }
    }
    return Color(g.defaultColor.colorValue);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grades = stats.gradeDistribution;
    if (grades.isEmpty) return const SizedBox.shrink();

    final colorScale = gymName != null
        ? ref.watch(gymColorScaleProvider(gymName!))
        : null;

    final maxCount = grades
        .map((g) => g.count)
        .reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WandeungColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '등급 분포',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: WandeungColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...grades.map((g) {
            final barColor = _barColor(g.grade, colorScale);
            final needsBorder =
                barColor.computeLuminance() > 0.7;
            final barFraction =
                maxCount > 0 ? g.count / maxCount : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      g.grade,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: WandeungColors.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Stack(
                        children: [
                          LinearProgressIndicator(
                            value: barFraction,
                            minHeight: 20,
                            backgroundColor: const Color(0xFFF0F0F0),
                            valueColor:
                                AlwaysStoppedAnimation(barColor),
                          ),
                          if (needsBorder)
                            Positioned.fill(
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: barFraction,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(4),
                                    border: Border.all(
                                      color: const Color(0xFFBDBDBD),
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${g.count}',
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: WandeungColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 40,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${g.completionRate.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: g.completionRate >= 70
                            ? WandeungColors.success
                            : g.completionRate >= 40
                                ? WandeungColors.inProgress
                                : WandeungColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          // 범례
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _legendDot(WandeungColors.success, '완등 70%↑'),
              const SizedBox(width: 10),
              _legendDot(WandeungColors.inProgress, '40~70%'),
              const SizedBox(width: 10),
              _legendDot(WandeungColors.accent, '40%↓'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            color: WandeungColors.textTertiary,
          ),
        ),
      ],
    );
  }
}
