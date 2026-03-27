---
name: climbing-product
description: "리클림 앱의 클라이밍 도메인 기능 개발 스킬. 새 기능 추가, 모델/프로바이더/스크린 생성, DB 스키마 변경 등 프로덕트 개발 전반을 체계적으로 수행한다."
---

# Climbing Product — 리클림 프로덕트 개발 스킬

## Overview

리클림(Reclim) 앱의 클라이밍 도메인 기능을 개발하는 스킬. 도메인 지식과 프로젝트 아키텍처를 결합하여 일관된 코드를 생성한다.

**Announce at start:** "climbing-product 스킬을 사용합니다."

## 클라이밍 도메인 지식

### 핵심 개념

| 용어 | 설명 | 코드 위치 |
|------|------|----------|
| **볼더링(Bouldering)** | 로프 없이 하는 실내 클라이밍. 이 앱의 주요 대상 | - |
| **등급(Grade)** | V-스케일 난이도. Vbbbbb(펭수)~V16 | `lib/utils/constants.dart` → `ClimbingGrade` |
| **난이도 색상** | 홀드/벽 색상으로 난이도 표시. 암장마다 다름 | `lib/utils/constants.dart` → `DifficultyColor` |
| **컬러스케일** | 암장별 색상→등급 매핑 커스텀 테이블 | `lib/models/gym_color_scale.dart` |
| **완등/도전중** | 루트 완등 여부 (completed/inProgress) | `ClimbingStatus` enum |
| **세팅(Setting)** | 암장이 홀드를 교체하는 것. 주기적으로 진행 | `lib/models/gym_setting_schedule.dart` |
| **섹터(Sector)** | 암장 내 벽 영역. 섹터별로 세팅 날짜가 다름 | `SettingSector` 클래스 |
| **기록(Record)** | 클라이밍 시도 1건 = 영상 + 등급 + 상태 + 메모 | `lib/models/climbing_record.dart` |
| **암장(Gym)** | 실내 클라이밍 시설 | `lib/models/climbing_gym.dart` |

### DB 테이블 구조 (Supabase PostgreSQL)

- `climbing_gyms` — 암장 정보 (name, address, lat/lng, google_place_id, brand_name, instagram_url)
- `climbing_records` — 클라이밍 기록 (user_id, gym_id, grade, difficulty_color, status, video_path, tags, memo, recorded_at)
- `gym_color_scales` — 암장별 색상-등급 매핑
- `gym_setting_schedules` — 암장 세팅일정 (gym_id, year_month, sectors JSONB, status)
- `user_subscriptions` — 유저 구독 상태
- 모든 테이블에 RLS 적용. `user_id = auth.uid()` 기반 격리

### 데이터 흐름

```
사용자 액션 → Screen (ConsumerWidget)
    → Provider (StateNotifierProvider / FutureProvider.family)
    → Supabase Client (supabase_flutter)
    → PostgreSQL (RLS) / Edge Functions → R2
```

## 기능 개발 프로세스

### Step 1: 요구사항 분석

사용자의 기능 요청을 받으면:
1. 관련 도메인 개념 파악 (위 테이블 참고)
2. 영향받는 기존 코드 탐색 (`lib/models/`, `lib/providers/`, `lib/screens/`)
3. DB 스키마 변경 필요 여부 확인 (`supabase/migrations/`)
4. 사용자에게 구현 범위 확인 질문 (한 번에 하나씩)

### Step 2: 스키마 변경 (필요 시)

```bash
# 마이그레이션 파일 생성 규칙
supabase/migrations/NNN_<description>.sql
# NNN = 기존 최대 번호 + 1 (ls supabase/migrations/ 로 확인)
```

**마이그레이션 작성 규칙:**
- RLS 정책 반드시 포함 (`enable row level security`)
- `user_id` 컬럼이 있으면 `auth.uid()` 기반 RLS 정책
- 기존 데이터 마이그레이션 고려
- `created_at`, `updated_at` 컬럼은 `timestamptz default now()`
- `id` 컬럼은 `uuid default gen_random_uuid() primary key`

### Step 3: 모델 생성/수정

**모델 파일 규칙** (`lib/models/`):
- `fromMap` factory constructor (Supabase JSON → Dart)
- `toInsertMap()` 메서드 (Dart → Supabase insert용)
- JOIN 결과 처리 시 중첩 Map에서 추출 (예: `map['climbing_gyms']['name']`)
- nullable 필드는 `?` 타입 + `toInsertMap`에서 `if (field != null)` 조건부 포함
- `copyWith` 메서드는 필요할 때만 추가
- `DateTime`은 `.toLocal()` 변환 (Supabase UTC → 로컬)
- `recorded_at` 같은 날짜 필드는 `.split('T')[0]`으로 날짜만 저장

### Step 4: Provider 생성/수정

**Provider 규칙** (`lib/providers/`):
- CRUD 로직이 있으면 `StateNotifierProvider` + `StateNotifier<AsyncValue<T>>`
- 조회 전용이면 `FutureProvider.family` (파라미터: 날짜, gymId 등)
- 단순 상태면 `StateProvider`
- 인증 변경 시 관련 provider `ref.invalidate()` 호출 (auth_provider에서)
- Supabase 쿼리에서 JOIN: `.select('*, climbing_gyms(name)')` 패턴
- 에러 처리: `AsyncValue.guard(() async { ... })`

### Step 5: Screen 생성/수정

**Screen 규칙** (`lib/screens/`):
- `ConsumerWidget` 또는 `ConsumerStatefulWidget` 사용
- 네비게이션: `Navigator.of(context).push(PageRouteBuilder(...))`
- 탭 화면은 `MainShellScreen`의 `IndexedStack`에 등록
- 한국어 하드코딩 (i18n 없음)
- 카드/컨테이너 배경: `Color(0xFFF0F0F0)` 또는 `Colors.white` — **Material colorScheme 배경색 사용 금지**
- 로딩: `AsyncValue.when(data:, loading:, error:)` 패턴
- 빈 상태(empty state) 반드시 처리

### Step 6: 검증

```bash
flutter analyze   # 린트 통과 확인
flutter test      # 기존 테스트 깨지지 않는지 확인
```

## 기능별 체크리스트

### 새 기록 관련 기능
- [ ] `ClimbingRecord` 모델 필드 추가/수정
- [ ] `record_provider.dart` CRUD 로직 반영
- [ ] 기록 저장 화면 (`record_save_screen.dart`) UI 수정
- [ ] 기록 상세 화면 (`record_detail_screen.dart`) 표시 반영
- [ ] 통계 영향 확인 (`stats_provider.dart`, `gym_stats_provider.dart`)
- [ ] DB 마이그레이션 필요 여부

### 새 암장 관련 기능
- [ ] `ClimbingGym` 모델 필드 추가/수정
- [ ] `gym_provider.dart` 로직 반영
- [ ] 암장 상세 화면 (`gym_detail_screen.dart`) UI 수정
- [ ] 지도 탭 영향 확인 (`map_tab_screen.dart`)
- [ ] 컬러스케일 영향 확인 (`gym_color_scale_provider.dart`)
- [ ] DB 마이그레이션 필요 여부

### 세팅일정 관련 기능
- [ ] `GymSettingSchedule` / `SettingSector` 모델 수정
- [ ] `setting_schedule_provider.dart` 로직 반영
- [ ] 세팅일정 탭/상세/제출 화면 수정
- [ ] DB 마이그레이션 필요 여부

### 영상 관련 기능
- [ ] `video_editor_provider.dart` 상태 관리
- [ ] `ffmpeg_command_builder.dart` 명령어 수정
- [ ] `video_export_service.dart` 내보내기 로직
- [ ] `video_upload_service.dart` 업로드 로직
- [ ] 에디터 위젯 (`lib/widgets/editor/`) 수정
- [ ] R2 Edge Function (`supabase/functions/r2/`) 영향 확인

### 통계 관련 기능
- [ ] `stats_provider.dart` (개인 통계) 또는 `gym_stats_provider.dart` (암장 통계)
- [ ] 통계 모델 (`user_climbing_stats.dart`, `gym_stats.dart`) 수정
- [ ] 통계 탭 화면 (`stats_tab_screen.dart`) UI 반영
- [ ] DB 쿼리/집계 로직 확인

## Key Principles

1. **도메인 용어 일관성** — 코드와 UI 모두 위 도메인 용어 사용
2. **기존 패턴 따르기** — 새 코드는 기존 코드의 패턴을 그대로 따름
3. **최소 변경** — 요청된 기능만 구현, 주변 리팩터링 금지
4. **RLS 필수** — 새 테이블은 반드시 RLS 정책 포함
5. **한국어 UI** — 모든 사용자 대면 텍스트는 한국어
6. **오프라인 고려** — `localOnly` 플래그와 로컬 저장 패턴 인지

## 프로덕트 아이디어 백로그

### 현재 앱 강점

개인 클라이밍 트래킹(기록, 영상, 통계)과 영상 편집이 매우 잘 갖춰져 있음. 암장 관리/세팅일정/컬러스케일도 완성도가 높음. 아래 아이디어는 이 토대 위에 쌓을 수 있는 확장 방향.

---

### Tier 1: 소셜 & 커뮤니티 (네트워크 효과 → 리텐션 핵심)

현재 소셜 기능이 전무하므로, 가장 큰 성장 레버.

| # | 아이디어 | 설명 | 필요 작업 |
|---|---------|------|----------|
| 1-1 | **친구/팔로우 시스템** | 다른 클라이머를 팔로우하고 활동을 볼 수 있음 | `user_follows` 테이블, 팔로우 Provider, 프로필 화면 확장 |
| 1-2 | **피드/타임라인** | 팔로우한 사람들의 최근 등반 기록 피드 | `feed_provider`, 피드 화면, 좋아요/응원 기능 |
| 1-3 | **암장 리더보드** | 주간/월간 암장별 완등 수, 최고 등급 랭킹 | `gym_leaderboard` 뷰 또는 Edge Function, 랭킹 UI |
| 1-4 | **영상 공유** | 촬영 영상을 인스타/틱톡에 앱 워터마크 포함 공유 | `share_plus` 패키지, 워터마크 FFmpeg 오버레이, 공유 시트 |
| 1-5 | **공개 프로필** | 방문 암장, 통계 요약, 대표 영상이 보이는 프로필 | 프로필 화면 확장, 공개/비공개 설정 |

### Tier 2: 동기부여 & 게임화

| # | 아이디어 | 설명 | 필요 작업 |
|---|---------|------|----------|
| 2-1 | **챌린지 시스템** | "이번 주 빨강 3개 완등", "한 달간 5개 암장 방문" 등 미션 | `challenges` 테이블, 챌린지 Provider/화면, 진행률 트래킹 |
| 2-2 | **업적/뱃지** | 마일스톤 달성 시 뱃지 부여 (첫 완등, 100회, 연속 7일 등) | `user_achievements` 테이블, 뱃지 아이콘, 프로필 표시 |
| 2-3 | **목표 설정** | "이번 달 V4 완등하기" 같은 개인 목표 + 진행률 | `user_goals` 테이블, 홈 화면 위젯, 달성 알림 |
| 2-4 | **연속 기록 (스트릭)** | N일 연속 클라이밍 기록 시 스트릭 카운터 표시 | 기존 데이터 기반 계산, 홈/프로필에 표시 |
| 2-5 | **시즌 랭킹** | 월별/분기별 시즌제 랭킹. 시즌 종료 시 보상(뱃지) | 시즌 관리 로직, 랭킹 집계 Edge Function |

### Tier 3: 스마트 분석 & AI

| # | 아이디어 | 설명 | 필요 작업 |
|---|---------|------|----------|
| 3-1 | **등급 추천** | 최근 완등 패턴 기반 "다음에 도전할 등급" 추천 | 통계 분석 로직, 홈 위젯 |
| 3-2 | **정체기 감지** | 같은 등급에서 오래 머무르면 알림 + 팁 제공 | 기록 분석, 알림 Provider |
| 3-3 | **약점 분석** | 색상/등급별 완등률 분석 → "파랑 벽에 약하다" 인사이트 | 통계 확장, 분석 화면 |
| 3-4 | **영상 비교 (Before/After)** | 같은 루트 과거 vs 현재 영상 나란히 비교 | `video_compare_screen.dart` 확장 (이미 기본 존재) |
| 3-5 | **AI 폼 분석** | 영상에서 자세 분석, 개선 포인트 제안 | 외부 AI API 또는 on-device ML, 분석 결과 오버레이 |

### Tier 4: 암장 연동 & B2B

| # | 아이디어 | 설명 | 필요 작업 |
|---|---------|------|----------|
| 4-1 | **암장 공식 세팅 연동** | 암장이 직접 세팅일정 등록하는 관리자 도구 | 암장 관리자 인증, 관리 대시보드, 승인 프로세스 간소화 |
| 4-2 | **암장 혼잡도** | 현재 시간대 암장 이용자 수 표시 (이미 기초 데이터 있음) | `gym_stats_provider` 실시간 확장, 지도 탭 표시 |
| 4-3 | **암장 리뷰/평점** | 암장에 별점과 후기 남기기 | `gym_reviews` 테이블, 리뷰 UI, 평균 별점 |
| 4-4 | **암장 이벤트** | 암장에서 진행하는 대회/이벤트 정보 노출 | `gym_events` 테이블, 이벤트 리스트 화면 |
| 4-5 | **암장 쿠폰/제휴** | 앱 내 암장 할인 쿠폰 제공 (B2B 수익 모델) | 쿠폰 시스템, 암장 파트너 관리 |

### Tier 5: 콘텐츠 & 미디어

| # | 아이디어 | 설명 | 필요 작업 |
|---|---------|------|----------|
| 5-1 | **인기 영상 피드** | 전체 사용자 중 인기 완등 영상 피드 (공개 동의한 것만) | 공개 설정, 좋아요/조회수, 트렌딩 알고리즘 |
| 5-2 | **루트 베타 영상** | 특정 암장+섹터+색상에 대한 공략 영상 모음 | 루트 태깅 체계, 검색/필터 |
| 5-3 | **하이라이트 릴** | 월간/주간 베스트 영상 자동 편집 릴 생성 | FFmpeg 자동 편집, 템플릿 시스템 |
| 5-4 | **영상 슬로모션 분석** | 핵심 동작 구간 자동 슬로모션 적용 | 모션 감지 또는 수동 마커, FFmpeg 속도 조절 |
| 5-5 | **운동 일지** | 클라이밍 외 보조 운동(매달리기, 캠퍼스보드 등) 기록 | `training_logs` 테이블, 운동 종류 enum, 통계 통합 |

### Tier 6: 편의 기능

| # | 아이디어 | 설명 | 필요 작업 |
|---|---------|------|----------|
| 6-1 | **푸시 알림** | 세팅일정 알림, 친구 활동, 목표 리마인더 | FCM 연동, `notifications` 테이블, 알림 설정 화면 |
| 6-2 | **위젯 (iOS/Android)** | 홈 화면 위젯에 이번 주 기록 요약, 스트릭 표시 | `home_widget` 패키지, 위젯 Provider |
| 6-3 | **Apple Watch / Wear OS** | 간단한 기록 입력 + 타이머 | 네이티브 워치 앱, 데이터 동기화 |
| 6-4 | **오프라인 모드 강화** | 인터넷 없이도 완전한 기록/조회 가능 | 로컬 DB (Drift/Hive), 동기화 큐 |
| 6-5 | **다크 모드** | 앱 전체 다크 테마 지원 | ThemeData 다크 변형, 테마 전환 설정 |

---

### 우선순위 판단 기준

아이디어 선택 시 아래 기준으로 우선순위를 정한다:

1. **사용자 리텐션 기여도** — 매일 앱을 열게 만드는가?
2. **구현 난이도** — 기존 아키텍처로 빠르게 만들 수 있는가?
3. **차별화** — 경쟁 앱(클라이밍데이, 클온 등)에 없는 기능인가?
4. **수익 연결** — Pro 구독이나 B2B 수익과 연결되는가?

## Transition

- 기능이 복잡하면 → `brainstorming` 스킬로 전환하여 설계 먼저
- 구현 계획이 필요하면 → `writing-plans` 스킬로 전환
- UI 디자인 작업이 주이면 → `flutter-design` 스킬로 전환
- 단순 수정(필드 추가, 쿼리 변경 등)은 이 스킬 안에서 바로 완료
