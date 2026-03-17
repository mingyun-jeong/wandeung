import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/climbing_gym.dart';
import '../models/gym_color_scale.dart';
import '../models/gym_stats.dart';
import '../providers/favorite_gym_provider.dart';
import '../providers/gym_color_scale_provider.dart';
import '../providers/gym_stats_provider.dart';
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
        // 선택된 암장이 없으면 즐겨찾기 첫 번째로 설정
        final gymId = selectedGymId ?? (gyms.isNotEmpty ? gyms.first.id : null);
        if (gymId == null) {
          return _buildEmptyState(context, ref);
        }
        // 선택된 암장 이름 찾기
        final selectedGym = gyms.where((g) => g.id == gymId).firstOrNull;

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(gymStatsProvider(gymId));
            ref.invalidate(myGymRankingProvider(gymId));
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _GymSelector(
                gyms: gyms,
                selectedGymId: gymId,
                selectedGymName: selectedGym?.name,
              ),
              const SizedBox(height: 16),
              _GymStatsContent(gymId: gymId, gymName: selectedGym?.name),
            ],
          ),
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
          Icon(Icons.store_outlined,
              size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('즐겨찾기한 암장이 없습니다',
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _openGymSearch(context, ref),
            icon: const Icon(Icons.search, size: 18),
            label: const Text('암장 검색'),
          ),
        ],
      ),
    );
  }

  void _openGymSearch(BuildContext context, WidgetRef ref) {
    GymSelectionSheet.show(
      context,
      onGymSelected: (gym) {
        if (gym.id != null) {
          ref.read(selectedGymForStatsProvider.notifier).state = gym.id;
        }
      },
    );
  }
}

/// 암장 선택 드롭다운 + 검색 버튼
class _GymSelector extends ConsumerWidget {
  final List<ClimbingGym> gyms;
  final String selectedGymId;
  final String? selectedGymName;

  const _GymSelector({
    required this.gyms,
    required this.selectedGymId,
    this.selectedGymName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: gyms.isEmpty
                ? Text(selectedGymName ?? '암장을 선택하세요',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))
                : DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: gyms.any((g) => g.id == selectedGymId)
                          ? selectedGymId
                          : null,
                      hint: Text(selectedGymName ?? '암장 선택'),
                      isExpanded: true,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                      items: gyms.map((gym) {
                        return DropdownMenuItem(
                          value: gym.id,
                          child: Text(gym.name),
                        );
                      }).toList(),
                      onChanged: (id) {
                        if (id != null) {
                          ref.read(selectedGymForStatsProvider.notifier).state = id;
                        }
                      },
                    ),
                  ),
          ),
          IconButton(
            icon: const Icon(Icons.search, size: 20),
            tooltip: '다른 암장 검색',
            onPressed: () {
              GymSelectionSheet.show(
                context,
                onGymSelected: (gym) {
                  if (gym.id != null) {
                    ref.read(selectedGymForStatsProvider.notifier).state = gym.id;
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 통계 내용 (요약 카드 + 차트 + 순위)
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
          return Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Center(
              child: Text('최근 30일간 기록이 없습니다',
                  style: TextStyle(color: Colors.grey.shade600)),
            ),
          );
        }

        final ranking = rankingAsync.valueOrNull;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SummaryCards(stats: stats, ranking: ranking),
            if (ranking != null) ...[
              const SizedBox(height: 20),
              _RankingCard(ranking: ranking),
            ],
            const SizedBox(height: 20),
            _GradeChart(stats: stats, gymName: gymName),
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
              Icon(Icons.error_outline, size: 36, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text('통계를 불러올 수 없습니다',
                  style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 4),
              Text('$e',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  textAlign: TextAlign.center),
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

/// 요약 카드 3개 (방문자, 기록, 완등률) + 내 완등률 뱃지
class _SummaryCards extends StatelessWidget {
  final GymStats stats;
  final MyGymRanking? ranking;

  const _SummaryCards({required this.stats, this.ranking});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Row(
          children: [
            _StatTile(
              label: '방문자',
              value: '${stats.totalUsers}명',
              icon: Icons.people_outline,
            ),
            const SizedBox(width: 8),
            _StatTile(
              label: '전체 기록',
              value: '${stats.totalClimbs}개',
              icon: Icons.trending_up,
            ),
            const SizedBox(width: 8),
            _StatTile(
              label: '평균 완등률',
              value: '${stats.avgCompletionRate.toStringAsFixed(0)}%',
              icon: Icons.check_circle_outline,
            ),
          ],
        ),
        if (ranking != null && ranking!.myClimbs > 0) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events,
                    color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  '내 완등률 ${ranking!.myCompletionRate.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '상위 ${ranking!.completionPercentile}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// 개별 통계 타일
class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: colorScheme.primary),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

/// 등급 분포 가로 바 차트 (암장 난이도 색상 반영)
class _GradeChart extends ConsumerWidget {
  final GymStats stats;
  final String? gymName;
  const _GradeChart({required this.stats, this.gymName});

  /// grade 문자열을 ClimbingGrade enum으로 변환
  static ClimbingGrade? _parseGrade(String grade) {
    final normalized = grade.trim().toLowerCase().replaceAll('-', '');
    for (final g in ClimbingGrade.values) {
      if (g.label.toLowerCase() == normalized || g.name.toLowerCase() == normalized) {
        return g;
      }
    }
    return null;
  }

  /// 등급에 해당하는 난이도 색상 결정
  static Color _barColor(String grade, GymColorScale? colorScale) {
    final g = _parseGrade(grade);
    if (g == null) return Colors.grey;

    if (colorScale != null) {
      for (final level in colorScale.levels) {
        if (g.sortIndex >= level.vMin.sortIndex &&
            g.sortIndex <= level.vMax.sortIndex) {
          return Color(level.color.colorValue);
        }
      }
    }

    // 폴백: 등급의 기본 색상
    return Color(g.defaultColor.colorValue);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final grades = stats.gradeDistribution;
    if (grades.isEmpty) return const SizedBox.shrink();

    final colorScale = gymName != null
        ? ref.watch(gymColorScaleProvider(gymName!))
        : null;

    final maxCount = grades
        .map((g) => g.count)
        .reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('등급 분포',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface)),
        const SizedBox(height: 4),
        Text('최근 30일',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 12),
        ...grades.map((g) {
          final barColor = _barColor(g.grade, colorScale);
          // 흰색/노랑 등 밝은 색은 테두리 추가
          final needsBorder = barColor.computeLuminance() > 0.7;

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(g.grade,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      children: [
                        LinearProgressIndicator(
                          value: maxCount > 0 ? g.count / maxCount : 0,
                          minHeight: 18,
                          backgroundColor: const Color(0xFFF0F0F0),
                          valueColor: AlwaysStoppedAnimation(barColor),
                        ),
                        if (needsBorder)
                          Positioned.fill(
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: maxCount > 0 ? g.count / maxCount : 0,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: Colors.grey.shade400, width: 0.5),
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
                  child: Text('${g.count}',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

/// 내 순위 카드
class _RankingCard extends StatelessWidget {
  final MyGymRanking ranking;
  const _RankingCard({required this.ranking});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('내 순위',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface)),
          const SizedBox(height: 12),
          _RankRow(
            icon: Icons.fitness_center,
            label: '기록 수',
            value: '${ranking.myClimbs}개',
            percentile: ranking.climbsPercentile,
          ),
          const SizedBox(height: 8),
          _RankRow(
            icon: Icons.check_circle_outline,
            label: '완등률',
            value: '${ranking.myCompletionRate.toStringAsFixed(0)}%',
            percentile: ranking.completionPercentile,
          ),
          if (ranking.highestGrade.isNotEmpty) ...[
            const SizedBox(height: 8),
            _RankRow(
              icon: Icons.arrow_upward,
              label: '최고 등급',
              value: ranking.highestGrade,
              percentile: ranking.gradePercentile,
            ),
          ],
        ],
      ),
    );
  }
}

/// 순위 행 위젯
class _RankRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final int percentile;

  const _RankRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.percentile,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _percentileColor(percentile).withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '상위 $percentile%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _percentileColor(percentile),
            ),
          ),
        ),
      ],
    );
  }

  Color _percentileColor(int p) {
    if (p <= 10) return Colors.amber.shade700;
    if (p <= 30) return Colors.green.shade600;
    if (p <= 60) return Colors.blue.shade600;
    return Colors.grey.shade600;
  }
}
