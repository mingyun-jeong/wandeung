# 클라이밍장 통계 대시보드 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 통계 페이지에 클라이밍장별 통계 탭을 추가하여 전체 유저 통계 + 내 상대 순위를 확인할 수 있게 한다.

**Architecture:** Supabase PostgreSQL function으로 서버 집계 → Riverpod FutureProvider로 호출 → stats_tab_screen에 새 탭으로 UI 렌더링. 즐겨찾기 + 검색으로 클라이밍장 선택.

**Tech Stack:** Flutter, Riverpod, Supabase RPC, fl_chart, PostgreSQL

---

### Task 1: DB Migration — `get_gym_stats` PostgreSQL Function

**Files:**
- Create: `supabase/migrations/027_gym_stats_functions.sql`

**Step 1: Write the migration SQL**

```sql
-- 클라이밍장 전체 통계 (최근 30일)
create or replace function get_gym_stats(p_gym_id uuid)
returns jsonb
language plpgsql
security definer
as $$
declare
  result jsonb;
  cutoff timestamptz := now() - interval '30 days';
begin
  select jsonb_build_object(
    'total_users', (
      select count(distinct user_id)
      from climbing_records
      where gym_id = p_gym_id
        and recorded_at >= cutoff
        and parent_record_id is null
        and deleted_at is null
    ),
    'total_climbs', (
      select count(*)
      from climbing_records
      where gym_id = p_gym_id
        and recorded_at >= cutoff
        and parent_record_id is null
        and deleted_at is null
    ),
    'avg_completion_rate', (
      select coalesce(
        round(
          count(*) filter (where status = 'completed')::numeric
          / nullif(count(*), 0) * 100,
          1
        ),
        0
      )
      from climbing_records
      where gym_id = p_gym_id
        and recorded_at >= cutoff
        and parent_record_id is null
        and deleted_at is null
    ),
    'grade_distribution', (
      select coalesce(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb)
      from (
        select
          grade,
          count(*) as count,
          round(
            count(*) filter (where status = 'completed')::numeric
            / nullif(count(*), 0) * 100,
            1
          ) as completion_rate
        from climbing_records
        where gym_id = p_gym_id
          and recorded_at >= cutoff
          and parent_record_id is null
          and deleted_at is null
        group by grade
        order by count(*) desc
      ) t
    ),
    'popular_grades', (
      select coalesce(array_agg(grade), '{}')
      from (
        select grade
        from climbing_records
        where gym_id = p_gym_id
          and recorded_at >= cutoff
          and parent_record_id is null
          and deleted_at is null
        group by grade
        order by count(*) desc
        limit 3
      ) t
    )
  ) into result;

  return result;
end;
$$;
```

**Step 2: Apply migration locally**

Run: `supabase db push` or apply via Supabase dashboard.

**Step 3: Commit**

```bash
git add supabase/migrations/027_gym_stats_functions.sql
git commit -m "feat: add get_gym_stats PostgreSQL function"
```

---

### Task 2: DB Migration — `get_my_gym_ranking` PostgreSQL Function

**Files:**
- Modify: `supabase/migrations/027_gym_stats_functions.sql` (append to same file)

**Step 1: Append ranking function to migration**

```sql
-- 내 상대 순위 (최근 30일)
create or replace function get_my_gym_ranking(p_gym_id uuid, p_user_id uuid)
returns jsonb
language plpgsql
security definer
as $$
declare
  result jsonb;
  cutoff timestamptz := now() - interval '30 days';
  my_climb_count int;
  my_completed int;
  my_rate numeric;
  my_max_grade text;
  total_users int;
  users_with_more_climbs int;
  users_with_higher_rate int;
  users_with_higher_grade int;
begin
  -- 내 기록 수 & 완등 수
  select count(*), count(*) filter (where status = 'completed')
  into my_climb_count, my_completed
  from climbing_records
  where gym_id = p_gym_id
    and user_id = p_user_id
    and recorded_at >= cutoff
    and parent_record_id is null
    and deleted_at is null;

  my_rate := case when my_climb_count > 0
    then round(my_completed::numeric / my_climb_count * 100, 1)
    else 0 end;

  -- 내 최고 등급 (grade 문자열의 숫자 부분 기준 정렬)
  select grade into my_max_grade
  from climbing_records
  where gym_id = p_gym_id
    and user_id = p_user_id
    and recorded_at >= cutoff
    and parent_record_id is null
    and deleted_at is null
    and status = 'completed'
  order by
    case grade
      when 'vBbbbb' then -4
      when 'vBbb' then -3
      when 'vBb' then -2
      when 'vB' then -1
      when 'v0' then 0
      when 'v1' then 1 when 'v2' then 2 when 'v3' then 3
      when 'v4' then 4 when 'v5' then 5 when 'v6' then 6
      when 'v7' then 7 when 'v8' then 8 when 'v9' then 9
      when 'v10' then 10 when 'v11' then 11 when 'v12' then 12
      when 'v13' then 13 when 'v14' then 14 when 'v15' then 15
      when 'v16' then 16
      else -5
    end desc
  limit 1;

  -- 전체 유저 수 (이 암장, 최근 30일)
  select count(distinct user_id) into total_users
  from climbing_records
  where gym_id = p_gym_id
    and recorded_at >= cutoff
    and parent_record_id is null
    and deleted_at is null;

  -- 나보다 기록 많은 유저 수
  select count(*) into users_with_more_climbs
  from (
    select user_id, count(*) as cnt
    from climbing_records
    where gym_id = p_gym_id
      and recorded_at >= cutoff
      and parent_record_id is null
      and deleted_at is null
    group by user_id
    having count(*) > my_climb_count
  ) t;

  -- 나보다 완등률 높은 유저 수
  select count(*) into users_with_higher_rate
  from (
    select user_id,
      round(count(*) filter (where status = 'completed')::numeric / nullif(count(*), 0) * 100, 1) as rate
    from climbing_records
    where gym_id = p_gym_id
      and recorded_at >= cutoff
      and parent_record_id is null
      and deleted_at is null
    group by user_id
    having round(count(*) filter (where status = 'completed')::numeric / nullif(count(*), 0) * 100, 1) > my_rate
  ) t;

  -- 나보다 높은 등급 완등한 유저 수
  select count(*) into users_with_higher_grade
  from (
    select distinct user_id
    from climbing_records
    where gym_id = p_gym_id
      and recorded_at >= cutoff
      and parent_record_id is null
      and deleted_at is null
      and status = 'completed'
      and case grade
        when 'vBbbbb' then -4 when 'vBbb' then -3 when 'vBb' then -2 when 'vB' then -1
        when 'v0' then 0 when 'v1' then 1 when 'v2' then 2 when 'v3' then 3
        when 'v4' then 4 when 'v5' then 5 when 'v6' then 6 when 'v7' then 7
        when 'v8' then 8 when 'v9' then 9 when 'v10' then 10 when 'v11' then 11
        when 'v12' then 12 when 'v13' then 13 when 'v14' then 14 when 'v15' then 15
        when 'v16' then 16 else -5
      end > coalesce(
        case my_max_grade
          when 'vBbbbb' then -4 when 'vBbb' then -3 when 'vBb' then -2 when 'vB' then -1
          when 'v0' then 0 when 'v1' then 1 when 'v2' then 2 when 'v3' then 3
          when 'v4' then 4 when 'v5' then 5 when 'v6' then 6 when 'v7' then 7
          when 'v8' then 8 when 'v9' then 9 when 'v10' then 10 when 'v11' then 11
          when 'v12' then 12 when 'v13' then 13 when 'v14' then 14 when 'v15' then 15
          when 'v16' then 16 else -5
        end, -5)
  ) t;

  result := jsonb_build_object(
    'my_climbs', my_climb_count,
    'my_completion_rate', my_rate,
    'climbs_percentile', case when total_users > 0
      then ceil((users_with_more_climbs + 1)::numeric / total_users * 100)
      else 0 end,
    'completion_percentile', case when total_users > 0
      then ceil((users_with_higher_rate + 1)::numeric / total_users * 100)
      else 0 end,
    'highest_grade', coalesce(my_max_grade, ''),
    'grade_percentile', case when total_users > 0
      then ceil((users_with_higher_grade + 1)::numeric / total_users * 100)
      else 0 end
  );

  return result;
end;
$$;
```

**Step 2: Commit**

```bash
git add supabase/migrations/027_gym_stats_functions.sql
git commit -m "feat: add get_my_gym_ranking PostgreSQL function"
```

---

### Task 3: Dart Models — `GymStats` and `MyGymRanking`

**Files:**
- Create: `lib/models/gym_stats.dart`

**Step 1: Write the models**

```dart
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
```

**Step 2: Commit**

```bash
git add lib/models/gym_stats.dart
git commit -m "feat: add GymStats and MyGymRanking models"
```

---

### Task 4: Provider — `gym_stats_provider.dart`

**Files:**
- Create: `lib/providers/gym_stats_provider.dart`

**Step 1: Write the providers**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';
import '../models/gym_stats.dart';
import 'auth_provider.dart';

/// 현재 선택된 클라이밍장 ID (통계 탭용)
final selectedGymForStatsProvider = StateProvider<String?>((ref) => null);

/// 클라이밍장 전체 통계 (최근 30일)
final gymStatsProvider =
    FutureProvider.family<GymStats?, String>((ref, gymId) async {
  final response = await SupabaseConfig.client.rpc(
    'get_gym_stats',
    params: {'p_gym_id': gymId},
  );
  if (response == null) return null;
  return GymStats.fromMap(response as Map<String, dynamic>);
});

/// 내 상대 순위 (최근 30일)
final myGymRankingProvider =
    FutureProvider.family<MyGymRanking?, String>((ref, gymId) async {
  final userId = ref.watch(authProvider).valueOrNull?.id;
  if (userId == null) return null;

  final response = await SupabaseConfig.client.rpc(
    'get_my_gym_ranking',
    params: {'p_gym_id': gymId, 'p_user_id': userId},
  );
  if (response == null) return null;
  return MyGymRanking.fromMap(response as Map<String, dynamic>);
});
```

**Step 2: Commit**

```bash
git add lib/providers/gym_stats_provider.dart
git commit -m "feat: add gym stats and ranking providers"
```

---

### Task 5: UI — `gym_stats_tab.dart` 위젯

**Files:**
- Create: `lib/widgets/gym_stats_tab.dart`

**Step 1: Write the gym stats tab widget**

이 위젯은 `stats_tab_screen.dart`에서 탭으로 사용된다.

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/climbing_gym.dart';
import '../models/gym_stats.dart';
import '../providers/favorite_gym_provider.dart';
import '../providers/gym_stats_provider.dart';
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
              _GymStatsContent(gymId: gymId),
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
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
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
  const _GymStatsContent({required this.gymId});

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
            const SizedBox(height: 20),
            _GradeChart(stats: stats),
            if (ranking != null) ...[
              const SizedBox(height: 20),
              _RankingCard(ranking: ranking),
            ],
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Center(child: Text('통계를 불러올 수 없습니다')),
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
              color: colorScheme.primaryContainer.withOpacity(0.3),
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
          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
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

/// 등급 분포 가로 바 차트
class _GradeChart extends StatelessWidget {
  final GymStats stats;
  const _GradeChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final grades = stats.gradeDistribution;
    if (grades.isEmpty) return const SizedBox.shrink();

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
        ...grades.map((g) => Padding(
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
                      child: LinearProgressIndicator(
                        value: maxCount > 0 ? g.count / maxCount : 0,
                        minHeight: 18,
                        backgroundColor:
                            colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation(
                            colorScheme.primary.withOpacity(0.7)),
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
            )),
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
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
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
```

**Step 2: Commit**

```bash
git add lib/widgets/gym_stats_tab.dart
git commit -m "feat: add GymStatsTab widget with summary, chart, and ranking"
```

---

### Task 6: UI — `stats_tab_screen.dart`에 탭 통합

**Files:**
- Modify: `lib/screens/stats_tab_screen.dart`

**Step 1: stats_tab_screen을 TabBar 구조로 변경**

`StatsTabScreen`을 `ConsumerStatefulWidget`으로 변경하고, `TabController`를 추가한다.

현재 `StatsTabScreen`은 `ConsumerWidget`이고 `Scaffold` → `CustomScrollView` 구조이다. 이것을 감싸는 `DefaultTabController` + `TabBar` 구조로 바꾼다.

변경 내용:
1. import 추가: `import '../widgets/gym_stats_tab.dart';`
2. `StatsTabScreen`을 `ConsumerStatefulWidget`으로 변경하고 `SingleTickerProviderStateMixin` 추가
3. `AppBar`에 `TabBar` 추가: `['내 통계', '암장 통계']`
4. `body`를 `TabBarView`로 감싸서 기존 내용은 첫 번째 탭, `GymStatsTab()`은 두 번째 탭

기존 body 내용 (`RefreshIndicator` → `CustomScrollView`)을 별도 메서드 `_buildMyStatsTab()`으로 추출하여 `TabBarView`의 첫 번째 child로 넣는다.

**Step 2: Run analyze**

Run: `cd wandeung && flutter analyze`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/screens/stats_tab_screen.dart
git commit -m "feat: integrate gym stats tab into stats screen"
```

---

### Task 7: 테스트 — 모델 파싱 테스트

**Files:**
- Create: `test/gym_stats_test.dart`

**Step 1: Write model parsing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wandeung/models/gym_stats.dart';

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
```

**Step 2: Run tests**

Run: `cd wandeung && flutter test test/gym_stats_test.dart`
Expected: All tests pass

**Step 3: Commit**

```bash
git add test/gym_stats_test.dart
git commit -m "test: add GymStats and MyGymRanking model parsing tests"
```

---

### Task 8: 최종 검증

**Step 1: Run full lint**

Run: `cd wandeung && flutter analyze`
Expected: No errors

**Step 2: Run all tests**

Run: `cd wandeung && flutter test`
Expected: All tests pass

**Step 3: Final commit (if any fixes needed)**

```bash
git add -A
git commit -m "fix: address lint and test issues for gym dashboard"
```
