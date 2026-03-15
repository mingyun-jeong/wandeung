# 내 암장 즐겨찾기 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 사용자가 프로필 화면에서 자주 가는 암장을 즐겨찾기로 관리할 수 있도록 한다.

**Architecture:** Supabase `user_favorite_gyms` 테이블에 즐겨찾기를 저장하고, Riverpod provider로 상태를 관리한다. 프로필 화면에 "내 암장" 섹션을 추가하고, 암장 추가 시 바텀시트에서 검색 + 기록 기반 추천을 제공한다.

**Tech Stack:** Flutter, Riverpod, Supabase (Postgres + RLS), Google Places API

---

### Task 1: Supabase 마이그레이션 — `user_favorite_gyms` 테이블

**Files:**
- Create: `supabase/migrations/021_user_favorite_gyms.sql`

**Step 1: 마이그레이션 SQL 작성**

```sql
-- 사용자별 암장 즐겨찾기
CREATE TABLE user_favorite_gyms (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  gym_id UUID REFERENCES climbing_gyms(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, gym_id)
);

CREATE INDEX idx_user_favorite_gyms_user ON user_favorite_gyms(user_id);

-- RLS
ALTER TABLE user_favorite_gyms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own favorites"
  ON user_favorite_gyms FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own favorites"
  ON user_favorite_gyms FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own favorites"
  ON user_favorite_gyms FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);
```

**Step 2: Commit**

```bash
git add supabase/migrations/021_user_favorite_gyms.sql
git commit -m "feat: add user_favorite_gyms migration with RLS"
```

---

### Task 2: Favorite Gyms Provider

**Files:**
- Create: `lib/providers/favorite_gym_provider.dart`

**Step 1: Provider 작성**

`favorite_gym_provider.dart`에 세 가지를 구현:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';
import '../models/climbing_gym.dart';
import 'auth_provider.dart';

/// 현재 유저의 즐겨찾기 암장 목록
final favoriteGymsProvider = FutureProvider<List<ClimbingGym>>((ref) async {
  final userId = ref.watch(authProvider).valueOrNull?.id;
  if (userId == null) return [];

  final response = await SupabaseConfig.client
      .from('user_favorite_gyms')
      .select('gym_id, climbing_gyms(id, name, address, latitude, longitude, google_place_id, brand_name)')
      .eq('user_id', userId)
      .order('created_at', ascending: false);

  return (response as List)
      .map((e) => ClimbingGym.fromMap(e['climbing_gyms'] as Map<String, dynamic>))
      .toList();
});

/// 기록 기반 추천 암장 (방문 횟수 상위 5개, 이미 즐겨찾기된 암장 제외)
final recommendedGymsProvider = FutureProvider<List<ClimbingGym>>((ref) async {
  final userId = ref.watch(authProvider).valueOrNull?.id;
  if (userId == null) return [];

  // 즐겨찾기된 gym_id 목록
  final favorites = await ref.watch(favoriteGymsProvider.future);
  final favoriteIds = favorites.map((g) => g.id).whereType<String>().toSet();

  // 기록에서 gym_id별 방문 횟수 집계
  final response = await SupabaseConfig.client
      .from('climbing_records')
      .select('gym_id, climbing_gyms(id, name, address, latitude, longitude, google_place_id, brand_name)')
      .eq('user_id', userId)
      .isFilter('parent_record_id', null)
      .not('gym_id', 'is', null);

  final countMap = <String, int>{};
  final gymMap = <String, ClimbingGym>{};
  for (final row in response as List) {
    final gymData = row['climbing_gyms'] as Map<String, dynamic>?;
    if (gymData == null) continue;
    final gymId = gymData['id'] as String;
    if (favoriteIds.contains(gymId)) continue;
    countMap[gymId] = (countMap[gymId] ?? 0) + 1;
    gymMap.putIfAbsent(gymId, () => ClimbingGym.fromMap(gymData));
  }

  final sorted = countMap.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return sorted.take(5).map((e) => gymMap[e.key]!).toList();
});

/// 즐겨찾기 추가/삭제 서비스
class FavoriteGymService {
  static final _supabase = SupabaseConfig.client;

  static Future<void> addFavorite(String gymId) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('user_favorite_gyms').insert({
      'user_id': userId,
      'gym_id': gymId,
    });
  }

  static Future<void> removeFavorite(String gymId) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase
        .from('user_favorite_gyms')
        .delete()
        .eq('user_id', userId)
        .eq('gym_id', gymId);
  }
}
```

**Key references:**
- `lib/providers/auth_provider.dart` — `authProvider`로 현재 유저 ID watch
- `lib/config/supabase_config.dart` — `SupabaseConfig.client`
- `lib/models/climbing_gym.dart` — `ClimbingGym.fromMap()`
- `lib/providers/record_provider.dart` — 패턴 참고 (같은 `_watchUserId` 패턴)

**Step 2: Commit**

```bash
git add lib/providers/favorite_gym_provider.dart
git commit -m "feat: add favorite gyms provider and service"
```

---

### Task 3: 암장 추가 바텀시트 위젯

**Files:**
- Create: `lib/widgets/favorite_gym_sheet.dart`

**Step 1: 바텀시트 위젯 작성**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/climbing_gym.dart';
import '../providers/favorite_gym_provider.dart';
import '../providers/gym_provider.dart';
import '../providers/gym_color_scale_provider.dart';
import '../providers/record_provider.dart';

class FavoriteGymSheet extends ConsumerStatefulWidget {
  const FavoriteGymSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const FavoriteGymSheet(),
    );
  }

  @override
  ConsumerState<FavoriteGymSheet> createState() => _FavoriteGymSheetState();
}

class _FavoriteGymSheetState extends ConsumerState<FavoriteGymSheet> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final query = _searchController.text.trim();
      ref.read(searchQueryProvider.notifier).state = query;
      setState(() => _isSearching = query.isNotEmpty);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addGym(ClimbingGym gym) async {
    // gym이 DB에 없을 수 있으므로 RecordService._findOrCreateGym 패턴 사용
    final scales = await ref.read(allColorScalesProvider.future);
    final gymId = await RecordService.findOrCreateGym(gym, scales: scales);
    await FavoriteGymService.addFavorite(gymId);
    ref.invalidate(favoriteGymsProvider);
    ref.invalidate(recommendedGymsProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 드래그 핸들
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 헤더
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('암장 추가',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, letterSpacing: -0.3)),
            ),
            const SizedBox(height: 12),
            // 검색 입력
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '암장 이름으로 검색',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _isSearching
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            // 검색 결과 또는 추천 목록
            Expanded(
              child: _isSearching ? _buildSearchResults() : _buildRecommendations(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    final gyms = ref.watch(gymsProvider);
    return gyms.when(
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('검색 결과가 없습니다.', style: TextStyle(color: Colors.grey)));
        }
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (_, i) => _GymTile(gym: list[i], onTap: () => _addGym(list[i])),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('검색 실패', style: TextStyle(color: Colors.red.shade700))),
    );
  }

  Widget _buildRecommendations() {
    final recommended = ref.watch(recommendedGymsProvider);
    return recommended.when(
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('기록된 암장이 없습니다.\n검색으로 암장을 추가해보세요.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('기록에서 추천',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4))),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) => _GymTile(gym: list[i], onTap: () => _addGym(list[i])),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const SizedBox.shrink(),
    );
  }
}

class _GymTile extends StatelessWidget {
  final ClimbingGym gym;
  final VoidCallback onTap;
  const _GymTile({required this.gym, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(gym.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  if (gym.address != null)
                    Text(gym.address!, style: const TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.add_rounded, size: 20,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }
}
```

**Important:** `RecordService._findOrCreateGym`은 현재 private이다. `findOrCreateGym`으로 public static method로 노출하거나, 같은 로직을 `FavoriteGymService`에 복제해야 한다. `RecordService._findOrCreateGym`을 `findOrCreateGym`으로 이름 변경(public 전환)하는 것을 권장.

**Step 2: `RecordService._findOrCreateGym`을 public으로 전환**

`lib/providers/record_provider.dart:333` 수정:

```dart
// 변경 전
static Future<String> _findOrCreateGym(
// 변경 후
static Future<String> findOrCreateGym(
```

그리고 내부 호출부(`saveRecord`, `updateRecord`)도 `findOrCreateGym`으로 변경.

**Step 3: Commit**

```bash
git add lib/widgets/favorite_gym_sheet.dart lib/providers/record_provider.dart
git commit -m "feat: add favorite gym bottom sheet with search and recommendations"
```

---

### Task 4: 프로필 화면에 "내 암장" 섹션 추가

**Files:**
- Modify: `lib/screens/profile_screen.dart`

**Step 1: import 추가**

```dart
import '../providers/favorite_gym_provider.dart';
import '../widgets/favorite_gym_sheet.dart';
```

**Step 2: "내 암장" 섹션을 등급 뱃지와 계정 섹션 사이에 삽입**

`profile_screen.dart`의 `const SizedBox(height: 40)` (line 152) 이후, `// ── 계정 섹션 ──` (line 154) 이전에 내 암장 섹션을 삽입한다:

```dart
const SizedBox(height: 40),

// ── 내 암장 섹션 ──
_FavoriteGymsSection(),

const SizedBox(height: 24),

// ── 계정 섹션 ──
```

**Step 3: `_FavoriteGymsSection` 위젯 구현**

`profile_screen.dart` 파일 내부에 private 위젯으로 추가:

```dart
class _FavoriteGymsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final favoriteGyms = ref.watch(favoriteGymsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더: "내 암장" + 추가 버튼
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Text('내 암장',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withOpacity(0.4))),
                const Spacer(),
                GestureDetector(
                  onTap: () => FavoriteGymSheet.show(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 16,
                        color: colorScheme.onSurface.withOpacity(0.4)),
                      const SizedBox(width: 2),
                      Text('추가', style: TextStyle(fontSize: 13,
                        color: colorScheme.onSurface.withOpacity(0.4))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 즐겨찾기 목록 또는 빈 상태
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
            ),
            child: favoriteGyms.when(
              data: (gyms) {
                if (gyms.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text('자주 가는 암장을 추가해보세요',
                        style: TextStyle(fontSize: 13,
                          color: colorScheme.onSurface.withOpacity(0.3))),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (int i = 0; i < gyms.length; i++) ...[
                      _FavoriteGymTile(gym: gyms[i]),
                      if (i < gyms.length - 1)
                        Divider(height: 1, indent: 16, endIndent: 16,
                          color: colorScheme.outlineVariant.withOpacity(0.2)),
                    ],
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteGymTile extends ConsumerWidget {
  final ClimbingGym gym;
  const _FavoriteGymTile({required this.gym});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, size: 18,
            color: colorScheme.onSurface.withOpacity(0.4)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(gym.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis),
                if (gym.address != null)
                  Text(gym.address!, style: TextStyle(fontSize: 11,
                    color: colorScheme.onSurface.withOpacity(0.35)),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              if (gym.id == null) return;
              await FavoriteGymService.removeFavorite(gym.id!);
              ref.invalidate(favoriteGymsProvider);
              ref.invalidate(recommendedGymsProvider);
            },
            child: Icon(Icons.close_rounded, size: 16,
              color: colorScheme.onSurface.withOpacity(0.25)),
          ),
        ],
      ),
    );
  }
}
```

**Step 4: Commit**

```bash
git add lib/screens/profile_screen.dart
git commit -m "feat: add '내 암장' favorites section to profile screen"
```

---

### Task 5: 통합 테스트 및 정리

**Step 1: `flutter analyze` 실행**

```bash
cd wandeung && flutter analyze
```

모든 lint 에러 수정.

**Step 2: 수동 테스트 체크리스트**

- [ ] 프로필 화면에 "내 암장" 섹션이 빈 상태로 표시됨
- [ ] "추가" 버튼 탭 → 바텀시트 열림
- [ ] 바텀시트 초기 상태: 기록 기반 추천 암장 표시
- [ ] 검색어 입력 시 Google Places 검색 결과 표시
- [ ] 암장 탭 → 즐겨찾기 추가 후 시트 닫힘 → 프로필에 반영
- [ ] X 버튼 탭 → 즐겨찾기 삭제 → 프로필에서 제거
- [ ] 이미 즐겨찾기된 암장은 추천 목록에서 제외됨

**Step 3: 최종 커밋**

```bash
git add -A
git commit -m "feat: complete favorite gyms feature"
```
