# 세팅일정 (Setting Schedule) — Beta 설계

## 개요

실내 암장의 세팅(문제 갱신) 일정을 사용자 참여형으로 수집하여 앱 내 캘린더로 보여주는 기능. 사용자가 인스타그램 세팅 공지 스크린샷을 올리면 GPT Vision API가 자동 파싱하고, 모든 사용자가 세팅 일정을 캘린더에서 확인할 수 있다.

## 동기

- 암장마다 문제 갱신 날짜가 다르고, 공지는 각 암장 인스타에 올라옴
- 사용자는 자기가 다니는 암장들의 인스타를 일일이 확인해야 하는 번거로움
- 앱에서 한눈에 세팅 일정을 확인할 수 있으면 편리

## 접근 방식

**Supabase Edge Function + GPT Vision API (풀 서버 방식)**

- API 키가 서버에만 존재 (보안)
- 중복 체크/승인 로직 추가 용이
- Edge Function 2개로 구성 (parse, submit)

## 데이터 모델

```sql
gym_setting_schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gym_name TEXT NOT NULL,          -- "더클라임 신림점"
  gym_brand TEXT,                  -- "더클라임"
  year_month TEXT NOT NULL,        -- "2026-03"
  sectors JSONB NOT NULL,          -- [{name, dates}]
  source_image_url TEXT,           -- Storage 경로
  submitted_by UUID REFERENCES auth.users,
  status TEXT DEFAULT 'approved',  -- "pending" | "approved"
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

### sectors JSONB 구조

```json
[
  {"name": "MILKYWAY", "dates": ["2026-03-03"]},
  {"name": "GALAXY", "dates": ["2026-03-09", "2026-03-10"]},
  {"name": "BALANCE", "dates": ["2026-03-16", "2026-03-17"]},
  {"name": "ANDROMEDA", "dates": ["2026-03-23", "2026-03-24"]}
]
```

### 설계 결정

- 암장 단위로 월별 1레코드 (중복 제보 시 업데이트)
- sectors를 JSONB → 암장마다 섹터 구조가 달라도 유연 대응
- status는 Beta에서 바로 "approved", 추후 관리자 검증 추가 가능

## Supabase Edge Functions

### 1. parse-setting-schedule

```
POST /functions/v1/parse-setting-schedule
Content-Type: multipart/form-data

Request:
  image (file) — 세팅일정 스크린샷

Response:
  {
    "gym_name": "더클라임 신림점",
    "gym_brand": "더클라임",
    "year_month": "2026-03",
    "sectors": [
      {"name": "MILKYWAY", "dates": ["2026-03-03"]},
      ...
    ]
  }
```

내부 동작: 이미지를 GPT-4o mini Vision에 전달, 프롬프트로 구조화된 JSON 추출.

### 2. submit-setting-schedule

```
POST /functions/v1/submit-setting-schedule
Content-Type: application/json

Request:
  {
    "gym_name": "더클라임 신림점",
    "gym_brand": "더클라임",
    "year_month": "2026-03",
    "sectors": [...],
    "source_image_base64": "..."
  }

Response: 저장된 레코드
```

내부 동작: 이미지를 Storage에 업로드, DB에 upsert (같은 gym_name + year_month이면 업데이트).

### GPT Vision 프롬프트

```
시스템: 실내 클라이밍장 세팅 일정 이미지를 분석하는 AI입니다.
반드시 아래 JSON 형식으로만 응답하세요.

{
  "gym_name": "암장명 (지점 포함)",
  "year_month": "YYYY-MM",
  "sectors": [
    {"name": "섹터명", "dates": ["YYYY-MM-DD", ...]}
  ]
}

- 이미지에서 암장 이름, 월, 섹터별 세팅 날짜를 추출하세요
- 색상으로 구분된 섹터는 색상-섹터 매칭을 시도하세요
- 확실하지 않은 정보는 빈 값으로 남겨주세요
```

## 데이터 모델 — 기여자 테이블

```sql
setting_schedule_contributors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  schedule_id UUID NOT NULL REFERENCES gym_setting_schedules ON DELETE CASCADE,
  contributed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, schedule_id)
);
```

- 세팅일정을 등록/업데이트한 사용자를 기록
- 추후 보상 시스템에 활용
- gym_setting_schedules.submitted_by는 최종 수정자, contributors는 기여한 모든 사용자

## 앱 UI

### 네비게이션

하단 탭에 "세팅일정" 메뉴 추가, Beta 뱃지 표시.

### 세팅일정 탭 화면

```
┌─────────────────────────┐
│  세팅일정  Beta          │
├─────────────────────────┤
│  🔍 암장 검색...         │  ← Google Places 검색
├─────────────────────────┤
│  ◀  2026년 3월  ▶       │
│  캘린더 (dot 표시)       │
├─────────────────────────┤
│  3월 10일 (화)            │
│  ┌───────────────────┐  │
│  │ 📍 OTW 이태원      │  │
│  │ Sector A 세팅      │  │
│  │ 정보 공유자: ki님   │  │
│  └───────────────────┘  │
├─────────────────────────┤
│  [+ 세팅일정 등록하기]     │
└─────────────────────────┘
```

**암장 검색 플로우:**
1. 검색창에 암장명 입력 → Google Places API로 검색 (기존 gym_provider 재사용)
2. 암장 선택 → 해당 암장의 세팅일정 DB 조회
3. **데이터 있으면** → 캘린더에 해당 암장 일정만 필터링 표시
4. **데이터 없으면** → "아직 등록된 세팅일정이 없습니다" + `[+ 세팅일정 공유해주기]` 버튼
5. 버튼 클릭 → 세팅일정 등록 화면 (암장명 자동 입력)

**정보 공유자 표시:**
- 세팅일정 카드에 "정보 공유자: ki님" 표시
- 사용자 이메일 앞 2글자 + "님" (예: `kimhyun@gmail.com` → "ki님")
- 기여자 정보는 auth.users에서 조회

### 등록 플로우

1. FAB 버튼 탭 또는 "세팅일정 공유해주기" 탭
2. 갤러리에서 이미지 선택
3. 로딩 화면 ("AI가 일정을 분석중...")
4. 파싱 결과 확인/수정 화면
   - 암장명 (수정 가능, 검색에서 진입 시 자동 입력)
   - 월 (수정 가능)
   - 섹터별 세팅 날짜 (수정/삭제/추가 가능)
5. "등록하기" 버튼으로 제출
6. 기여자 테이블에 기록

## RLS 정책

- gym_setting_schedules: 조회(전체), 등록(인증), 수정/삭제(본인)
- setting_schedule_contributors: 조회(전체), 등록(인증, 본인만)

## 중복 처리

- 같은 gym_name + year_month 조합이 이미 있으면 기존 레코드 업데이트 (최신 제보 우선)
- 원본 이미지도 교체
- 기여자는 누적 (이전 기여자 + 새 기여자 모두 기록)

## 비용 추정

- GPT-4o mini Vision: 이미지 1장당 약 ₩10~30
- Supabase Storage: 무료 티어 1GB
- Beta 단계 하루 10건 가정 → 월 ₩3,000~9,000

## Beta 범위 외 (추후 고도화)

- RapidAPI Instagram Scraper로 자동 수집
- 관리자 승인 워크플로우
- "내 암장 세팅일 알림" 푸시
- 잘못된 정보 신고/삭제
- 오프라인 캐시
- 기여자 보상 시스템 (포인트, 뱃지 등)
