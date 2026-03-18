# 미디어 트랙 분할/삭제 기능 디자인

> 날짜: 2026-03-18
> 참고: VLLO 스타일 미디어 편집

## 요약

미디어 타임라인 트랙에서 오브젝트를 선택 → 분할 → 삭제하여 원하는 구간만 남기는 기능. 편집 완료 후 "완료" 버튼을 누르면 선택된 구간만 프리뷰에 반영된다. 또한 좌측 트랙 라벨 클릭 시 해당 탭으로 이동하고, 미디어 트랙의 `+` 버튼을 제거한다.

## 현재 상태

- **미디어 트랙** (`VlloTimeline._buildMediaTrack`): 썸네일 이미지를 보여주기만 하며, 선택/분할/삭제 불가
- **분할 기능**: 속도(`SpeedSegmentsNotifier.splitAt`)와 줌(`CropSegmentsNotifier.splitAt`)에만 존재
- **좌측 라벨** (`TrackLabelPanel`): 라벨만 표시, 클릭 시 탭 전환 없음
- **미디어 `+` 버튼**: `TrackLabelPanel`에서 `showAddButton: true`로 미디어 라벨에 `+` 아이콘 표시 중

## 변경 사항

### 1. 미디어 세그먼트 모델 및 Provider 추가

**파일:** `lib/models/video_edit_models.dart`

```dart
/// 미디어 구간 — 영상의 특정 시간 범위 (분할/삭제 단위)
class MediaSegment {
  final String id;
  final Duration start;
  final Duration end;
  final bool isDeleted; // true면 최종 내보내기에서 제외

  const MediaSegment({
    required this.id,
    required this.start,
    required this.end,
    this.isDeleted = false,
  });

  MediaSegment copyWith({Duration? start, Duration? end, bool? isDeleted}) {
    return MediaSegment(
      id: id,
      start: start ?? this.start,
      end: end ?? this.end,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Duration get duration => end - start;
}
```

**파일:** `lib/providers/video_editor_provider.dart`

```dart
class MediaSegmentsNotifier extends StateNotifier<List<MediaSegment>> {
  MediaSegmentsNotifier() : super([]);

  void initWithFullRange(Duration videoDuration) {
    state = [
      MediaSegment(
        id: 'seg_0',
        start: Duration.zero,
        end: videoDuration,
      ),
    ];
  }

  /// 현재 플레이헤드 위치에서 분할
  void splitAt(Duration position) {
    final newSegments = <MediaSegment>[];
    int counter = state.length;
    for (final seg in state) {
      if (position > seg.start && position < seg.end) {
        newSegments.add(seg.copyWith(end: position));
        newSegments.add(MediaSegment(
          id: 'seg_${counter++}',
          start: position,
          end: seg.end,
          isDeleted: seg.isDeleted,
        ));
      } else {
        newSegments.add(seg);
      }
    }
    state = newSegments;
  }

  /// 특정 세그먼트 삭제 토글
  void toggleDelete(String id) {
    state = [
      for (final seg in state)
        if (seg.id == id) seg.copyWith(isDeleted: !seg.isDeleted) else seg,
    ];
  }

  /// 삭제된 세그먼트 복구
  void restore(String id) {
    state = [
      for (final seg in state)
        if (seg.id == id) seg.copyWith(isDeleted: false) else seg,
    ];
  }

  void restoreState(List<MediaSegment> segments) => state = segments;
  void reset() => state = [];
}

final mediaSegmentsProvider = StateNotifierProvider.autoDispose<
    MediaSegmentsNotifier, List<MediaSegment>>(
  (ref) => MediaSegmentsNotifier(),
);

/// 현재 선택된 미디어 세그먼트 ID
final selectedMediaSegmentProvider =
    StateProvider.autoDispose<String?>((ref) => null);
```

### 2. 미디어 트랙 UI 변경 (선택/분할/삭제 지원)

**파일:** `lib/widgets/editor/vllo_timeline.dart` — `_buildMediaTrack()` 수정

현재는 단순 썸네일 Row. 변경 후:

- `mediaSegmentsProvider`를 watch하여 각 세그먼트를 개별 블록으로 렌더링
- 각 블록은 해당 시간 범위의 썸네일을 보여줌
- **탭하면 선택** (흰색 테두리 하이라이트)
- **삭제된 세그먼트**: 반투명 + 빨간 X 표시, 탭하면 복구 가능
- 세그먼트 사이에 시각적 구분선 표시

```
┌──────────┐│┌──────────┐│┌──────────┐
│ seg 0    │││ seg 1    │││ seg 2    │  ← 각각 탭 가능
│ (선택됨) │││ (삭제됨) │││          │
└──────────┘│└──────────┘│└──────────┘
             ↑ 분할선
```

### 3. 컨텍스트 액션 바 — 미디어 탭 액션 추가

**파일:** `lib/screens/video_editor_screen.dart` — `_buildContextActionBar`의 `EditorTab.trim` case 수정

현재 트림 액션: `처음부터 | 여기부터 | 분할 | 여기까지 | 끝까지`

변경 후 — 세그먼트 선택 여부에 따라 분기:

**세그먼트 미선택 시 (기존과 유사):**
```
[ 분할 ]
```

**세그먼트 선택 시:**
```
[ 분할 ]  [ 삭제 ]  (또는 [ 복구 ] if 이미 삭제됨)    [ 완료 ✓ ]
```

- **분할**: 현재 플레이헤드 위치에서 선택된 세그먼트를 분할
- **삭제**: 선택된 세그먼트를 `isDeleted = true`로 토글
- **완료**: 편집 확정 → 삭제된 세그먼트를 제외하고 트림 범위 업데이트

### 4. "완료" 동작 — 삭제된 구간 제외 후 프리뷰 반영

"완료" 버튼 클릭 시:
1. `mediaSegmentsProvider`에서 `isDeleted == false`인 세그먼트만 필터링
2. 이 구간들을 기반으로 내보내기 시 FFmpeg concat 명령어에 반영
3. 프리뷰에서는 삭제된 구간을 스킵하며 재생
4. 트림 슬라이더의 범위도 유효 구간만 반영

**구현 방식:**
- `_onVideoPositionChanged`에서 현재 위치가 삭제된 세그먼트에 속하면 다음 유효 세그먼트의 시작점으로 자동 점프
- 내보내기 시 `VideoExportService`에 `mediaSegments` 파라미터 추가하여 삭제 구간을 FFmpeg `-ss`/`-to` 필터로 처리

### 5. 좌측 트랙 라벨 클릭 → 탭 이동

**파일:** `lib/widgets/editor/track_label_panel.dart`

- `_TrackLabel`에 `onTap` 콜백 추가
- `TrackLabelPanel`에서 각 라벨의 `onTap`으로 `selectedEditorTabProvider` 업데이트
- `ConsumerWidget` → 이미 `ConsumerWidget`이므로 `ref.read`로 탭 변경

```dart
_TrackLabel(
  icon: _tracks[i].$2,
  label: _tracks[i].$3,
  height: trackHeight,
  isActive: selectedTab == _tracks[i].$1,
  onTap: () => ref.read(selectedEditorTabProvider.notifier).state = _tracks[i].$1,
),
```

### 6. 미디어 `+` 버튼 제거

**파일:** `lib/widgets/editor/track_label_panel.dart`

- `showAddButton` 파라미터 및 관련 `Icons.add_circle_outline` 위젯 제거
- 미디어 라벨도 다른 트랙과 동일한 레이아웃 사용

## 구현 순서 (TDD)

### Step 1: 미디어 `+` 버튼 제거 + 라벨 탭 → 탭 이동
- `TrackLabelPanel`에서 `showAddButton` 제거
- 각 라벨에 `onTap` 추가하여 `selectedEditorTabProvider` 변경
- 테스트: 라벨 탭 시 `selectedEditorTabProvider` 값 변경 확인

### Step 2: `MediaSegment` 모델 + Provider 추가
- `video_edit_models.dart`에 `MediaSegment` 클래스 추가
- `video_editor_provider.dart`에 `MediaSegmentsNotifier` + providers 추가
- 테스트: `initWithFullRange`, `splitAt`, `toggleDelete` 단위 테스트

### Step 3: 미디어 트랙 UI — 세그먼트별 렌더링 + 선택
- `VlloTimeline._buildMediaTrack()`을 세그먼트 기반으로 리팩터링
- 각 세그먼트 탭 → `selectedMediaSegmentProvider` 업데이트
- 선택된 세그먼트 흰색 테두리, 삭제된 세그먼트 반투명+X 표시

### Step 4: 컨텍스트 액션 — 분할/삭제/복구 버튼
- `_buildTrimActions()` 대신 `_buildMediaActions()` 구현
- 분할: 현재 위치에서 `mediaSegmentsProvider.splitAt()`
- 삭제/복구: 선택된 세그먼트 `toggleDelete()`

### Step 5: "완료" 동작 — 프리뷰 반영
- 재생 중 삭제 구간 자동 스킵 로직 (`_onVideoPositionChanged` 수정)
- 내보내기 시 삭제 구간 제외 (FFmpeg concat filter 적용)
- `VideoExportService.exportVideo`에 `mediaSegments` 파라미터 추가

### Step 6: 초기화 연동
- `VideoEditorScreen.initState`에서 `mediaSegmentsProvider.initWithFullRange()` 호출
- Undo/Redo 히스토리에 `mediaSegments` 상태 포함

## 고려사항

- **삭제 전 최소 1개 세그먼트 유지**: 모든 세그먼트를 삭제하려 하면 경고 표시
- **분할 최소 길이**: 200ms 미만 세그먼트는 분할 불가 (기존 speed/crop과 동일)
- **배속/줌과의 연동**: 미디어 세그먼트 삭제 시 해당 구간의 speed/crop 세그먼트도 영향받음 → 내보내기 시 삭제 구간을 먼저 필터링한 후 speed/crop 적용
