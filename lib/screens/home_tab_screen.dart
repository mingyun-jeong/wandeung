import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app.dart';
import '../models/climbing_gym.dart';
import '../models/user_climbing_stats.dart';
import '../providers/camera_settings_provider.dart';
import '../providers/record_provider.dart';
import '../screens/gym_detail_screen.dart';
import '../widgets/record_card.dart';
import '../widgets/wandeung_app_bar.dart';

class HomeTabScreen extends ConsumerWidget {
  const HomeTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(userStatsProvider);
    final recentAsync = ref.watch(recentRecordsProvider);
    final gymsAsync = ref.watch(recentGymsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const WandeungAppBar(),
      body: RefreshIndicator(
        color: WandeungColors.accent,
        onRefresh: () async {
          ref.invalidate(userStatsProvider);
          ref.invalidate(recentRecordsProvider);
          ref.invalidate(recentGymsProvider);
        },
        child: CustomScrollView(
          slivers: [
            // 요약 통계 (streak + 완등률)
            SliverToBoxAdapter(
              child: statsAsync.when(
                data: (stats) => _StatsSection(stats: stats),
                loading: () => const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('통계를 불러올 수 없습니다'),
                ),
              ),
            ),

            // 주간 활동 히트맵
            SliverToBoxAdapter(
              child: statsAsync.whenOrNull(
                    data: (stats) => const _WeeklyHeatmap(),
                  ) ??
                  const SizedBox.shrink(),
            ),

            // 최근 방문 암장
            SliverToBoxAdapter(
              child: gymsAsync.whenOrNull(
                    data: (gyms) =>
                        gyms.isNotEmpty ? _RecentGymsSection(gyms: gyms) : null,
                  ) ??
                  const SizedBox.shrink(),
            ),

            // 최근 기록 헤더
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
                child: Row(
                  children: [
                    Text(
                      '최근 기록',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    recentAsync.whenOrNull(
                          data: (records) => records.isNotEmpty
                              ? TextButton(
                                  onPressed: () {
                                    ref
                                        .read(
                                            bottomNavIndexProvider.notifier)
                                        .state = 3;
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '더보기',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 18,
                                        color: colorScheme.primary,
                                      ),
                                    ],
                                  ),
                                )
                              : null,
                        ) ??
                        const SizedBox.shrink(),
                  ],
                ),
              ),
            ),

            // 최근 기록 리스트
            recentAsync.when(
              data: (records) {
                if (records.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: WandeungColors.accent.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.terrain_outlined,
                                size: 36,
                                color: WandeungColors.accent.withOpacity(0.4),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              '아직 기록이 없어요',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: WandeungColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              '첫 등반을 기록해보세요!',
                              style: TextStyle(
                                fontSize: 13,
                                color: WandeungColors.textTertiary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: () {
                                ref.read(bottomNavIndexProvider.notifier).state = 2;
                              },
                              icon: const Icon(Icons.videocam_rounded, size: 18),
                              label: const Text('촬영하기'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.separated(
                    itemCount: records.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 2),
                    itemBuilder: (_, i) => RecordCard(record: records[i]),
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, _) => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: Text('기록을 불러올 수 없습니다')),
                ),
              ),
            ),

            // 하단 여백
            const SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 주간 활동 히트맵 ─────────────────────────────────────────────────────────

class _WeeklyHeatmap extends ConsumerWidget {
  const _WeeklyHeatmap();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));

    final dayLabels = ['월', '화', '수', '목', '금', '토', '일'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: WandeungColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.local_fire_department_rounded,
                    size: 16, color: WandeungColors.accent),
                SizedBox(width: 6),
                Text(
                  '이번 주 활동',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: WandeungColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (i) {
                final day = monday.add(Duration(days: i));
                final isToday = day.isAtSameMomentAs(today);
                final isFuture = day.isAfter(today);

                return ref.watch(recordsByDateProvider(day)).when(
                      data: (records) {
                        final hasRecord = records.isNotEmpty;
                        return _DayDot(
                          label: dayLabels[i],
                          hasRecord: hasRecord,
                          isToday: isToday,
                          isFuture: isFuture,
                        );
                      },
                      loading: () => _DayDot(
                        label: dayLabels[i],
                        hasRecord: false,
                        isToday: isToday,
                        isFuture: isFuture,
                      ),
                      error: (_, __) => _DayDot(
                        label: dayLabels[i],
                        hasRecord: false,
                        isToday: isToday,
                        isFuture: isFuture,
                      ),
                    );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  final String label;
  final bool hasRecord;
  final bool isToday;
  final bool isFuture;

  const _DayDot({
    required this.label,
    required this.hasRecord,
    required this.isToday,
    required this.isFuture,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            color: isToday
                ? WandeungColors.accent
                : WandeungColors.textTertiary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasRecord
                ? WandeungColors.accent
                : isFuture
                    ? Colors.transparent
                    : WandeungColors.border.withOpacity(0.5),
            border: isToday && !hasRecord
                ? Border.all(color: WandeungColors.accent, width: 2)
                : null,
          ),
          child: hasRecord
              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
              : null,
        ),
      ],
    );
  }
}

// ─── 최근 방문 암장 ───────────────────────────────────────────────────────────

class _RecentGymsSection extends StatefulWidget {
  final List<ClimbingGym> gyms;
  const _RecentGymsSection({required this.gyms});

  @override
  State<_RecentGymsSection> createState() => _RecentGymsSectionState();
}

class _RecentGymsSectionState extends State<_RecentGymsSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final GlobalKey _contentKey = GlobalKey();
  double _contentWidth = 0;
  bool _measured = false;

  bool get _shouldMarquee => widget.gyms.length >= 2;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    if (_shouldMarquee) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureAndStart());
    }
  }

  void _measureAndStart() {
    final box =
        _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final width = box.size.width;
    if (width > 0) {
      setState(() {
        _contentWidth = width;
        _measured = true;
      });
      final totalScroll = _contentWidth + 8;
      final duration = Duration(milliseconds: (totalScroll / 40 * 1000).round());
      _controller
        ..duration = duration
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildChip(ClimbingGym gym, ColorScheme colorScheme) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GymDetailScreen(gym: gym),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: WandeungColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 15,
              color: WandeungColors.accent,
            ),
            const SizedBox(width: 4),
            Text(
              gym.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChipRow(ColorScheme colorScheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < widget.gyms.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          _buildChip(widget.gyms[i], colorScheme),
        ],
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              '최근 방문 암장',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          SizedBox(
            height: 38,
            child: _shouldMarquee
                ? ClipRect(
                    child: _measured
                        ? AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) {
                              final dx =
                                  -_controller.value * (_contentWidth + 8);
                              return Transform.translate(
                                offset: Offset(dx, 0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildChipRow(colorScheme),
                                    const SizedBox(width: 8),
                                    _buildChipRow(colorScheme),
                                  ],
                                ),
                              );
                            },
                          )
                        : Row(
                            key: _contentKey,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildChipRow(colorScheme),
                            ],
                          ),
                  )
                : _buildChipRow(colorScheme),
          ),
        ],
      ),
    );
  }
}

// ─── 통계 섹션 (리디자인) ─────────────────────────────────────────────────────

class _StatsSection extends StatelessWidget {
  final UserClimbingStats stats;
  const _StatsSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    final completedRatio = stats.totalClimbs > 0
        ? stats.totalCompleted / stats.totalClimbs
        : 0.0;
    final inProgressRatio = stats.totalClimbs > 0
        ? stats.totalInProgress / stats.totalClimbs
        : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              WandeungColors.secondary,
              WandeungColors.primary,
              Color(0xFF16213E),
            ],
            stops: [0.0, 0.6, 1.0],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: WandeungColors.primary.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Streak 배너
            if (stats.currentStreak > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: WandeungColors.accent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: WandeungColors.accent.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        size: 16,
                        color: WandeungColors.accentLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '연속 ${stats.currentStreak}일째 클라이밍 중!',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: WandeungColors.accentLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            Row(
              children: [
                Text(
                  '최근 30일',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '총 ${stats.totalClimbs}건',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _RateDisplay(
                    label: '완등',
                    rate: stats.completionRate,
                    count: stats.totalCompleted,
                    color: WandeungColors.success,
                  ),
                ),
                Container(
                  width: 1,
                  height: 48,
                  color: Colors.white.withOpacity(0.2),
                ),
                Expanded(
                  child: _RateDisplay(
                    label: '도전중',
                    rate: stats.inProgressRate,
                    count: stats.totalInProgress,
                    color: WandeungColors.inProgress,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // 세그먼트 프로그레스 바
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 6,
                child: Row(
                  children: [
                    if (completedRatio > 0)
                      Expanded(
                        flex: (completedRatio * 1000).round(),
                        child: Container(color: WandeungColors.success),
                      ),
                    if (inProgressRatio > 0)
                      Expanded(
                        flex: (inProgressRatio * 1000).round(),
                        child: Container(color: WandeungColors.inProgress),
                      ),
                    if ((1 - completedRatio - inProgressRatio) > 0)
                      Expanded(
                        flex: ((1 - completedRatio - inProgressRatio) * 1000).round(),
                        child: Container(
                          color: Colors.white.withOpacity(0.15),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RateDisplay extends StatelessWidget {
  final String label;
  final double rate;
  final int count;
  final Color color;

  const _RateDisplay({
    required this.label,
    required this.rate,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              rate.toStringAsFixed(0),
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1,
                letterSpacing: -1.5,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 1),
              child: Text(
                '%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$label $count건',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
