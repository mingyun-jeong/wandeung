# 하단 네비게이션 분리: 영상 촬영 / 기록 탭

## 개요

하단 네비게이션 바를 추가하여 앱을 2개 탭으로 분리한다:
- **영상 촬영** 탭: 카메라 프리뷰 + 난이도/암장 오버레이 → 녹화 → 저장
- **기록** 탭: 캘린더 + 기록 목록 (기존 HomeScreen 내용)

## 네비게이션 흐름

```
LoginScreen → MainShellScreen
                ├─ Tab 0: CameraTabScreen (영상 촬영)
                │   ├─ 카메라 프리뷰 + 난이도/암장 오버레이
                │   ├─ 녹화 → RecordSaveScreen (push)
                │   └─ 저장 완료 → pop → CameraTabScreen → 기록 탭 전환
                └─ Tab 1: RecordsTabScreen (기록)
                    ├─ 캘린더 + 기록 목록
                    └─ RecordCard 탭 → RecordDetailScreen (push)
```

## 주요 결정사항

- **X 버튼**: 기록 탭으로 전환 (bottomNavIndexProvider 변경)
- **녹화 시작 조건**: 난이도/암장 선택 없이 녹화 가능, 저장 시점에 난이도/색상만 필수
- **탭 유지**: IndexedStack으로 카메라 탭 전환 시 재초기화 방지
- **녹화 버튼 색상**: 빨강 → 초록 (앱 테마 색상)

## 신규 파일

| 파일 | 역할 |
|------|------|
| `lib/screens/main_shell_screen.dart` | BottomNavigationBar + IndexedStack 루트 화면 |
| `lib/screens/camera_tab_screen.dart` | 영상 촬영 탭 (카메라 + 오버레이 셀렉터) |
| `lib/screens/records_tab_screen.dart` | 기록 탭 (캘린더 + 기록 목록) |
| `lib/providers/camera_settings_provider.dart` | 촬영 전 난이도/색상/암장 상태 관리 + bottomNavIndexProvider |
| `lib/widgets/camera_grade_overlay.dart` | 카메라 위 난이도/색상 선택 오버레이 |
| `lib/widgets/camera_gym_overlay.dart` | 카메라 위 암장 선택 오버레이 |
| `lib/widgets/zoom_controls.dart` | 줌 컨트롤 위젯 (0.6x, -, +) |
| `lib/widgets/recommended_tags.dart` | 추천 태그 칩 위젯 |

## 수정 파일

| 파일 | 변경 내용 |
|------|-----------|
| `lib/app.dart` | `HomeScreen` → `MainShellScreen`으로 교체 |
| `lib/screens/record_save_screen.dart` | cameraSettingsProvider에서 읽기, 추천 태그 추가, 하단 버튼 레이아웃 변경 |

## 삭제 파일

| 파일 | 사유 |
|------|------|
| `lib/screens/home_screen.dart` | `records_tab_screen.dart`로 대체 |
| `lib/screens/camera_screen.dart` | `camera_tab_screen.dart`로 대체 |

## 카메라 탭 레이아웃

```
Stack(
  CameraPreview (전체 화면)
  SafeArea → Row(X버튼, 타이머, 카메라전환)
  if (!recording) → Column(CameraGradeOverlay, CameraGymOverlay)  // 좌측
  Center bottom → 녹화 버튼 (초록)
  Bottom right → ZoomControls
)
```

## 저장 화면 변경사항

- 카메라에서 난이도/색상 선택 시 → 앱바에 뱃지만 표시, DifficultySelector 숨김
- 카메라에서 미선택 시 → fallback으로 DifficultySelector 표시
- 암장도 동일 패턴 (선택 시 읽기전용, 미선택 시 GymSelector 표시)
- 추천 태그 추가: #다이나믹, #슬랩, #발컨, #힐훅, #토훅, #맨틀링
- 하단 버튼: 삭제 + 저장하기 가로 배치

## 상태 관리

```dart
// CameraSettings — 촬영 전 메타데이터
cameraSettingsProvider: grade, color, selectedGym, manualGymName

// 탭 인덱스
bottomNavIndexProvider: 0 (영상 촬영) | 1 (기록)

// 기존 유지
selectedDateProvider, focusedMonthProvider → records_tab_screen.dart로 이동
recordsByDateProvider, recordDatesProvider → 변경 없음
```
