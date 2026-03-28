import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app.dart';
import '../config/r2_config.dart';
import '../models/climbing_gym.dart';
import '../models/climbing_record.dart';
import '../models/gym_setting_schedule.dart';
import '../models/user_climbing_stats.dart';
import '../providers/camera_settings_provider.dart';
import '../providers/gym_stats_provider.dart';
import '../providers/record_provider.dart';
import '../providers/setting_schedule_provider.dart';
import '../screens/gym_detail_screen.dart';
import '../screens/record_save_screen.dart';
import '../screens/video_playback_screen.dart';
import '../utils/constants.dart';
import '../widgets/reclim_app_bar.dart';
import '../widgets/upload_status_indicator.dart';

class HomeTabScreen extends ConsumerWidget {
  const HomeTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(userStatsProvider);
    final recentAsync = ref.watch(recentRecordsProvider);
    final gymsAsync = ref.watch(recentGymsProvider);

    return Scaffold(
      appBar: const ReclimAppBar(),
      body: RefreshIndicator(
        color: ReclimColors.accent,
        onRefresh: () async {
          ref.invalidate(userStatsProvider);
          ref.invalidate(recentRecordsProvider);
          ref.invalidate(recentGymsProvider);
          ref.invalidate(weeklySettingSchedulesProvider);
          // 최근 암장 액티브 유저 수 갱신
          final gyms = ref.read(recentGymsProvider).valueOrNull ?? [];
          for (final gym in gyms) {
            if (gym.id != null) {
              ref.invalidate(gymCrowdednessProvider(gym.id!));
            }
          }
        },
        child: CustomScrollView(
          slivers: [
            // [1] 히어로 통계 카드
            SliverToBoxAdapter(
              child: statsAsync.when(
                data: (stats) => _HeroStatsCard(stats: stats),
                loading: () => const SizedBox(
                  height: 260,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('통계를 불러올 수 없습니다'),
                ),
              ),
            ),

            // [2] 퀵 액션 (촬영 + 최근 암장)
            SliverToBoxAdapter(
              child: _QuickActions(
                gyms: gymsAsync.valueOrNull ?? [],
              ),
            ),

            // [3] 이번 주 세팅일정
            SliverToBoxAdapter(
              child: ref.watch(weeklySettingSchedulesProvider).whenOrNull(
                        data: (entries) => entries.isNotEmpty
                            ? _WeeklySettingSection(entries: entries)
                            : null,
                      ) ??
                  const SizedBox.shrink(),
            ),

            // [4] 최근 기록 헤더
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 12, 0),
                child: Row(
                  children: [
                    const Text(
                      '최근 기록',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: ReclimColors.textPrimary,
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
                                        .state = 1;
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '더보기',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: ReclimColors.accent,
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 18,
                                        color: ReclimColors.accent,
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

            // [5] 최근 기록 그리드
            recentAsync.when(
              data: (records) {
                if (records.isEmpty) {
                  return SliverToBoxAdapter(child: _EmptyRecords());
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.78,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _RecordGridCard(record: records[i]),
                      childCount: records.length,
                    ),
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
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

// ─── [1] 히어로 통계 카드 ─────────────────────────────────────────────────────

class _HeroStatsCard extends ConsumerWidget {
  final UserClimbingStats stats;
  const _HeroStatsCard({required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completionPct = stats.completionRate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final dayLabels = ['월', '화', '수', '목', '금', '토', '일'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ReclimColors.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // 스트릭 + 기간
            Row(
              children: [
                if (stats.currentStreak > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ReclimColors.accent.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          size: 14,
                          color: ReclimColors.accentLight,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${stats.currentStreak}일 연속',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: ReclimColors.accentLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  '최근 30일',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 원형 프로그레스 + 좌우 수치
            Row(
              children: [
                // 완등 수치
                Expanded(
                  child: _StatColumn(
                    value: '${stats.totalCompleted}',
                    label: '완등',
                    color: ReclimColors.success,
                  ),
                ),

                // 원형 완등률
                SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 88,
                        height: 88,
                        child: CircularProgressIndicator(
                          value: stats.totalClimbs > 0
                              ? stats.totalCompleted / stats.totalClimbs
                              : 0,
                          strokeWidth: 7,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            ReclimColors.success,
                          ),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${completionPct.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '완등률',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 도전중 수치
                Expanded(
                  child: _StatColumn(
                    value: '${stats.totalInProgress}',
                    label: '도전중',
                    color: ReclimColors.inProgress,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 주간 히트맵 (통합)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (i) {
                  final day = monday.add(Duration(days: i));
                  final isToday = day.isAtSameMomentAs(today);
                  final isFuture = day.isAfter(today);

                  return ref.watch(recordsByDateProvider(day)).when(
                        data: (records) => _HeatmapDot(
                          label: dayLabels[i],
                          hasRecord: records.isNotEmpty,
                          isToday: isToday,
                          isFuture: isFuture,
                        ),
                        loading: () => _HeatmapDot(
                          label: dayLabels[i],
                          hasRecord: false,
                          isToday: isToday,
                          isFuture: isFuture,
                        ),
                        error: (_, __) => _HeatmapDot(
                          label: dayLabels[i],
                          hasRecord: false,
                          isToday: isToday,
                          isFuture: isFuture,
                        ),
                      );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatColumn({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
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
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeatmapDot extends StatelessWidget {
  final String label;
  final bool hasRecord;
  final bool isToday;
  final bool isFuture;
  const _HeatmapDot({
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
                ? ReclimColors.accentLight
                : Colors.white.withOpacity(0.4),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasRecord
                ? ReclimColors.success
                : isFuture
                    ? Colors.transparent
                    : Colors.white.withOpacity(0.08),
            border: isToday && !hasRecord
                ? Border.all(
                    color: ReclimColors.accentLight.withOpacity(0.6),
                    width: 1.5)
                : null,
          ),
          child: hasRecord
              ? const Icon(Icons.check_rounded,
                  size: 14, color: Colors.white)
              : null,
        ),
      ],
    );
  }
}

// ─── [2] 퀵 액션 ─────────────────────────────────────────────────────────────

class _QuickActions extends ConsumerWidget {
  final List<ClimbingGym> gyms;
  const _QuickActions({required this.gyms});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // 촬영 CTA
          GestureDetector(
            onTap: () {
              ref.read(bottomNavIndexProvider.notifier).state = 2;
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: ReclimColors.accent,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_rounded,
                      size: 18, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    '촬영하기',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 최근 암장 칩들
          ...gyms.map((gym) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _RecentGymChip(gym: gym),
              )),
        ],
      ),
    );
  }
}

class _RecentGymChip extends ConsumerWidget {
  final ClimbingGym gym;
  const _RecentGymChip({required this.gym});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GymDetailScreen(gym: gym),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: ReclimColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 15,
              color: ReclimColors.accent,
            ),
            const SizedBox(width: 4),
            Text(
              gym.name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: ReclimColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── [3] 이번 주 세팅일정 ─────────────────────────────────────────────────────

class _WeeklySettingSection extends ConsumerWidget {
  final List<
      ({
        GymSettingSchedule schedule,
        List<SettingSector> sectors,
        String dateStr,
      })> entries;
  const _WeeklySettingSection({required this.entries});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Row(
              children: [
                const Text(
                  '이번 주 세팅일정',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: ReclimColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: const Text(
                          '세팅일정 안내',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        content: const Text(
                          'Beta 기능이에요. 일정이 정확하지 않을 수 있으니 참고만 해주세요.',
                          style: TextStyle(fontSize: 14, height: 1.5),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('확인'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.help_rounded,
                    size: 18,
                    color: Colors.orange,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    ref.read(bottomNavIndexProvider.notifier).state = 3;
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '더보기',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: ReclimColors.accent,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: ReclimColors.accent,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ...entries.map((entry) => _WeeklySettingCard(
                gymId: entry.schedule.gymId,
                gymName: entry.schedule.gymName ?? '',
                sectors: entry.sectors,
                dateStr: entry.dateStr,
              )),
        ],
      ),
    );
  }
}

class _WeeklySettingCard extends StatelessWidget {
  final String gymId;
  final String gymName;
  final List<SettingSector> sectors;
  final String dateStr;
  const _WeeklySettingCard({
    required this.gymId,
    required this.gymName,
    required this.sectors,
    required this.dateStr,
  });

  String _formatDate(String dateStr) {
    final date = DateTime.parse(dateStr);
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${date.month}/${date.day} (${weekdays[date.weekday - 1]})';
  }

  bool _isToday(String dateStr) {
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return dateStr == today;
  }

  @override
  Widget build(BuildContext context) {
    final sectorNames = sectors.map((s) => s.name).join(', ');
    final isToday = _isToday(dateStr);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GymDetailScreen(
              gym: ClimbingGym(id: gymId, name: gymName),
            ),
          ),
        );
      },
      child: Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isToday
              ? ReclimColors.accent.withOpacity(0.4)
              : ReclimColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isToday
                  ? ReclimColors.accent.withOpacity(0.1)
                  : ReclimColors.border.withOpacity(0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _formatDate(dateStr),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isToday
                    ? ReclimColors.accent
                    : ReclimColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gymName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ReclimColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$sectorNames 세팅',
                  style: const TextStyle(
                    fontSize: 12,
                    color: ReclimColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}

// ─── [4] 기록 그리드 카드 ─────────────────────────────────────────────────────

class _RecordGridCard extends StatelessWidget {
  final ClimbingRecord record;
  const _RecordGridCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final diffColor = DifficultyColor.values.firstWhere(
      (c) => c.name == record.difficultyColor,
      orElse: () => DifficultyColor.white,
    );
    final baseColor = Color(diffColor.colorValue);
    final isCompleted = record.status == 'completed';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecordSaveScreen(existingRecord: record),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ReclimColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 썸네일 영역
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildThumbnail(diffColor),
                  // 상태 뱃지 (좌상단)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? ReclimColors.success
                            : ReclimColors.inProgress,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isCompleted ? '완등' : '도전중',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // 날짜 (우상단)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _formatRecordedAt(record.recordedAt),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // 재생 버튼 (우하단)
                  if (record.videoPath != null)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: GestureDetector(
                        onTap: () {
                          final path = record.videoPath!;
                          if (path.startsWith('/') &&
                              !File(path).existsSync()) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('영상 파일을 찾을 수 없습니다'),
                              ),
                            );
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  VideoPlaybackScreen(videoPath: path),
                            ),
                          );
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  // 클라우드 업로드 상태 (좌하단 영상길이 옆)
                  if (record.id != null)
                    Positioned(
                      left: 2,
                      top: 36,
                      child: UploadStatusIndicator(
                        recordId: record.id!,
                        isLocalVideo: record.isLocalVideo,
                        localOnly: record.localOnly,
                      ),
                    ),
                  // 영상 길이 (좌하단)
                  if (record.videoDurationSeconds != null)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatDuration(record.videoDurationSeconds!),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 하단 메타 정보
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 난이도 컬러 + 암장명
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: diffColor == DifficultyColor.rainbow
                              ? null
                              : baseColor,
                          gradient: diffColor == DifficultyColor.rainbow
                              ? const LinearGradient(colors: [
                                  Colors.red,
                                  Colors.orange,
                                  Colors.yellow,
                                  Colors.green,
                                  Colors.blue,
                                ])
                              : null,
                          shape: BoxShape.circle,
                          border: diffColor.needsDarkIcon
                              ? Border.all(
                                  color: const Color(0xFFE0E0E0),
                                  width: 0.5)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          record.gymName ?? '암장 미지정',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: ReclimColors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${diffColor.korean} · ${record.grade}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: ReclimColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(DifficultyColor diffColor) {
    final path = record.thumbnailPath;
    final baseColor = Color(diffColor.colorValue);

    Widget fallback() {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              baseColor.withOpacity(0.8),
              baseColor.withOpacity(0.5),
            ],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.terrain_rounded,
            size: 36,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
      );
    }

    if (path == null) return fallback();

    final isLocal = path.startsWith('/');
    if (isLocal && !File(path).existsSync()) return fallback();

    return isLocal
        ? Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback(),
          )
        : FutureBuilder<String>(
            future: R2Config.getPresignedUrl(path),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return fallback();
              return Image.network(
                snapshot.data!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback(),
              );
            },
          );
  }

  String _formatRecordedAt(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final recordDate = DateTime(date.year, date.month, date.day);
    final diff = today.difference(recordDate).inDays;
    if (diff == 0) return '오늘';
    if (diff == 1) return '어제';
    if (diff < 7) return '$diff일 전';
    return '${date.month}/${date.day}';
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

// ─── 빈 상태 ──────────────────────────────────────────────────────────────────

class _EmptyRecords extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: ReclimColors.accent.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.terrain_outlined,
                size: 36,
                color: ReclimColors.accent.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '아직 기록이 없어요',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: ReclimColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '첫 등반을 기록해보세요!',
              style: TextStyle(
                fontSize: 13,
                color: ReclimColors.textTertiary,
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
    );
  }
}
