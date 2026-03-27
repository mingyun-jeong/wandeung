# iOS 빌드 및 배포 가이드

> 작성일: 2026-03-20
> 번들 ID: `com.mg.cling`

---

## 현재 상태 요약

| 항목 | 상태 |
|------|------|
| Info.plist 권한 (카메라/마이크/위치) | 완료 |
| AppDelegate Google Maps 초기화 | 완료 |
| Podfile / 플러그인 등록 | 기본 셋업 완료 |
| Apple Developer 계정 & 서명 | **미설정** |
| Google Sign-In iOS 설정 | **미설정** |
| Podfile 최소 iOS 버전 | 완료 |
| Google Maps iOS API | **미활성화** |
| FFmpeg 폰트 경로 iOS 분기 | 완료 |
| R2 시크릿 키 보안 | 완료 |
| App Store Connect 등록 | 완료 |

---

## 1. Apple Developer 계정 & Xcode 서명

### 현재 상태

- `project.pbxproj`에 `DEVELOPMENT_TEAM` 미설정
- `CODE_SIGN_STYLE = Automatic` (자동 서명은 활성화됨)

### 필요한 작업

1. **Apple Developer Program 가입** — $99/년, App Store 배포 필수
2. **Apple Developer Console → Identifiers**에서 Bundle ID `com.mg.cling` 등록
3. **Xcode에서 프로젝트 열기** → Runner 타겟 → Signing & Capabilities → Team 선택
4. Xcode가 자동으로 Provisioning Profile 생성 (Automatic Signing)

### 참고

- 실 기기 테스트도 Apple Developer 계정 필요 (무료 계정은 7일 제한)
- TestFlight 배포 시에도 유료 계정 필수

---

## 2. Google Sign-In iOS 설정

현재 `auth_provider.dart`에서 `GoogleSignIn(serverClientId: webClientId)`만 사용 중.
Android에서는 이것만으로 동작하지만 **iOS에서는 추가 설정 필요**.

### 2-1. Google Cloud Console에서 iOS OAuth Client ID 생성

1. [Google Cloud Console](https://console.cloud.google.com) → APIs & Services → Credentials
2. **"Create Credentials" → "OAuth client ID"** 선택
3. Application type: **iOS**
4. Bundle ID: `com.mg.cling` 입력
5. 생성 완료 후 **iOS Client ID** 확인 (예: `123456789-xxxxx.apps.googleusercontent.com`)

### 2-2. Info.plist에 URL Scheme 추가

iOS에서 Google Sign-In OAuth 콜백을 받으려면 **reversed client ID**를 URL scheme으로 등록해야 한다.

**파일:** `ios/Runner/Info.plist`

`</dict>` 닫는 태그 바로 위에 추가:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <!-- iOS Client ID의 reversed 값 -->
      <!-- 예: 123456789-xxxxx.apps.googleusercontent.com → com.googleusercontent.apps.123456789-xxxxx -->
      <string>com.googleusercontent.apps.YOUR_IOS_CLIENT_ID</string>
    </array>
  </dict>
</array>
```

### 2-3. auth_provider.dart 코드 수정

Android에서 `clientId`를 넘기면 API Exception 10이 발생하므로 **플랫폼 분기 필수**.

```dart
import 'dart:io' show Platform;

final googleSignIn = GoogleSignIn(
  clientId: Platform.isIOS ? dotenv.env['GOOGLE_IOS_CLIENT_ID'] : null,
  serverClientId: webClientId,
);
```

### 2-4. 환경변수 추가

`.env`에 추가:

```
GOOGLE_IOS_CLIENT_ID=123456789-xxxxx.apps.googleusercontent.com
```

---

## 3. Podfile 최소 iOS 버전 설정

### 현재 상태

`ios/Podfile` 2번째 줄이 주석 처리되어 있음:

```ruby
# platform :ios, '13.0'
```

### 사용 패키지별 최소 요구 버전

| 패키지 | 최소 iOS 버전 |
|--------|-------------|
| `supabase_flutter` | 13.0 |
| `google_sign_in` | 14.0 |
| `google_maps_flutter` | 14.0 |
| `ffmpeg_kit_flutter_new` | 12.1 |
| `camera` | 12.0 |

### 필요한 변경

```ruby
platform :ios, '14.0'
```

주석 해제 후 버전을 `14.0`으로 설정.

---

## 4. Google Maps iOS API 활성화

### 현재 상태

`AppDelegate.swift`에서 `.env`의 `GOOGLE_MAPS_API_KEY`를 읽어 `GMSServices.provideAPIKey()`를 호출하는 코드는 이미 작성되어 있음.

### 필요한 작업

1. **Google Cloud Console → APIs & Services → Library**에서 **"Maps SDK for iOS"** 활성화
2. **API 키 제한 추가:**
   - Application restrictions → iOS apps
   - Bundle ID: `com.mg.cling` 등록
   - API restrictions → Maps SDK for iOS만 허용

---

## 5. FFmpeg 폰트 경로 iOS 분기

### 현재 상태

`lib/main.dart`에서 Android 전용 경로만 사용 중:

```dart
await FFmpegKitConfig.setFontDirectory('/system/fonts');
```

### 필요한 변경

```dart
import 'dart:io' show Platform;

if (Platform.isAndroid) {
  await FFmpegKitConfig.setFontDirectory('/system/fonts');
} else if (Platform.isIOS) {
  await FFmpegKitConfig.setFontDirectory('/System/Library/Fonts');
}
```

---

## 6. 환경변수 보안 (R2 시크릿 키)

### 현재 상태

`.env` 파일이 `pubspec.yaml`에서 Flutter asset으로 포함됨:

```yaml
assets:
  - .env
```

앱 번들에 `.env`가 그대로 들어가므로 IPA를 풀면 모든 키가 노출됨.

### 변수별 위험도

| 변수 | 위험도 | 이유 |
|------|--------|------|
| `SUPABASE_URL` | 낮음 | 공개 URL, RLS가 보호 |
| `SUPABASE_ANON_KEY` | 낮음 | 공개 키, RLS가 보호 |
| `GOOGLE_WEB_CLIENT_ID` | 낮음 | OAuth용 공개 ID |
| `GOOGLE_MAPS_API_KEY` | 중간 | API 키 제한으로 완화 가능 |
| **`R2_ACCESS_KEY_ID`** | **높음** | 스토리지 전체 읽기/쓰기 가능 |
| **`R2_SECRET_ACCESS_KEY`** | **높음** | 위와 동일 |

### 권장 해결 방안

R2 시크릿 키를 클라이언트에서 제거하고, 서버 사이드에서 presigned URL을 발급하는 방식으로 전환:

1. **Supabase Edge Function** 생성 — R2 presigned URL 발급 API
2. 앱에서는 Edge Function을 호출하여 presigned URL을 받아 직접 업로드
3. `.env`에서 `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` 제거
4. `r2_config.dart`의 S3v4 서명 로직을 서버로 이관

> 이 문제는 iOS뿐 아니라 Android에도 해당됨. 프로덕션 배포 전에 반드시 해결 필요.

---

## 7. App Store 배포 추가 요구사항

### App Store Connect 등록

| 항목 | 설명 |
|------|------|
| 앱 이름 | `리클림` |
| Bundle ID | `com.mg.cling` |
| 카테고리 | 건강 및 피트니스 / 스포츠 |
| 가격 | 무료 |

### 필수 제출물

| 항목 | 상태 | 상세 |
|------|------|------|
| 앱 아이콘 (1024x1024) | 확인 필요 | `flutter_launcher_icons` 설정은 있으나 iOS 생성 여부 확인 |
| 스크린샷 | **미준비** | 6.7인치(iPhone 15 Pro Max) + 5.5인치(iPhone 8 Plus) 최소 필요 |
| 개인정보 처리방침 URL | **없음** | App Store Connect 등록 시 필수 |
| 앱 심사 노트 | **미작성** | 카메라/위치 사용 사유, 테스트 계정 정보 기재 |

### 심사 주의사항

- **카메라 권한:** 실제로 영상 촬영 기능이 있으므로 문제없음
- **위치 권한:** 암장 검색 목적 — 심사 노트에 사용 시나리오 설명
- **Google 로그인:** "Sign in with Apple"도 제공해야 할 수 있음 (App Store 가이드라인 4.8)
  - 서드파티 로그인을 제공하는 앱은 **Apple 로그인도 함께 제공 필수**
  - `sign_in_with_apple` 패키지 + Supabase Apple OAuth 설정 필요

---

## 8. Apple 로그인 추가 (App Store 가이드라인 4.8)

Google 로그인을 제공하므로 **Apple 로그인도 필수**.

### 필요한 작업

1. **Apple Developer Console:**
   - Identifiers → `com.mg.cling` → Capabilities에서 "Sign In with Apple" 활성화
2. **Xcode:**
   - Runner 타겟 → Signing & Capabilities → "+ Capability" → "Sign in with Apple" 추가
3. **Supabase Dashboard:**
   - Authentication → Providers → Apple 활성화
   - Service ID, Key 등록
4. **패키지 추가:**
   ```yaml
   sign_in_with_apple: ^6.1.0
   ```
5. **코드 구현:**
   - 로그인 화면에 "Apple로 로그인" 버튼 추가
   - `AuthNotifier`에 `signInWithApple()` 메서드 추가

---

## 작업 순서 체크리스트

### Phase 1: 계정 및 외부 설정

- [ ] Apple Developer Program 가입
- [ ] Apple Developer Console에 Bundle ID 등록
- [ ] Google Cloud Console에서 iOS OAuth Client ID 생성
- [ ] Google Cloud Console에서 Maps SDK for iOS 활성화 + API 키 제한
- [x] Supabase Dashboard에서 Apple OAuth 설정

### Phase 2: 코드 수정

- [x] `Podfile` — `platform :ios, '14.0'` 설정
- [ ] `Info.plist` — URL Scheme 추가 (reversed client ID)
- [ ] `.env` — `GOOGLE_IOS_CLIENT_ID` 추가
- [ ] `auth_provider.dart` — iOS용 `clientId` 분기
- [x] `main.dart` — FFmpeg 폰트 경로 iOS 분기
- [x] Apple 로그인 구현 (sign_in_with_apple 패키지)

### Phase 3: 보안 (프로덕션 배포 전)

- [x] R2 시크릿 키를 서버 사이드(Edge Function)로 이관
- [x] 클라이언트 `.env`에서 R2 시크릿 제거

### Phase 4: App Store 제출

- [ ] Xcode에서 Team 선택 + Signing 설정
- [x] 앱 아이콘 iOS 사이즈 확인/생성
- [x] App Store Connect 앱 등록
- [x] 개인정보 처리방침 URL 준비
- [x] 스크린샷 준비 (6.7" + 5.5")
- [x] 심사 노트 작성
- [ ] `flutter build ios --release` → Xcode Archive → App Store 업로드
