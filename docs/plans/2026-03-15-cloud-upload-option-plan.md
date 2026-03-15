# 클라우드 업로드 옵션 구현 계획

설계 문서: `2026-03-15-cloud-upload-option-design.md`

## Step 1: cloudUploadEnabled 프로바이더 추가

**파일:** `lib/providers/connectivity_provider.dart`

`wifiOnlyUploadNotifier`와 동일한 패턴으로 `cloudUploadEnabled` StateNotifierProvider 추가.
- SharedPreferences 키: `cloud_upload_enabled`
- 기본값: `true`

**테스트:**
- `true`/`false` 토글 시 SharedPreferences에 값 저장/로드 확인

## Step 2: RecordSaveScreen 저장 플로우 분기

**파일:** `lib/screens/record_save_screen.dart` (L347-360)

`cloudUploadEnabled`가 `false`일 때:
- 압축(`VideoExportService.compressForUpload`) 스킵
- 업로드 큐 등록(`uploadQueueProvider.notifier.enqueue`) 스킵
- 썸네일 R2 업로드는 유지 (L334-345, 변경 없음)

변경 범위: L347-360의 압축/큐 등록 코드를 `if (cloudUploadEnabled)` 블록으로 감싸기만 하면 됨.

**테스트:**
- `cloudUploadEnabled = false`로 저장 시 업로드 큐에 레코드가 추가되지 않는지 확인
- 로컬 영상 경로가 DB에 그대로 저장되는지 확인

## Step 3: 설정 화면 UI 변경

**파일:** `lib/screens/settings_screen.dart`

업로드 섹션 최상단에 "클라우드 업로드" 토글 추가:
- `ref.watch(cloudUploadEnabledProvider)`로 상태 감시
- 토글 OFF 시:
  - Wi-Fi only 토글 비활성화 (또는 숨김)
  - 업로드 큐 상태 숨김
  - 로컬 영상 섹션의 "모두 업로드" 버튼 숨김

**테스트:**
- 토글 OFF 시 하위 업로드 관련 UI가 숨겨지는지 확인
- 토글 ON/OFF가 SharedPreferences에 저장되는지 확인

## Step 4: UploadStatusIndicator에 클라우드 완료 상태 추가

**파일:** `lib/widgets/upload_status_indicator.dart`

현재 상태:
- 큐에 없고 `!isLocalVideo` → 아무것도 안 보임
- 큐에 없고 `isLocalVideo` → 미업로드 (cloud_off, amber)

변경:
- 큐에 없고 `!isLocalVideo` → **클라우드 완료 아이콘 표시** (cloud_done, 흰색 또는 초록)
- 나머지는 기존 로직 유지

디자인 문서에서 정한 3가지 상태:
| 상태 | 아이콘 | 색상 |
|------|--------|------|
| 클라우드 완료 | `Icons.cloud_done` | 초록 |
| 업로드 대기/진행 | `Icons.cloud_upload` | 파랑/회색 |
| 로컬 전용 | `Icons.phone_android` | 흰색 |

현재 로컬 전용 아이콘이 `cloud_off`인데 → `phone_android`로 변경.

**테스트:**
- 3가지 상태별 올바른 아이콘 렌더링 확인
