# 클라이밍장 통계 대시보드 디자인

## 개요

일반 유저가 특정 클라이밍장의 전체 통계와 자신의 상대적 순위를 확인할 수 있는 기능. 기존 통계 페이지에 별도 탭으로 추가한다.

## 핵심 결정사항

- **사용자**: 일반 유저 (B2C)
- **데이터 범위**: 내 기록 + 익명 전체 통계 + 상대 비교 ("상위 N%")
- **기간**: 최근 30일 고정
- **가격**: 전체 무료
- **접근 경로**: stats_tab_screen에 새 탭 추가
- **클라이밍장 선택**: 즐겨찾기 목록 + 검색(기존 gym_selection_sheet 재사용)
- **프라이버시**: 완전 익명 집계 + 상대 비교 (개별 유저 데이터 노출 없음)

## 기술 접근 방식: Supabase DB Function (서버 집계)

PostgreSQL function으로 집계 로직을 만들고, 클라이언트는 결과만 받는다.

- SQL function은 `SECURITY DEFINER`로 실행하여 집계 결과만 반환
- 기존 RLS 정책 유지, 개별 유저 데이터 노출 없음
- 클라이언트 부하 없음, 데이터 커져도 안정적
- 필요 시 Materialized View로 전환 가능

## DB 설계

### PostgreSQL Function 1: `get_gym_stats(gym_id)`

최근 30일 기준 클라이밍장 전체 통계를 반환한다.

```sql
-- 반환값:
{
  total_users: int,            -- 방문 유저 수
  total_climbs: int,           -- 전체 기록 수
  avg_completion_rate: float,  -- 평균 완등률
  grade_distribution: jsonb,   -- 등급별 [{grade, count, completion_rate}]
  color_distribution: jsonb,   -- 난이도 색상별 기록 수
  popular_grades: text[]       -- 인기 등급 TOP 3
}
```

### PostgreSQL Function 2: `get_my_gym_ranking(gym_id, user_id)`

최근 30일 기준 해당 유저의 상대 순위를 반환한다.

```sql
-- 반환값:
{
  my_climbs: int,              -- 내 기록 수
  my_completion_rate: float,   -- 내 완등률
  climbs_percentile: int,      -- 기록 수 상위 N%
  completion_percentile: int,  -- 완등률 상위 N%
  highest_grade: text,         -- 내 최고 등급
  grade_percentile: int        -- 최고 등급 상위 N%
}
```

## UI 구조

### stats_tab_screen 탭 추가

- 기존 탭: 내 통계
- 새 탭: **클라이밍장 통계**

### 클라이밍장 통계 탭 레이아웃

스크롤 가능한 단일 페이지:

1. **클라이밍장 선택 영역**
   - 즐겨찾기 클라이밍장 목록 표시 (기본값: 가장 자주 간 곳)
   - 검색 아이콘 → 기존 `gym_selection_sheet` 재사용하여 전체 클라이밍장 검색/선택

2. **요약 카드 영역**
   - 방문자 수 / 전체 기록 수 / 평균 완등률
   - 내 완등률 + "상위 N%" 뱃지

3. **등급 분포 차트**
   - 가로 바 차트: 등급별 기록 수
   - 내 기록은 다른 색으로 오버레이

4. **내 순위 카드**
   - 기록 수 상위 N%
   - 완등률 상위 N%
   - 최고 등급 상위 N%

## Provider & 데이터 흐름

### 새로운 Model (2개)

- `GymStats` — totalUsers, totalClimbs, avgCompletionRate, gradeDistribution, popularGrades
- `MyGymRanking` — myClimbs, myCompletionRate, climbsPercentile, completionPercentile, highestGrade, gradePercentile

### 새로운 Provider (2개 + 1 StateProvider)

- `gymStatsProvider(gymId)` — `FutureProvider`. Supabase RPC로 `get_gym_stats` 호출
- `myGymRankingProvider(gymId)` — `FutureProvider`. Supabase RPC로 `get_my_gym_ranking` 호출
- `selectedGymForStatsProvider` — `StateProvider<String?>`. 현재 선택된 클라이밍장 ID

### 데이터 흐름

1. 유저가 클라이밍장 통계 탭 진입
2. 즐겨찾기 중 기본 클라이밍장 선택 (가장 방문 많은 곳)
3. `gymStatsProvider` + `myGymRankingProvider` 동시 호출
4. 클라이밍장 변경 시 StateProvider 업데이트 → provider 자동 갱신

### 재사용 기존 Provider

- `favoriteGymsProvider` — 즐겨찾기 목록
- `gymsProvider` — Google Places 검색
- `gym_selection_sheet` — 클라이밍장 검색 바텀시트
