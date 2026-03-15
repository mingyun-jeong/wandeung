# 클라우드 업로드 옵션 설계

## 개요

사용자가 촬영한 영상을 클라우드(R2)에 업로드할지 로컬에만 저장할지 설정에서 선택할 수 있도록 한다. 데이터 부담 경감과 프라이버시 보호가 목적.

## 결정 사항

- **글로벌 설정**: 앱 전체에 적용. 개별 영상 선택 아님.
- **기존 데이터 유지**: 설정 변경 전 클라우드 영상은 삭제하지 않음.
- **다시 켰을 때**: 새 영상만 업로드. 로컬 전용 기간 영상은 로컬 유지.
- **썸네일**: 설정과 무관하게 항상 R2 업로드 (파일 크기 작음).
- **로컬 전용 시 원본 유지**: 압축 없이 원본 그대로 로컬에 저장.

## 설정

- `cloudUploadEnabled` SharedPreferences 플래그 (기본값: `true`)
- 기존 `wifiOnlyUploadProvider`와 동일한 패턴으로 Riverpod StateNotifierProvider 생성
- 설정 화면 업로드 섹션에 "클라우드 업로드" 토글 추가
- 토글 OFF 시 하위 항목(Wi-Fi only 토글, 업로드 큐 상태) 숨김/비활성화

## 저장 플로우 변경

현재 플로우: 로컬 저장 → 썸네일 생성 → 썸네일 R2 업로드 → 영상 압축 → 업로드 큐 등록

`cloudUploadEnabled = false`일 때:
- 로컬 저장 → 썸네일 생성 → 썸네일 R2 업로드 → **끝** (압축/큐 등록 스킵)

변경 지점: `RecordSaveScreen`의 저장 로직에 분기 하나 추가. 업로드 큐/서비스 코드 변경 없음.

## 썸네일 상태 아이콘

`record_card.dart` 썸네일 좌상단에 반투명 원형 배지 + 흰색 아이콘 표시.

기존 `isLocalVideo` 프로퍼티와 `uploadQueueProvider`로 상태 판별:

| 상태 | 조건 | 아이콘 |
|------|------|--------|
| 클라우드 완료 | `!isLocalVideo` | 구름 (Icons.cloud_done) |
| 업로드 대기중 | `isLocalVideo` + 업로드 큐에 존재 | 구름+화살표 (Icons.cloud_upload) |
| 로컬 전용 | `isLocalVideo` + 업로드 큐에 없음 | 폰 (Icons.phone_android) |

스타일: 반투명 검은 배경(`Colors.black54`) 원형 컨테이너, 흰색 아이콘. 기존 화질 배지와 유사한 톤.
