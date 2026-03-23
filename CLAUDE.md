# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**리클림 (Reclim)** — Flutter 실내 클라이밍 세션 트래커. 영상 촬영/편집, 암장 관리, 통계 기능 제공.
- Bundle ID: `com.mg.cling`
- Version: `0.0.1+12`

## Common Commands

```bash
flutter pub get                # 의존성 설치
flutter analyze                # 린트 (analysis_options.yaml 기반)
flutter test                   # 전체 테스트
flutter test test/gym_stats_test.dart  # 단일 테스트 파일
flutter build apk              # Android APK 빌드
flutter build appbundle        # Android AAB (Play Store용)
flutter build ios              # iOS 빌드 (Xcode 필요)
flutter run                    # 디버그 실행
```

Supabase Edge Functions (supabase CLI 필요):
```bash
supabase functions serve       # 로컬 Edge Function 서버
supabase db push               # 마이그레이션 적용
supabase functions deploy <name>  # 개별 함수 배포
```

## Architecture

### State Management: Riverpod 2.6

- `StateNotifierProvider` — 인증, 카메라 설정, 필터 등 mutable 상태
- `FutureProvider.family` — 날짜/월/암장별 파라미터 기반 데이터 조회
- `StateProvider` — 단순 UI 상태 (탭 인덱스, 선택값)
- 인증 상태 변경 시 관련 Provider 자동 무효화

### Navigation

별도 라우팅 프레임워크 없이 `Navigator` + `PageRouteBuilder` 직접 사용.
- `MainShellScreen` — `IndexedStack` 기반 5탭 BottomNavigationBar
- 상세 화면은 push/replace로 이동

### Data Flow

```
Flutter App (Riverpod Providers)
    ↕ Supabase Client (supabase_flutter)
Supabase PostgreSQL (RLS로 유저 격리)
    ↕ Edge Functions (Deno/TypeScript)
Cloudflare R2 (영상/썸네일 저장, presigned URL 방식)
```

- **인증**: Supabase Auth — Google OAuth + Apple Sign-In
- **DB**: Supabase PostgreSQL, RLS 정책으로 사용자별 데이터 격리
- **스토리지**: Cloudflare R2 (S3 호환). `supabase/functions/r2/` Edge Function이 SigV4 presigned URL 발급
- **영상 처리**: FFmpeg (로컬 디바이스에서 트림, 속도, 크롭, 오버레이, 자막)

### Key Layers

- `lib/providers/` — 비즈니스 로직 + 상태 관리 (17개 provider)
- `lib/screens/` — 화면 위젯 (22개)
- `lib/services/` — 외부 연동 (FFmpeg 명령 빌드, 영상 업로드, 결제)
- `lib/models/` — 데이터 클래스 (climbing_record, climbing_gym 등)
- `lib/widgets/` — 재사용 UI 컴포넌트. `widgets/editor/` 하위에 비디오 에디터 전용 위젯 24개
- `lib/config/` — Supabase 초기화, R2 설정
- `lib/utils/` — 상수(등급, 색상), 캐시 유틸

### Backend (supabase/)

- `supabase/migrations/` — 27+ SQL 마이그레이션 (climbing_gyms, climbing_records, gym_setting_schedules 등)
- `supabase/functions/` — 7개 Deno Edge Function (r2, verify-purchase, delete-account 등)

## Environment

`.env` 파일 필요 (`.env.example` 참고):
- `SUPABASE_URL`, `SUPABASE_ANON_KEY`
- `GOOGLE_WEB_CLIENT_ID`, `GOOGLE_IOS_CLIENT_ID`
- `GOOGLE_MAPS_API_KEY`
- `R2_*` 관련 키 (서버 이관 예정)

## Theme

Material 3 커스텀 테마 (`lib/app.dart`):
- Primary: Accent Red `#E94560`
- Secondary: Navy
- Surface: Warm Gray
- NavigationBar: 64px 높이, 커스텀 인디케이터

## Platform-Specific Notes

- **Android**: minSdk 24, targetSdk 35, Google Services 플러그인
- **iOS**: deployment target 14.0, Automatic Signing, Google Maps는 AppDelegate.swift에서 초기화
- FFmpeg 폰트 경로: Android `/system/fonts`, iOS `/System/Library/Fonts`
