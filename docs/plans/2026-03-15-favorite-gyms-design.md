# 내 암장 즐겨찾기 디자인

## 목적

사용자가 자주 가는 암장을 프로필에서 관리하는 기능. 본인 관리 용도.

## 데이터

### 새 테이블: `user_favorite_gyms`

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid (PK) | DEFAULT gen_random_uuid() |
| user_id | uuid (FK → auth.users) | NOT NULL |
| gym_id | uuid (FK → climbing_gyms) | NOT NULL |
| created_at | timestamptz | DEFAULT now() |

- UNIQUE 제약: `(user_id, gym_id)`
- RLS: 본인 데이터만 SELECT/INSERT/DELETE
- 인덱스: `user_id`로 조회하므로 UNIQUE 제약이 커버

## UI

### 프로필 화면 — "내 암장" 섹션

- **위치**: 등급 뱃지 아래, 계정 섹션 위
- 섹션 헤더 "내 암장" + 우측 "추가" 버튼 (+ 아이콘)
- 즐겨찾기된 암장을 리스트로 표시 (암장명 + 삭제 X 버튼)
- 비어있으면 "자주 가는 암장을 추가해보세요" 안내

### 암장 추가 바텀시트

- 상단: 검색 입력 필드 (Google Places API, 기존 gym_provider 로직 재활용)
- **검색 입력 전**: "기록에서 추천" — 과거 climbing_records에서 방문 횟수 상위 5개 암장 표시 (이미 즐겨찾기된 암장 제외)
- **검색 시**: Google Places 검색 결과 리스트
- 암장 탭 → 즐겨찾기 추가 후 시트 닫기

## Provider

- `favoriteGymsProvider` (FutureProvider): Supabase에서 본인 즐겨찾기 목록 조회, climbing_gyms JOIN
- `recommendedGymsProvider` (FutureProvider): climbing_records에서 gym_id별 카운트 → 상위 5개, 즐겨찾기 제외

## 마이그레이션

- `021_user_favorite_gyms.sql`: 테이블 생성 + RLS 정책 + UNIQUE 제약
