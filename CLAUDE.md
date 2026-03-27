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

---

## Global Development Guidelines

모든 기능은 **Android와 iOS 모두에서 정상 동작**해야 하며, **테스트 코드가 반드시 존재하고 통과**해야 한다.

### 1. 크로스 플랫폼 필수 원칙

#### 1.1 플랫폼 분기 처리
- `Platform.isAndroid` / `Platform.isIOS` 분기가 필요한 경우, **반드시 양쪽 모두 구현**한다.
- 한쪽만 구현하고 `// TODO` 로 남기는 것을 금지한다.
- 플랫폼별 차이가 있는 기능 목록:
  - **권한 요청**: 카메라, 갤러리, 위치 (Android: `permission_handler`, iOS: Info.plist)
  - **파일 경로**: `path_provider`의 `getApplicationDocumentsDirectory()` 사용 (하드코딩 금지)
  - **FFmpeg 폰트**: Android `/system/fonts`, iOS `/System/Library/Fonts`
  - **OAuth**: Google Sign-In (clientId 분기), Apple Sign-In (iOS 네이티브 / Android 웹 기반)
  - **딥링크 / URL 스킴**: AndroidManifest.xml + Info.plist 양쪽 설정
  - **카메라**: Android와 iOS의 해상도/프리셋 차이 고려

#### 1.2 UI/UX 일관성
- Material 3 테마를 기본으로 사용하되, iOS에서 어색한 UI가 없는지 검증한다.
- `SafeArea`를 모든 최상위 화면에 적용한다 (노치, Dynamic Island 대응).
- 키보드가 올라올 때 `resizeToAvoidBottomInset` 또는 `SingleChildScrollView`로 대응한다.
- 하드코딩된 크기 대신 `MediaQuery`, `LayoutBuilder`, `Flexible/Expanded`를 사용한다.

#### 1.3 네이티브 설정 동기화
- 새 권한 추가 시: `AndroidManifest.xml` + `Info.plist` **동시에** 업데이트한다.
- 새 플러그인 추가 시: Android `build.gradle`와 iOS `Podfile` 양쪽의 호환성을 확인한다.
- `flutter pub get` 후 `cd ios && pod install` 이 정상 완료되는지 확인한다.

### 2. 테스트 필수 원칙

#### 2.1 테스트 커버리지 요구사항
- **Model 클래스**: 모든 모델의 `fromJson`, `toJson`, `copyWith`, equality 테스트 필수.
- **Provider/비즈니스 로직**: 상태 변경, 에러 처리, 엣지 케이스 테스트 필수.
- **Service 클래스**: 외부 의존성은 mock 처리하고 입출력 검증 테스트 필수.
- **Widget**: 핵심 사용자 플로우에 대한 위젯 테스트 권장.

#### 2.2 테스트 파일 구조
```
test/
├── models/              # 모델 단위 테스트
│   └── {model_name}_test.dart
├── providers/           # Provider 로직 테스트
│   └── {provider_name}_test.dart
├── services/            # 서비스 로직 테스트
│   └── {service_name}_test.dart
├── widgets/             # 위젯 테스트
│   └── {widget_name}_test.dart
└── helpers/             # 테스트 유틸리티 (mock, fixture)
    ├── mocks.dart
    └── fixtures.dart
```

#### 2.3 테스트 작성 규칙
- 파일명은 `{소스파일명}_test.dart` 형식을 따른다.
- `group()`으로 관련 테스트를 묶고, `test()` 이름은 **한글로 동작을 서술**한다.
  ```dart
  group('ClimbingRecord', () {
    test('fromJson으로 정상 파싱된다', () { ... });
    test('난이도가 null이면 기본값을 사용한다', () { ... });
  });
  ```
- Supabase, R2 등 외부 서비스 호출은 반드시 mock 처리한다.
- 테스트에서 실제 네트워크 요청을 하지 않는다.

#### 2.4 테스트 실행 기준
- 새 기능 PR 전: `flutter test` 전체 통과 필수.
- 새 모델/프로바이더/서비스 추가 시: 해당 테스트 파일도 함께 추가한다.
- 버그 수정 시: 해당 버그를 재현하는 테스트를 먼저 작성한 뒤 수정한다.

### 3. 코드 품질

#### 3.1 정적 분석
- `flutter analyze` 경고 0개를 유지한다.
- 사용하지 않는 import, 변수, 파라미터를 남기지 않는다.

#### 3.2 에러 처리
- Supabase 호출은 `try-catch`로 감싸고, 사용자에게 의미 있는 에러 메시지를 표시한다.
- 네트워크 미연결 시 `connectivity_plus`로 상태를 확인하고 적절히 안내한다.
- `catch (e)` 대신 구체적인 예외 타입을 사용한다 (불가능한 경우에만 범용 catch 허용).

#### 3.3 상태 관리 규칙
- Provider 내에서 다른 Provider를 `ref.read`로 직접 호출하지 않고, 필요시 `ref.watch` 또는 파라미터로 전달한다.
- `StateNotifier`의 상태 변경은 반드시 불변 객체를 통해 수행한다 (`state = state.copyWith(...)`).
- dispose 시 리소스(컨트롤러, 스트림 구독)를 반드시 정리한다.

### 4. 기능 개발 체크리스트

새 기능을 개발할 때 아래 항목을 모두 충족해야 한다:

- [ ] Android 에뮬레이터에서 정상 동작 확인
- [ ] iOS 시뮬레이터에서 정상 동작 확인
- [ ] 플랫폼별 권한/설정 파일 업데이트 완료
- [ ] 단위 테스트 작성 및 통과 (`flutter test`)
- [ ] 정적 분석 통과 (`flutter analyze` 경고 0개)
- [ ] SafeArea, 다양한 화면 크기 대응 확인
- [ ] 네트워크 미연결 시 크래시 없음 확인
- [ ] 메모리 누수 없음 (컨트롤러/스트림 정리 확인)
