# 프리미엄 멤버십 & 인앱 결제 설계

## 개요

FREE/Pro 티어 기반 프리미엄 멤버십을 Android + iOS 인앱 결제로 제공한다.

## Pro 차별점

| 항목 | Free | Pro |
|------|------|-----|
| 클라우드 용량 | 500MB (현재 코드) / 3GB (설계 문서 목표) | **무제한** |
| 영상 화질 | 720p CRF 28 압축 | **1080p 원본** |
| 보관 기간 | 6개월 | 6개월 (동일) |
| 로컬 모드 | 가능 | 가능 |

## 가격

| 상품 | 가격 | Google Play 상품 ID | App Store 상품 ID |
|------|------|---------------------|-------------------|
| Pro 월간 | 1,800원/월 | `pro_monthly` | `pro_monthly` |
| Pro 연간 | 18,000원/년 (2개월 무료) | `pro_yearly` | `pro_yearly` |

---

## 출시 전략 검토: 유료 포함 출시 vs 나중에 추가

### 옵션 A: 초기 출시에 유료 포함

**장점:**
- 처음부터 수익 모델이 있으므로 앱 성장과 수익이 동시에 발생
- 무료 사용자가 "원래 있던 기능"으로 인식 → 불만 적음
- 스토어 리뷰에 "유료 전환" 관련 부정 리뷰 방지

**단점:**
- 출시 지연 (인앱 결제 구현 + 스토어 심사에 2-4주 추가)
- Google Play / App Store 인앱 결제 심사가 별도로 필요 (특히 첫 제출 시 리젝 가능성)
- 초기 사용자 확보에 "유료" 이미지가 부담될 수 있음
- 결제 관련 버그가 초기 사용자 경험을 해칠 위험

### 옵션 B: 무료로 먼저 출시, 나중에 Pro 추가

**장점:**
- 빠른 출시 → 빠른 피드백 수집
- 초기 사용자 확보에 유리 (진입 장벽 없음)
- 결제 시스템을 충분히 테스트한 후 도입 가능
- 사용 패턴 데이터를 확보한 후 가격/용량 최적화 가능

**단점:**
- 무료로 쓰던 사용자가 갑자기 제한을 경험 → 부정적 반응
- "갑자기 유료화" 스토어 리뷰 리스크
- 무료 기간 동안 이미 3GB 이상 업로드한 사용자 마이그레이션 문제

### 권장: **옵션 B (무료 먼저 출시) + 미리 설계된 티어 구조**

**이유:**
1. **현재 버전 0.0.1+13** — 아직 초기 단계. 사용자 확보가 우선
2. **인앱 결제는 스토어 심사 리스크가 높음** — 첫 출시와 결제를 동시에 심사받으면 양쪽 이슈가 겹칠 수 있음
3. **사용 데이터가 없음** — 실제 사용자의 업로드 패턴을 보고 Free 한도(500MB vs 3GB)와 가격을 조정해야 함

**단, 아래 조건을 충족하여 나중에 Pro를 자연스럽게 추가:**
- Free 한도를 처음부터 설정 (3GB 또는 500MB)
- 용량 바 UI를 처음부터 노출 ("X GB / 3 GB 사용 중")
- 한도 초과 시 "Pro로 업그레이드" 플레이스홀더 표시 (결제 미구현 시 "준비 중" 안내)
- 코드 구조는 티어 분기를 처음부터 반영 (subscriptionTierProvider 이미 존재)

이렇게 하면 사용자는 처음부터 Free/Pro 구조를 인지하고, Pro 추가 시 "갑자기 유료화"가 아닌 "예고된 기능 오픈"으로 받아들임.

---

## 기술 아키텍처

### 인앱 결제 플로우

```
[사용자]                [앱]                [스토어]            [Supabase Edge Function]
   │                    │                    │                        │
   ├─ "Pro 구독" 탭 ──→ │                    │                        │
   │                    ├─ 상품 정보 요청 ──→ │                        │
   │                    │ ←── 상품 목록 ──── │                        │
   │ ←── 상품 표시 ──── │                    │                        │
   │                    │                    │                        │
   ├─ "구매" 탭 ──────→ │                    │                        │
   │                    ├─ 구매 요청 ────── → │                        │
   │ ←── 결제 UI ────── │ ←── 구매 결과 ──── │                        │
   │                    │                    │                        │
   │                    ├─ 영수증 검증 요청 ──────────────────────── → │
   │                    │                    │   ├─ 스토어 API 검증    │
   │                    │                    │   ├─ DB upsert          │
   │                    │ ←── 검증 결과 ────────────────────────────── │
   │                    │                    │                        │
   │                    ├─ 구독 상태 갱신    │                        │
   │ ←── Pro 활성화 ─── │                    │                        │
```

### 구독 갱신/만료 처리

```
[스토어 서버]           [Supabase Edge Function]        [앱]
   │                        │                           │
   ├─ 갱신 알림 (RTDN/    │                           │
   │   Server Notification)→│                           │
   │                        ├─ 구독 상태 확인            │
   │                        ├─ DB 업데이트               │
   │                        │                           │
   │                        │   (앱 실행 시)             │
   │                        │ ←── 구독 상태 조회 ──────── │
   │                        ├─ 현재 상태 반환 ──────── → │
   │                        │                           ├─ Pro/Free 판별
```

### 패키지 선택

**`in_app_purchase` (공식 Flutter 플러그인)**
- Google Play Billing + App Store 동시 지원
- Flutter 팀 관리, 안정적
- 저수준 API → 직접 스트림 관리 필요

vs.

**`purchases_flutter` (RevenueCat SDK)**
- 서버사이드 영수증 검증을 RevenueCat이 대행
- 구독 분석 대시보드 제공
- 월 $0 (월 매출 $2,500 이하 무료)
- 벤더 종속

**권장: `in_app_purchase`**
- 이유: 이미 Supabase Edge Function(`verify-purchase`)을 직접 구현하는 구조. RevenueCat 없이도 충분
- Edge Function에서 Google Play Developer API / App Store Server API 직접 호출
- 코드 제어권이 높고, 추후 RevenueCat 전환도 가능

---

## 구현 범위

### Phase 1: Free 티어 완성 (Pro 없이 출시 가능)

이미 상당 부분 구현됨. 남은 작업:

| 작업 | 상태 | 설명 |
|------|------|------|
| `user_subscriptions` 테이블 | ✅ 완료 | migration 024 |
| `subscriptionTierProvider` | ✅ 완료 | Free/Pro 판별 |
| `cloudUsageProvider` | ✅ 완료 | 사용량 합산 |
| Free 용량 한도 결정 | ⚠️ 불일치 | 코드: 500MB, 설계: 3GB → 통일 필요 |
| 720p 압축 (Free) | ❌ 미구현 | ffmpeg_kit 설치됨, 압축 로직 필요 |
| 용량 바 UI | ❌ 미구현 | 설정 화면에 프로그레스 바 |
| 한도 초과 시 안내 | ❌ 미구현 | 업로드 차단 + "Pro 준비 중" 메시지 |

### Phase 2: 인앱 결제 연동 (Android)

| 작업 | 파일 | 설명 |
|------|------|------|
| `in_app_purchase` 패키지 추가 | `pubspec.yaml` | 의존성 추가 |
| `BillingService` 구현 | `lib/services/billing_service.dart` (신규) | 스토어 연결, 상품 조회, 구매 처리, 영수증 전달 |
| Google Play Console 상품 등록 | (콘솔 작업) | `pro_monthly`, `pro_yearly` 구독 상품 |
| `verify-purchase` Edge Function 완성 | `supabase/functions/verify-purchase/index.ts` | Google Play Developer API 연동 (현재 스텁) |
| 구독 관리 UI | `lib/screens/subscription_screen.dart` (신규) | 상품 목록, 구매 버튼, 현재 플랜 표시 |
| 업그레이드 유도 UI | 기존 화면 수정 | 용량 초과 시, 설정 화면에서 Pro 유도 |
| Google RTDN 웹훅 | `supabase/functions/google-rtdn/` (신규) | 구독 갱신/취소/만료 실시간 알림 처리 |

### Phase 3: 인앱 결제 연동 (iOS)

| 작업 | 파일 | 설명 |
|------|------|------|
| App Store Connect 상품 등록 | (콘솔 작업) | 동일 상품 ID |
| `BillingService` iOS 분기 | `lib/services/billing_service.dart` | `in_app_purchase`가 플랫폼 분기 자동 처리 |
| `verify-purchase` iOS 분기 | `supabase/functions/verify-purchase/index.ts` | App Store Server API v2 검증 추가 |
| App Store Server Notification v2 | `supabase/functions/appstore-notification/` (신규) | 구독 상태 변경 웹훅 |
| StoreKit 설정 | `ios/` Xcode 프로젝트 | In-App Purchase capability 추가 |

### Phase 4: 1080p 원본 저장 (Pro 전용)

| 작업 | 파일 | 설명 |
|------|------|------|
| 티어별 압축 분기 | `lib/services/video_upload_service.dart` | Free→720p 압축, Pro→1080p 원본 |
| `videoQuality` 필드 활용 | `lib/models/climbing_record.dart` | 저장 시 720p/1080p 기록 |
| 다운그레이드 처리 | `subscription_provider.dart` | Pro→Free 시 새 영상부터 720p |

---

## 신규/수정 파일 목록

### 신규 파일

```
lib/services/billing_service.dart          # 인앱 결제 핵심 로직
lib/screens/subscription_screen.dart       # 구독 관리 화면
lib/widgets/upgrade_prompt_widget.dart     # 업그레이드 유도 위젯 (재사용)
supabase/functions/google-rtdn/index.ts   # Google RTDN 웹훅
supabase/functions/appstore-notification/index.ts  # App Store 웹훅
```

### 수정 파일

```
pubspec.yaml                               # in_app_purchase 추가
lib/providers/subscription_provider.dart   # Free 한도 통일, 결제 상태 연동
lib/services/video_upload_service.dart     # 티어별 압축/원본 분기
lib/screens/settings_screen.dart           # 용량 바, 구독 관리 링크
supabase/functions/verify-purchase/index.ts # 스텁 → 실제 검증 구현
android/app/build.gradle                   # billing permission (자동)
ios/Runner.xcodeproj/                      # In-App Purchase capability
```

---

## BillingService 설계

```dart
class BillingService {
  static final InAppPurchase _iap = InAppPurchase.instance;

  // 초기화: 스토어 연결 + 구매 스트림 리스닝
  static Future<void> initialize();

  // 상품 목록 조회
  static Future<List<ProductDetails>> getProducts();

  // 구매 시작
  static Future<void> purchase(ProductDetails product);

  // 구매 완료 처리 (영수증 → Edge Function → DB 업데이트)
  static Future<void> _handlePurchase(PurchaseDetails purchase);

  // 구매 복원 (앱 재설치 시)
  static Future<void> restorePurchases();

  // 리소스 해제
  static void dispose();
}
```

핵심 원칙:
- 영수증 검증은 **반드시 서버사이드** (Edge Function)
- 클라이언트는 스토어에서 받은 `purchaseToken`/`transactionReceipt`를 서버로 전달만 함
- 구독 상태는 DB(`user_subscriptions`)가 단일 소스 오브 트루스
- 앱 실행 시 + 구매 후 `userSubscriptionProvider` invalidate

---

## verify-purchase Edge Function 완성 설계

### Android (Google Play)

```typescript
// Google Play Developer API v3
// purchases.subscriptionsv2.get 호출
// 필요: Google Cloud 서비스 계정 키 (GOOGLE_SERVICE_ACCOUNT_KEY)

async function verifyAndroid(purchaseToken: string, productId: string) {
  const auth = new GoogleAuth({ credentials: JSON.parse(GOOGLE_SERVICE_ACCOUNT_KEY) });
  const response = await androidpublisher.purchases.subscriptionsv2.get({
    packageName: 'com.wandeung.wandeung',
    token: purchaseToken,
  });
  // expiryTime, paymentState 확인
  return { valid: true, expiresAt: response.lineItems[0].expiryTime };
}
```

### iOS (App Store)

```typescript
// App Store Server API v2
// JWT 서명으로 인증 → /inApps/v1/subscriptions/{transactionId}
// 필요: App Store Connect API Key (APPSTORE_API_KEY, APPSTORE_KEY_ID, APPSTORE_ISSUER_ID)

async function verifyiOS(transactionId: string) {
  const jwt = signJWT(APPSTORE_API_KEY, APPSTORE_KEY_ID, APPSTORE_ISSUER_ID);
  const response = await fetch(`https://api.storekit.itunes.apple.com/...`, {
    headers: { Authorization: `Bearer ${jwt}` }
  });
  return { valid: true, expiresAt: response.expiresDate };
}
```

---

## 구독 UI 와이어프레임

### 구독 화면 (SubscriptionScreen)

```
┌─────────────────────────────┐
│  ← 프리미엄 멤버십           │
│                             │
│  ┌───────────────────────┐  │
│  │  🎬 1080p 고화질 저장   │  │
│  │  ☁️ 무제한 클라우드     │  │
│  └───────────────────────┘  │
│                             │
│  ┌─ 월간 ──────────────┐   │
│  │  월 1,800원           │   │
│  └──────────────────────┘   │
│                             │
│  ┌─ 연간 (인기) ────────┐   │
│  │  연 18,000원          │   │
│  │  월 1,500원 (2개월 무료)│  │
│  └──────────────────────┘   │
│                             │
│  [구독하기]                  │
│                             │
│  구독은 언제든 해지 가능합니다  │
│  자동 갱신 구독입니다         │
└─────────────────────────────┘
```

### 설정 화면 (기존 수정)

```
설정
├── 저장 모드: ☁️ 클라우드
│   ├── 현재 플랜: Free (720p)
│   ├── 사용량: [======    ] 1.2 GB / 3 GB
│   └── [Pro로 업그레이드 →]
│
├── (Pro인 경우)
│   ├── 현재 플랜: Pro ✓ (1080p)
│   ├── 다음 결제일: 2026-04-22
│   └── [구독 관리 →]
```

---

## 스토어 심사 고려사항

### Google Play

- 구독 상품은 Google Play Console에서 먼저 생성 후 심사
- 테스트 시 라이선스 테스트 계정 등록 필수
- RTDN(Real-time Developer Notifications) 설정: Cloud Pub/Sub 토픽 → Supabase Edge Function

### App Store

- In-App Purchase capability를 Xcode 프로젝트에 추가
- App Store Connect에서 구독 상품 생성 + 심사용 스크린샷
- StoreKit 2 테스트 환경(Xcode StoreKit Configuration) 활용
- App Store Server Notification v2 URL 등록

### 공통

- 구독 약관 / 개인정보처리방침 링크 필수 (스토어 정책)
- "구독 자동 갱신" 고지 문구 구매 버튼 근처에 표시
- "구독 복원" 버튼 필수 (iOS 심사 리젝 사유 #1)

---

## 리스크 & 완화

| 리스크 | 영향 | 완화 |
|--------|------|------|
| 인앱 결제 심사 리젝 | 출시 지연 | Phase 1(Free만)으로 먼저 출시 |
| Google Play Developer API 키 유출 | 결제 위조 | Supabase Secrets에만 저장, 클라이언트에 노출 안 함 |
| 구독 갱신 알림 누락 | 만료된 Pro가 계속 사용 | 앱 실행 시 DB 조회 + expires_at 체크 이중 검증 |
| 환불 처리 | Pro 혜택 유지 | RTDN/ASN으로 환불 감지 → status = 'refunded' |
| Free 한도 너무 적음 | 사용자 이탈 | 사용 데이터 수집 후 한도 조정 (500MB ↔ 3GB) |

---

## 구현 순서 권장

```
Phase 1 (출시 준비) ─────────────────────────────
  ├── Free 한도 통일 (500MB or 3GB 결정)
  ├── 720p 압축 구현
  ├── 용량 바 UI
  ├── 한도 초과 안내 ("Pro 준비 중")
  └── 앱 출시 (Free only)
          │
Phase 2 (Android IAP) ──────────────────────────
  ├── in_app_purchase 패키지 추가
  ├── BillingService 구현
  ├── Google Play Console 상품 등록
  ├── verify-purchase 완성 (Android)
  ├── 구독 UI
  ├── RTDN 웹훅
  └── 앱 업데이트 출시
          │
Phase 3 (iOS IAP) ──────────────────────────────
  ├── App Store Connect 상품 등록
  ├── verify-purchase iOS 분기 추가
  ├── App Store Server Notification 웹훅
  ├── StoreKit capability 설정
  └── 앱 업데이트 출시
          │
Phase 4 (1080p Pro) ────────────────────────────
  ├── 티어별 영상 품질 분기
  ├── 다운그레이드 로직
  └── 앱 업데이트 출시
```

---

## 결정 필요 사항

1. **Free 용량 한도**: 500MB (현재 코드) vs 3GB (기존 설계) — 어느 쪽?
2. **출시 전략 확정**: 옵션 B (Free 먼저) 동의 여부
3. **가격 확정**: 월 1,800원 / 연 18,000원 유지 여부
4. **Phase 1 우선 진행** 여부
