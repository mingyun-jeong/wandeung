# 영상 저장 티어 & 비즈니스 모델 설계

## 개요

영상 업로드 방식을 정리하고, 클라우드 저장을 유료 비즈니스 모델로 전환한다. 사용자는 클라우드 모드(기본)와 로컬 모드 중 선택하며, 클라우드 모드 내에서 Free/Pro 티어로 화질과 용량이 구분된다.

## 티어 구조

| 티어 | 화질 | 클라우드 용량 | 보관 기간 | 가격 |
|------|------|-------------|----------|------|
| Free | 720p (CRF 28 압축) | 3 GB | 6개월 | 0원 |
| Pro | 1080p 원본 | 무제한* | 6개월 | 1,800원/월, 18,000원/년 |

\* 6개월 TTL로 실질적 최대 약 30GB.

### 가격 산정 근거

- 백엔드: Cloudflare R2 (egress 무료)
- 전제: 월 평균 1분 30초 영상 50개 업로드, 30개 다운로드
- 720p 90초 ≈ 25MB → 50개 = 1.25GB/월, 6개월 누적 최대 7.5GB
- 1080p 90초 ≈ 100MB → 50개 = 5GB/월, 6개월 누적 최대 30GB
- Pro R2 비용: 30GB × $0.015 = $0.45 ≈ 585원/월
- 앱스토어 수수료 15% 반영, Pro 마진 62%

## 저장 모드

### 클라우드 모드 (기본)

- 신규 사용자 기본값
- 촬영(`ResolutionPreset.high`) 후 티어에 따라 처리:
  - Free: 720p CRF 28로 압축 → R2 업로드 → 로컬 임시파일 삭제
  - Pro: 1080p 원본 그대로 → R2 업로드 → 로컬 임시파일 삭제
- 썸네일은 항상 R2 업로드
- 갤러리 저장 안 함 (다운로드 기능으로 대체)
- Wi-Fi 전용 업로드 토글 유지

### 로컬 모드

- 결제하지 않고 원본 화질을 유지하고 싶은 사용자용
- 촬영 후 원본 → 앱 내부 저장소(`/videos/`) + 갤러리('완등' 앨범) 저장
- R2 업로드 안 함
- 클라우드 관련 UI는 보이되 탭 시 "클라우드 모드로 전환하세요" 안내
- 설정 화면에 안내 문구: "원본 영상은 현재 기기에만 저장됩니다. 기기 분실 시 영상을 복구할 수 없습니다."

### 모드 전환

- 로컬 → 클라우드: 전환 시점 이후 새 영상만 클라우드 업로드. 기존 로컬 영상은 무시.
- 클라우드 → 로컬: 기존 클라우드 영상은 TTL까지 유지. 새 영상부터 로컬 저장.

## 데이터 흐름

```
촬영 완료 (ResolutionPreset.high)
    │
    ├── 클라우드 모드
    │   ├── Free
    │   │   ├── 720p CRF 28로 압축
    │   │   ├── R2 업로드 (upload queue)
    │   │   ├── 업로드 완료 후 로컬 임시파일 삭제
    │   │   └── 썸네일 → R2 업로드
    │   │
    │   └── Pro
    │       ├── 1080p 원본 그대로
    │       ├── R2 업로드 (upload queue)
    │       ├── 업로드 완료 후 로컬 임시파일 삭제
    │       └── 썸네일 → R2 업로드
    │
    └── 로컬 모드
        ├── 원본 → 앱 내부 저장소 (/videos/)
        ├── 원본 → 갤러리 ('완등' 앨범)
        └── 썸네일 → 로컬 저장

재생:
  클라우드 → R2 presigned URL 스트리밍 (기존 캐시 시스템 유지)
  로컬 → 로컬 파일 직접 재생

다운로드:
  클라우드 → "다운로드" 버튼 → R2에서 받아 갤러리 저장
  로컬 → 이미 갤러리에 있으므로 다운로드 버튼 불필요
```

## 용량 관리 & TTL

### 무료 3GB 한도

- DB에서 사용자별 클라우드 저장량 추적 (`climbing_records`의 영상 파일 크기 합산)
- 업로드 전 잔여 용량 체크
- 초과 시: "저장 공간이 가득 찼습니다. Pro로 업그레이드하거나 로컬 모드로 전환하세요"
- 설정 화면에 "X.X GB / 3 GB 사용 중" 프로그레스 바 표시

### 6개월 TTL

- `climbing_records.created_at` 기준 6개월 경과한 레코드의 R2 오브젝트 삭제
- 삭제 방식: Supabase Edge Function 또는 R2 Lifecycle Rule로 서버사이드 처리
- DB 레코드는 유지 (기록/통계 보존), `video_path`와 `thumbnail_path`만 null 처리
- 캘린더에서 과거 기록은 보이되, 영상은 "보관 기간 만료" 표시

### Pro 다운그레이드 (Pro → Free)

- 기존 1080p 영상은 R2에 그대로 유지 (TTL까지)
- 새 영상부터 720p 압축 적용
- 3GB 초과 상태면 새 업로드 차단, 기존 영상은 TTL까지 보관

## 결제 시스템

### 인앱 결제

- Google Play Billing Library (Android)
- 구독 상품: Pro 월간 1,800원, Pro 연간 18,000원 (2개월 무료)
- 구독 상태 관리: Google Play → Supabase Edge Function으로 서버사이드 검증

### DB 스키마

```sql
CREATE TABLE user_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  plan TEXT NOT NULL DEFAULT 'free',        -- 'free' | 'pro'
  status TEXT NOT NULL DEFAULT 'active',    -- 'active' | 'cancelled' | 'expired'
  platform TEXT NOT NULL DEFAULT 'android', -- 향후 iOS 대비
  store_transaction_id TEXT,
  started_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

### 티어 판별

```
앱 시작 / 업로드 시
  → user_subscriptions 조회
  → expires_at > now() && status = 'active' → Pro
  → 그 외 → Free
```

## 설정 UI

```
설정
├── 저장 모드
│   ├── ☁️ 클라우드 (기본)
│   │   ├── 현재 플랜: Free (720p) / Pro (1080p)
│   │   ├── 사용량: 1.2 GB / 3 GB [======    ] (Free만)
│   │   ├── Wi-Fi에서만 업로드: ON/OFF
│   │   ├── 업로드 대기열: N개 대기 중
│   │   └── [Pro로 업그레이드] 버튼 (Free만)
│   │
│   └── 📱 로컬
│       └── "원본 영상은 현재 기기에만 저장됩니다.
│            기기 분실 시 영상을 복구할 수 없습니다."
│
├── 구독 관리 (Pro일 때)
│   ├── 다음 결제일: 2026-04-16
│   └── 구독 해지 → Google Play로 이동
```

## 코드 변경 범위

### 수정 파일

| 파일 | 변경 내용 |
|------|----------|
| `lib/models/video_edit_models.dart` | `ExportQuality.uhd4k` 제거, `UploadCompression`을 티어별 분기로 변경 |
| `lib/screens/record_save_screen.dart` | 갤러리 저장을 모드별 분기, 티어별 압축/원본 업로드 로직 |
| `lib/screens/video_playback_screen.dart` | 로컬 모드 시 다운로드 버튼 숨김 |
| `lib/providers/connectivity_provider.dart` | 클라우드 ON/OFF → 저장 모드(cloud/local) 전환으로 리팩터 |
| `lib/providers/upload_queue_provider.dart` | 로컬 모드면 큐 비활성화, 티어별 압축 분기 |
| `lib/services/video_export_service.dart` | 4K 내보내기 제거 |
| `lib/services/video_upload_service.dart` | 용량 체크 로직 추가 (Free 3GB 한도) |
| `lib/models/climbing_record.dart` | `videoQuality` 필드 값을 720p/1080p로 한정 |

### 신규 파일

| 파일 | 내용 |
|------|------|
| `lib/providers/subscription_provider.dart` | 구독 상태 관리, 티어 판별 |
| `lib/services/billing_service.dart` | Google Play Billing 연동 |
| `supabase/migrations/xxx_user_subscriptions.sql` | 구독 테이블 |
| `supabase/migrations/xxx_add_file_size.sql` | 영상 파일 크기 컬럼 (용량 추적용) |
| `supabase/functions/verify-purchase/` | 구독 영수증 서버사이드 검증 |
| `supabase/functions/cleanup-expired/` | 6개월 TTL 클린업 |

### 제거 항목

- `ExportQuality.uhd4k` enum 값 및 관련 UI
- 클라우드 모드에서의 `Gal.putVideo()` 호출 (로컬 모드에서는 유지)
- 기존 "클라우드 업로드 ON/OFF" 토글 (저장 모드 선택으로 대체)
