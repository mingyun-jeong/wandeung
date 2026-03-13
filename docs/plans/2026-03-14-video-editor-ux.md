# 영상 편집 사용성 개선 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 영상 편집 화면을 탭 바 레이아웃으로 변경하고, 구간별 속도 조절, 텍스트 멀티트랙 타임라인, 이모지 스티커 + 시간/제스처를 구현한다.

**Architecture:** 기존 Riverpod 상태 관리 + FFmpeg 파이프라인을 확장한다. 모델 변경(OverlayItem에 시간/회전 필드 추가) → Provider 확장 → 위젯 교체/신규 순으로 진행한다. FFmpeg 필터 체인은 기존 자막의 `enable='between(t,...)'` 패턴을 스티커에도 적용한다.

**Tech Stack:** Flutter, Riverpod, video_editor_2, ffmpeg_kit_flutter_new

## Progress

- [x] Task 1: OverlayItem 모델에 startTime, endTime, rotation 필드 추가
- [x] Task 2: SpeedSegmentsNotifier에 splitAt, mergeAdjacent, moveBoundary 추가
- [x] Task 3: selectedEditorTabProvider 추가
- [x] Task 4: FFmpeg 오버레이 필터에 시간 기반 enable 추가
- [x] Task 5: SubtitleImageRenderer에서 스티커 회전 렌더링 지원
- [x] Task 6: EditorTabBar 하단 탭 바 위젯 생성
- [x] Task 7: SpeedSegmentTimeline 인터랙티브 위젯
- [x] Task 8: TextMultiTrackTimeline 멀티트랙 타임라인 위젯
- [x] Task 9: StickerTimelineTrack 멀티트랙 타임라인 위젯
- [x] Task 10: OverlayStickerSheet에 이모지 탭 추가
- [x] Task 11: OverlayLayer에 핀치 줌/회전 + 시간 기반 표시 추가
- [x] Task 12: VideoEditorScreen을 탭 바 레이아웃으로 변경
- [ ] Task 13: 통합 테스트 및 정리 (미사용 파일 삭제: speed_picker_sheet.dart, speed_segment_bar.dart, subtitle_timeline_track.dart)

### 추가 수정 사항 (플랜 외)
- 영상 자동 반복재생 비활성화 (`setLooping(false)`)
- 속도 탭 빈 segments RangeError 방어 처리
- 탭 콘텐츠 영역 고정 높이(120) — 영상 프리뷰 크기 안정화
- TimelineRuler 공용 위젯 추가 (텍스트/스티커 탭에 시간 눈금 표시)

---

## Task 1: OverlayItem 모델에 startTime, endTime, rotation 필드 추가

**Files:**
- Modify: `lib/models/video_edit_models.dart`

**Step 1: OverlayItem 모델 수정**

`lib/models/video_edit_models.dart`의 `OverlayItem` 클래스에 3개 필드를 추가한다:

```dart
class OverlayItem {
  final String id;
  final String text;
  final Offset position;
  final double fontSize;
  final Color color;
  final Color? backgroundColor;
  final Duration? startTime;   // 추가: null이면 영상 전체
  final Duration? endTime;     // 추가: null이면 영상 전체
  final double rotation;       // 추가: 라디안 단위 (기본 0.0)

  const OverlayItem({
    required this.id,
    required this.text,
    this.position = const Offset(0.5, 0.5),
    this.fontSize = 24.0,
    this.color = const Color(0xFFFFFFFF),
    this.backgroundColor,
    this.startTime,
    this.endTime,
    this.rotation = 0.0,
  });

  /// 주어진 시간에 이 스티커가 보이는지 여부
  bool isVisibleAt(Duration time) {
    if (startTime == null || endTime == null) return true;
    return time >= startTime! && time < endTime!;
  }

  OverlayItem copyWith({
    String? id,
    String? text,
    Offset? position,
    double? fontSize,
    Color? color,
    Color? backgroundColor,
    bool clearBackground = false,
    Duration? startTime,
    bool clearStartTime = false,
    Duration? endTime,
    bool clearEndTime = false,
    double? rotation,
  }) {
    return OverlayItem(
      id: id ?? this.id,
      text: text ?? this.text,
      position: position ?? this.position,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      backgroundColor:
          clearBackground ? null : (backgroundColor ?? this.backgroundColor),
      startTime: clearStartTime ? null : (startTime ?? this.startTime),
      endTime: clearEndTime ? null : (endTime ?? this.endTime),
      rotation: rotation ?? this.rotation,
    );
  }
}
```

**Step 2: 기존 사용처가 깨지지 않는지 확인**

Run: `cd wandeung && flutter analyze`
Expected: 기존 코드에서 OverlayItem 생성 시 새 필드는 모두 optional이므로 에러 없음.

**Step 3: Commit**

```bash
git add lib/models/video_edit_models.dart
git commit -m "feat: OverlayItem에 startTime, endTime, rotation 필드 추가"
```

---

## Task 2: SpeedSegmentsNotifier에 splitAt, mergeAdjacent 메서드 추가

**Files:**
- Modify: `lib/providers/video_editor_provider.dart`

**Step 1: splitAt 메서드 추가**

`SpeedSegmentsNotifier`에 현재 재생 위치 기준으로 구간을 분할하는 메서드를 추가한다:

```dart
/// 지정 시간 위치에서 구간을 분할
void splitAt(Duration position) {
  final newSegments = <SpeedSegment>[];
  for (final seg in state) {
    if (position > seg.start && position < seg.end) {
      // 이 구간을 둘로 분할
      newSegments.add(seg.copyWith(end: position));
      newSegments.add(seg.copyWith(start: position));
    } else {
      newSegments.add(seg);
    }
  }
  state = newSegments;
}

/// 인접한 동일 속도 구간을 병합
void mergeAdjacent() {
  if (state.length <= 1) return;
  final merged = <SpeedSegment>[state.first];
  for (int i = 1; i < state.length; i++) {
    final prev = merged.last;
    final curr = state[i];
    if ((prev.speed - curr.speed).abs() < 0.01 && prev.end == curr.start) {
      merged[merged.length - 1] = prev.copyWith(end: curr.end);
    } else {
      merged.add(curr);
    }
  }
  state = merged;
}

/// 특정 구간의 배속을 변경하고 인접 동일 속도 구간을 자동 병합
void updateSpeedAndMerge(int index, double speed) {
  updateSpeed(index, speed);
  mergeAdjacent();
}

/// 구간 경계(구간 사이 경계선)를 이동
/// [boundaryIndex]는 구간 인덱스(0-based), 해당 구간의 끝 = 다음 구간의 시작을 이동
void moveBoundary(int boundaryIndex, Duration newPosition) {
  if (boundaryIndex < 0 || boundaryIndex >= state.length - 1) return;
  final curr = state[boundaryIndex];
  final next = state[boundaryIndex + 1];

  // 최소 구간 길이 200ms 보장
  const minDuration = Duration(milliseconds: 200);
  final clampedPos = Duration(
    milliseconds: newPosition.inMilliseconds
        .clamp(
          curr.start.inMilliseconds + minDuration.inMilliseconds,
          next.end.inMilliseconds - minDuration.inMilliseconds,
        ),
  );

  state = [
    for (int i = 0; i < state.length; i++)
      if (i == boundaryIndex)
        state[i].copyWith(end: clampedPos)
      else if (i == boundaryIndex + 1)
        state[i].copyWith(start: clampedPos)
      else
        state[i],
  ];
}
```

**Step 2: selectedSpeedSegmentProvider 추가**

같은 파일에 선택된 속도 구간 인덱스 Provider 추가:

```dart
/// 현재 선택된 속도 구간 인덱스 (null이면 없음)
final selectedSpeedSegmentProvider =
    StateProvider.autoDispose<int?>((ref) => null);
```

**Step 3: Analyze**

Run: `cd wandeung && flutter analyze`
Expected: No issues found

**Step 4: Commit**

```bash
git add lib/providers/video_editor_provider.dart
git commit -m "feat: SpeedSegmentsNotifier에 splitAt, mergeAdjacent, moveBoundary 추가"
```

---

## Task 3: selectedEditorTabProvider 추가

**Files:**
- Modify: `lib/providers/video_editor_provider.dart`

**Step 1: 탭 enum과 Provider 추가**

`lib/providers/video_editor_provider.dart` 파일 하단에 추가:

```dart
/// 편집 화면 하단 탭
enum EditorTab { trim, speed, text, sticker }

/// 현재 선택된 편집 탭
final selectedEditorTabProvider =
    StateProvider.autoDispose<EditorTab>((ref) => EditorTab.trim);
```

**Step 2: Commit**

```bash
git add lib/providers/video_editor_provider.dart
git commit -m "feat: EditorTab enum 및 selectedEditorTabProvider 추가"
```

---

## Task 4: FFmpeg 오버레이 필터에 시간 기반 enable 추가

**Files:**
- Modify: `lib/services/ffmpeg_command_builder.dart`

**Step 1: 오버레이 스티커에 enable 조건 추가**

`_buildFilterComplex`의 오버레이 섹션(line ~118-143)에서, `OverlayItem`에 `startTime`/`endTime`이 있을 때 `enable='between(t,...)'`를 추가한다.

기존 코드:
```dart
// 오버레이 스티커는 항상 표시 (enable 없음)
final overlayFilter =
    "$currentLabel[$inputIdx:v]overlay="
    "x=$px*W-w/2:y=$py*H-h/2";
```

변경 후:
```dart
String overlayFilter =
    "$currentLabel[$inputIdx:v]overlay="
    "x=$px*W-w/2:y=$py*H-h/2";

// 시간 범위가 지정된 경우 enable 조건 추가
if (item.startTime != null && item.endTime != null) {
  final startSec = item.startTime!.inMilliseconds / 1000.0;
  final endSec = item.endTime!.inMilliseconds / 1000.0;
  overlayFilter += ":"
      "enable='between(t,${startSec.toStringAsFixed(3)},${endSec.toStringAsFixed(3)})'";
}
```

**Step 2: Analyze**

Run: `cd wandeung && flutter analyze`
Expected: No issues found

**Step 3: Commit**

```bash
git add lib/services/ffmpeg_command_builder.dart
git commit -m "feat: 오버레이 스티커에 시간 기반 enable 필터 추가"
```

---

## Task 5: SubtitleImageRenderer에서 스티커 회전 렌더링 지원

**Files:**
- Modify: `lib/services/subtitle_image_renderer.dart`

**Step 1: renderOverlays에서 rotation 반영**

`_renderOverlay` 메서드에 `item.rotation` 적용 코드를 추가한다. 기존 자막의 `_renderOne`에서 회전을 처리하는 패턴(line 177-204)을 동일하게 적용한다.

기존 `_renderOverlay`의 canvas 직접 그리기 부분(line 75~101)을 수정:

```dart
// 회전 시 필요한 바운딩 박스 계산
final angle = item.rotation;
final double imgW;
final double imgH;
if (angle == 0.0) {
  imgW = contentW;
  imgH = contentH;
} else {
  final cosA = math.cos(angle).abs();
  final sinA = math.sin(angle).abs();
  imgW = contentW * cosA + contentH * sinA;
  imgH = contentW * sinA + contentH * cosA;
}

final imgWi = imgW.ceil();
final imgHi = imgH.ceil();

final recorder = ui.PictureRecorder();
final canvas = ui.Canvas(recorder);

// 회전 적용 (중심 기준)
if (angle != 0.0) {
  canvas.translate(imgWi / 2, imgHi / 2);
  canvas.rotate(angle);
  canvas.translate(-contentW / 2, -contentH / 2);
} else {
  canvas.translate((imgWi - contentW) / 2, (imgHi - contentH) / 2);
}

// 기존 배경 + 외곽선 + 텍스트 렌더링 코드 그대로 유지
```

**Step 2: Analyze**

Run: `cd wandeung && flutter analyze`
Expected: No issues found

**Step 3: Commit**

```bash
git add lib/services/subtitle_image_renderer.dart
git commit -m "feat: 오버레이 스티커 회전 렌더링 지원"
```

---

## Task 6: 하단 탭 바 위젯 생성 (EditorTabBar)

**Files:**
- Create: `lib/widgets/editor/editor_tab_bar.dart`

**Step 1: EditorTabBar 위젯 작성**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/video_editor_provider.dart';

/// 편집 화면 하단 탭 바
class EditorTabBar extends ConsumerWidget {
  const EditorTabBar({super.key});

  static const _tabs = [
    (EditorTab.trim, Icons.content_cut, '트림'),
    (EditorTab.speed, Icons.speed, '속도'),
    (EditorTab.text, Icons.title, '텍스트'),
    (EditorTab.sticker, Icons.emoji_emotions, '스티커'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedEditorTabProvider);

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: _tabs.map((tab) {
          final (type, icon, label) = tab;
          final isSelected = selected == type;

          return Expanded(
            child: GestureDetector(
              onTap: () =>
                  ref.read(selectedEditorTabProvider.notifier).state = type,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 24,
                      color: isSelected ? Colors.white : Colors.white38,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.normal,
                        color: isSelected ? Colors.white : Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
```

**Step 2: Analyze**

Run: `cd wandeung && flutter analyze`
Expected: No issues found

**Step 3: Commit**

```bash
git add lib/widgets/editor/editor_tab_bar.dart
git commit -m "feat: EditorTabBar 하단 탭 바 위젯 추가"
```

---

## Task 7: SpeedSegmentTimeline 인터랙티브 위젯

**Files:**
- Create: `lib/widgets/editor/speed_segment_timeline.dart`

**Step 1: SpeedSegmentTimeline 위젯 작성**

기존 `SpeedSegmentBar`를 대체하는 인터랙티브 타임라인이다. 구간 탭 선택, 분할 버튼, 속도 버튼, 경계선 드래그를 지원한다.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/video_edit_models.dart';
import '../../providers/video_editor_provider.dart';

/// 속도 구간별 인터랙티브 타임라인
class SpeedSegmentTimeline extends ConsumerWidget {
  final Duration totalDuration;
  final Duration currentPosition;
  final VoidCallback onSplit;

  const SpeedSegmentTimeline({
    super.key,
    required this.totalDuration,
    required this.currentPosition,
    required this.onSplit,
  });

  static const _speedOptions = [0.5, 1.0, 2.0, 4.0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segments = ref.watch(speedSegmentsProvider);
    final selectedIdx = ref.watch(selectedSpeedSegmentProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 상단: 속도 버튼 + 분할 버튼
          Row(
            children: [
              ..._speedOptions.map((speed) {
                final isActive = selectedIdx != null &&
                    selectedIdx < segments.length &&
                    (segments[selectedIdx].speed - speed).abs() < 0.01;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: selectedIdx != null
                        ? () {
                            ref
                                .read(speedSegmentsProvider.notifier)
                                .updateSpeedAndMerge(selectedIdx, speed);
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive
                            ? _speedColor(speed)
                            : Colors.white.withOpacity(
                                selectedIdx != null ? 0.15 : 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isActive
                              ? _speedColor(speed)
                              : Colors.white24,
                        ),
                      ),
                      child: Text(
                        '${speed}x',
                        style: TextStyle(
                          color: isActive
                              ? Colors.white
                              : (selectedIdx != null
                                  ? Colors.white70
                                  : Colors.white24),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const Spacer(),
              // 분할 버튼
              GestureDetector(
                onTap: onSplit,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.content_cut, size: 16, color: Colors.white70),
                      SizedBox(width: 4),
                      Text(
                        '분할',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 타임라인 바
          SizedBox(
            height: 48,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trackWidth = constraints.maxWidth;
                final totalMs = totalDuration.inMilliseconds.toDouble();

                return Stack(
                  children: [
                    // 배경
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    // 구간 블록들
                    ...List.generate(segments.length, (i) {
                      final seg = segments[i];
                      final leftFrac = seg.start.inMilliseconds / totalMs;
                      final widthFrac =
                          seg.originalDuration.inMilliseconds / totalMs;
                      final isSelected = i == selectedIdx;

                      return Positioned(
                        left: leftFrac * trackWidth,
                        width: (widthFrac * trackWidth).clamp(20.0, trackWidth),
                        top: 2,
                        bottom: 2,
                        child: GestureDetector(
                          onTap: () {
                            ref
                                .read(selectedSpeedSegmentProvider.notifier)
                                .state = (selectedIdx == i) ? null : i;
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: _speedColor(seg.speed)
                                  .withOpacity(isSelected ? 0.9 : 0.5),
                              borderRadius: BorderRadius.circular(4),
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 2)
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${seg.speed}x',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSelected ? 14 : 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    // 경계선 드래그 핸들
                    ...List.generate(segments.length - 1, (i) {
                      final boundary = segments[i].end;
                      final leftFrac = boundary.inMilliseconds / totalMs;

                      return Positioned(
                        left: leftFrac * trackWidth - 8,
                        width: 16,
                        top: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onHorizontalDragUpdate: (details) {
                            final deltaMs =
                                (details.delta.dx / trackWidth * totalMs)
                                    .round();
                            final newPos = Duration(
                              milliseconds:
                                  boundary.inMilliseconds + deltaMs,
                            );
                            ref
                                .read(speedSegmentsProvider.notifier)
                                .moveBoundary(i, newPos);
                          },
                          child: MouseRegion(
                            cursor: SystemMouseCursors.resizeColumn,
                            child: Center(
                              child: Container(
                                width: 4,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white70,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    // 재생 위치 인디케이터
                    Positioned(
                      left:
                          (currentPosition.inMilliseconds / totalMs) *
                                  trackWidth -
                              1,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 2, color: Colors.white),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static Color _speedColor(double speed) {
    if (speed <= 0.5) return const Color(0xFF42A5F5);
    if (speed <= 1.0) return const Color(0xFF66BB6A);
    if (speed <= 2.0) return const Color(0xFFFFA726);
    return const Color(0xFFEF5350);
  }
}
```

**Step 2: Analyze**

Run: `cd wandeung && flutter analyze`
Expected: No issues found

**Step 3: Commit**

```bash
git add lib/widgets/editor/speed_segment_timeline.dart
git commit -m "feat: SpeedSegmentTimeline 인터랙티브 속도 타임라인 위젯 추가"
```

---

## Task 8: TextMultiTrackTimeline 멀티트랙 타임라인 위젯

**Files:**
- Create: `lib/widgets/editor/text_multi_track_timeline.dart`

**Step 1: TextMultiTrackTimeline 위젯 작성**

텍스트 하나당 트랙 한 줄. 블록 핸들로 시작/끝 조절, 본체 드래그로 구간 이동, 탭으로 편집, 길게 눌러 삭제.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/subtitle_item.dart';
import '../../providers/subtitle_provider.dart';

/// 텍스트 멀티트랙 타임라인
class TextMultiTrackTimeline extends ConsumerWidget {
  final Duration totalDuration;
  final Duration currentPosition;
  final VoidCallback onAddText;
  final void Function(SubtitleItem) onEditText;

  const TextMultiTrackTimeline({
    super.key,
    required this.totalDuration,
    required this.currentPosition,
    required this.onAddText,
    required this.onEditText,
  });

  static const _trackHeight = 32.0;
  static const _minDurationMs = 300;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitles = ref.watch(subtitlesProvider);
    final selectedId = ref.watch(selectedSubtitleIdProvider);
    final totalMs = totalDuration.inMilliseconds.toDouble();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 상단: 추가 버튼
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: onAddText,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 16, color: Colors.white70),
                    SizedBox(width: 4),
                    Text(
                      '텍스트 추가',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 멀티트랙 영역
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: subtitles.length > 4
                  ? _trackHeight * 4 + 16
                  : _trackHeight * subtitles.length + 16,
            ),
            child: subtitles.isEmpty
                ? Container(
                    height: _trackHeight,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '텍스트를 추가해보세요',
                      style: TextStyle(color: Colors.white24, fontSize: 12),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        ...subtitles.asMap().entries.map((entry) {
                          final sub = entry.value;
                          final isSelected = sub.id == selectedId;

                          return SizedBox(
                            height: _trackHeight,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final trackWidth = constraints.maxWidth;

                                return Stack(
                                  children: [
                                    // 트랙 배경
                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                    ),
                                    // 블록
                                    _TrackBlock(
                                      sub: sub,
                                      isSelected: isSelected,
                                      trackWidth: trackWidth,
                                      totalMs: totalMs,
                                      totalDuration: totalDuration,
                                      onTap: () {
                                        ref
                                            .read(selectedSubtitleIdProvider
                                                .notifier)
                                            .state = sub.id;
                                        onEditText(sub);
                                      },
                                      onLongPress: () {
                                        _showDeleteDialog(context, ref, sub);
                                      },
                                      onStartDrag: (deltaDx) {
                                        final deltaMs =
                                            (deltaDx / trackWidth * totalMs)
                                                .round();
                                        final newStart = Duration(
                                          milliseconds: (sub
                                                      .startTime
                                                      .inMilliseconds +
                                                  deltaMs)
                                              .clamp(
                                                  0,
                                                  sub.endTime
                                                          .inMilliseconds -
                                                      _minDurationMs),
                                        );
                                        ref
                                            .read(subtitlesProvider.notifier)
                                            .updateSubtitle(
                                              sub.id,
                                              sub.copyWith(
                                                  startTime: newStart),
                                            );
                                      },
                                      onEndDrag: (deltaDx) {
                                        final deltaMs =
                                            (deltaDx / trackWidth * totalMs)
                                                .round();
                                        final newEnd = Duration(
                                          milliseconds: (sub.endTime
                                                      .inMilliseconds +
                                                  deltaMs)
                                              .clamp(
                                            sub.startTime.inMilliseconds +
                                                _minDurationMs,
                                            totalDuration.inMilliseconds,
                                          ),
                                        );
                                        ref
                                            .read(subtitlesProvider.notifier)
                                            .updateSubtitle(
                                              sub.id,
                                              sub.copyWith(endTime: newEnd),
                                            );
                                      },
                                      onBodyDrag: (deltaDx) {
                                        final deltaMs =
                                            (deltaDx / trackWidth * totalMs)
                                                .round();
                                        final duration = sub.endTime
                                                .inMilliseconds -
                                            sub.startTime.inMilliseconds;
                                        var newStartMs =
                                            sub.startTime.inMilliseconds +
                                                deltaMs;
                                        newStartMs = newStartMs.clamp(
                                            0,
                                            totalDuration.inMilliseconds -
                                                duration);
                                        ref
                                            .read(subtitlesProvider.notifier)
                                            .updateSubtitle(
                                              sub.id,
                                              sub.copyWith(
                                                startTime: Duration(
                                                    milliseconds: newStartMs),
                                                endTime: Duration(
                                                    milliseconds:
                                                        newStartMs + duration),
                                              ),
                                            );
                                      },
                                    ),
                                    // 재생 위치
                                    Positioned(
                                      left: (currentPosition
                                                  .inMilliseconds /
                                              totalMs) *
                                          trackWidth,
                                      top: 0,
                                      bottom: 0,
                                      child: Container(
                                          width: 1,
                                          color: Colors.white54),
                                    ),
                                  ],
                                );
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(
      BuildContext context, WidgetRef ref, SubtitleItem sub) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('텍스트 삭제'),
        content: Text("'${sub.text}' 텍스트를 삭제할까요?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              ref.read(subtitlesProvider.notifier).removeSubtitle(sub.id);
              Navigator.pop(ctx);
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// 트랙 내 드래그 가능한 블록 (양쪽 핸들 + 본체 드래그)
class _TrackBlock extends StatelessWidget {
  final SubtitleItem sub;
  final bool isSelected;
  final double trackWidth;
  final double totalMs;
  final Duration totalDuration;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final void Function(double) onStartDrag;
  final void Function(double) onEndDrag;
  final void Function(double) onBodyDrag;

  static const _handleWidth = 12.0;

  const _TrackBlock({
    required this.sub,
    required this.isSelected,
    required this.trackWidth,
    required this.totalMs,
    required this.totalDuration,
    required this.onTap,
    required this.onLongPress,
    required this.onStartDrag,
    required this.onEndDrag,
    required this.onBodyDrag,
  });

  @override
  Widget build(BuildContext context) {
    final leftFrac = sub.startTime.inMilliseconds / totalMs;
    final widthFrac =
        (sub.endTime - sub.startTime).inMilliseconds / totalMs;
    final blockLeft = leftFrac * trackWidth;
    final blockWidth = (widthFrac * trackWidth).clamp(20.0, trackWidth);

    return Positioned(
      left: blockLeft,
      width: blockWidth,
      top: 3,
      bottom: 3,
      child: Stack(
        children: [
          // 본체 (좌우 드래그로 구간 이동)
          Positioned.fill(
            child: GestureDetector(
              onTap: onTap,
              onLongPress: onLongPress,
              onHorizontalDragUpdate: (d) => onBodyDrag(d.delta.dx),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.blue.withOpacity(0.8)
                      : Colors.amber.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4),
                  border: isSelected
                      ? Border.all(color: Colors.white, width: 1.5)
                      : null,
                ),
                alignment: Alignment.center,
                padding:
                    const EdgeInsets.symmetric(horizontal: _handleWidth + 2),
                child: Text(
                  sub.text,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          // 왼쪽 핸들
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: _handleWidth,
            child: GestureDetector(
              onHorizontalDragUpdate: (d) => onStartDrag(d.delta.dx),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.3)
                      : Colors.transparent,
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(4)),
                ),
                child: isSelected
                    ? const Center(
                        child: Icon(Icons.drag_handle,
                            size: 10, color: Colors.white70))
                    : null,
              ),
            ),
          ),
          // 오른쪽 핸들
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: _handleWidth,
            child: GestureDetector(
              onHorizontalDragUpdate: (d) => onEndDrag(d.delta.dx),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.3)
                      : Colors.transparent,
                  borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(4)),
                ),
                child: isSelected
                    ? const Center(
                        child: Icon(Icons.drag_handle,
                            size: 10, color: Colors.white70))
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

**Step 2: Analyze**

Run: `cd wandeung && flutter analyze`
Expected: No issues found

**Step 3: Commit**

```bash
git add lib/widgets/editor/text_multi_track_timeline.dart
git commit -m "feat: TextMultiTrackTimeline 멀티트랙 텍스트 타임라인 위젯 추가"
```

---

## Task 9: StickerTimelineTrack 멀티트랙 타임라인 위젯

**Files:**
- Create: `lib/widgets/editor/sticker_timeline_track.dart`

**Step 1: StickerTimelineTrack 위젯 작성**

텍스트 멀티트랙과 동일한 패턴을 OverlayItem용으로 구현한다. 스티커 하나당 트랙 한 줄, 블록 핸들로 시작/끝 조절, 본체 드래그로 구간 이동.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/video_edit_models.dart';
import '../../providers/video_editor_provider.dart';

/// 스티커 멀티트랙 타임라인
class StickerTimelineTrack extends ConsumerWidget {
  final Duration totalDuration;
  final Duration currentPosition;
  final VoidCallback onAddSticker;

  const StickerTimelineTrack({
    super.key,
    required this.totalDuration,
    required this.currentPosition,
    required this.onAddSticker,
  });

  static const _trackHeight = 32.0;
  static const _minDurationMs = 300;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlays = ref.watch(overlaysProvider);
    final totalMs = totalDuration.inMilliseconds.toDouble();

    // startTime이 있는 오버레이만 타임라인에 표시
    final timedOverlays =
        overlays.where((o) => o.startTime != null && o.endTime != null).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 상단: 추가 버튼
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: onAddSticker,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 16, color: Colors.white70),
                    SizedBox(width: 4),
                    Text(
                      '스티커 추가',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 멀티트랙
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: overlays.length > 4
                  ? _trackHeight * 4 + 16
                  : _trackHeight * overlays.length.clamp(1, 99) + 16,
            ),
            child: overlays.isEmpty
                ? Container(
                    height: _trackHeight,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '스티커를 추가해보세요',
                      style: TextStyle(color: Colors.white24, fontSize: 12),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: overlays.map((item) {
                        return SizedBox(
                          height: _trackHeight,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final trackWidth = constraints.maxWidth;

                              // 시간이 없는 스티커는 전체 구간 표시
                              final startMs =
                                  item.startTime?.inMilliseconds ?? 0;
                              final endMs = item.endTime?.inMilliseconds ??
                                  totalDuration.inMilliseconds;
                              final leftFrac = startMs / totalMs;
                              final widthFrac = (endMs - startMs) / totalMs;
                              final blockLeft = leftFrac * trackWidth;
                              final blockWidth =
                                  (widthFrac * trackWidth).clamp(20.0, trackWidth);

                              return Stack(
                                children: [
                                  Container(
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  Positioned(
                                    left: blockLeft,
                                    width: blockWidth,
                                    top: 3,
                                    bottom: 3,
                                    child: _StickerBlock(
                                      item: item,
                                      trackWidth: trackWidth,
                                      totalMs: totalMs,
                                      totalDuration: totalDuration,
                                      onLongPress: () =>
                                          _showDeleteDialog(context, ref, item),
                                      onStartDrag: (deltaDx) {
                                        final deltaMs =
                                            (deltaDx / trackWidth * totalMs)
                                                .round();
                                        final newStart = Duration(
                                          milliseconds: (startMs + deltaMs)
                                              .clamp(
                                                  0,
                                                  endMs - _minDurationMs),
                                        );
                                        ref
                                            .read(overlaysProvider.notifier)
                                            .updateOverlay(
                                              item.id,
                                              item.copyWith(
                                                  startTime: newStart),
                                            );
                                      },
                                      onEndDrag: (deltaDx) {
                                        final deltaMs =
                                            (deltaDx / trackWidth * totalMs)
                                                .round();
                                        final newEnd = Duration(
                                          milliseconds: (endMs + deltaMs)
                                              .clamp(
                                            startMs + _minDurationMs,
                                            totalDuration.inMilliseconds,
                                          ),
                                        );
                                        ref
                                            .read(overlaysProvider.notifier)
                                            .updateOverlay(
                                              item.id,
                                              item.copyWith(endTime: newEnd),
                                            );
                                      },
                                      onBodyDrag: (deltaDx) {
                                        final deltaMs =
                                            (deltaDx / trackWidth * totalMs)
                                                .round();
                                        final duration = endMs - startMs;
                                        var newStartMs = startMs + deltaMs;
                                        newStartMs = newStartMs.clamp(
                                            0,
                                            totalDuration.inMilliseconds -
                                                duration);
                                        ref
                                            .read(overlaysProvider.notifier)
                                            .updateOverlay(
                                              item.id,
                                              item.copyWith(
                                                startTime: Duration(
                                                    milliseconds: newStartMs),
                                                endTime: Duration(
                                                    milliseconds:
                                                        newStartMs + duration),
                                              ),
                                            );
                                      },
                                    ),
                                  ),
                                  // 재생 위치
                                  Positioned(
                                    left: (currentPosition.inMilliseconds /
                                            totalMs) *
                                        trackWidth,
                                    top: 0,
                                    bottom: 0,
                                    child: Container(
                                        width: 1, color: Colors.white54),
                                  ),
                                ],
                              );
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(
      BuildContext context, WidgetRef ref, OverlayItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('스티커 삭제'),
        content: Text("'${item.text}' 스티커를 삭제할까요?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              ref.read(overlaysProvider.notifier).removeOverlay(item.id);
              Navigator.pop(ctx);
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _StickerBlock extends StatelessWidget {
  final OverlayItem item;
  final double trackWidth;
  final double totalMs;
  final Duration totalDuration;
  final VoidCallback onLongPress;
  final void Function(double) onStartDrag;
  final void Function(double) onEndDrag;
  final void Function(double) onBodyDrag;

  static const _handleWidth = 12.0;

  const _StickerBlock({
    required this.item,
    required this.trackWidth,
    required this.totalMs,
    required this.totalDuration,
    required this.onLongPress,
    required this.onStartDrag,
    required this.onEndDrag,
    required this.onBodyDrag,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onLongPress: onLongPress,
            onHorizontalDragUpdate: (d) => onBodyDrag(d.delta.dx),
            child: Container(
              decoration: BoxDecoration(
                color: (item.backgroundColor ?? Colors.purple)
                    .withOpacity(0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: _handleWidth + 2),
              child: Text(
                item.text,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        // 왼쪽 핸들
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: _handleWidth,
          child: GestureDetector(
            onHorizontalDragUpdate: (d) => onStartDrag(d.delta.dx),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.transparent,
                borderRadius:
                    BorderRadius.horizontal(left: Radius.circular(4)),
              ),
            ),
          ),
        ),
        // 오른쪽 핸들
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: _handleWidth,
          child: GestureDetector(
            onHorizontalDragUpdate: (d) => onEndDrag(d.delta.dx),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.transparent,
                borderRadius:
                    BorderRadius.horizontal(right: Radius.circular(4)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
```

**Step 2: Analyze**

Run: `cd wandeung && flutter analyze`
Expected: No issues found

**Step 3: Commit**

```bash
git add lib/widgets/editor/sticker_timeline_track.dart
git commit -m "feat: StickerTimelineTrack 스티커 멀티트랙 타임라인 위젯 추가"
```

---

## Task 10: OverlayStickerSheet에 이모지 탭 추가

**Files:**
- Modify: `lib/widgets/editor/overlay_sticker_sheet.dart`

**Step 1: 이모지 탭 구조로 변경**

기존 `OverlayStickerSheet`를 DefaultTabController + TabBar로 감싸서 [등급 | 이모지] 2개 탭으로 변경한다.

등급 탭은 기존 UI 그대로 유지. 이모지 탭은 카테고리별 이모지 그리드:

```dart
// 이모지 데이터
static const _emojiCategories = {
  '클라이밍': ['🧗', '💪', '🔥', '⛰️', '🏔️', '🪨', '🎯', '👏', '🧗‍♂️', '🧗‍♀️'],
  '감정': ['😆', '😤', '🥲', '😎', '🤯', '🫣', '😱', '🥳', '😮‍💨', '🫠'],
  '기타': ['⭐', '❤️', '✨', '🎉', '👍', '💯', '🏆', '🥇', '💥', '🔔'],
};
```

이모지 선택 시 `OverlayItem`을 생성한다:
- `text` = 선택한 이모지 문자
- `fontSize` = 48.0
- `backgroundColor` = null (이모지 자체가 컬러풀)
- `startTime`/`endTime` = 현재 재생 위치 ~ +3초 (추가 파라미터로 받기)

**변경 포인트:**
- `OverlayStickerSheet`에 `currentPosition`과 `videoDuration` 파라미터 추가
- 생성된 `OverlayItem`에 `startTime`/`endTime` 설정
- 등급 스티커도 동일하게 `startTime`/`endTime` 설정

**Step 2: Analyze**

Run: `cd wandeung && flutter analyze`
Expected: No issues found

**Step 3: Commit**

```bash
git add lib/widgets/editor/overlay_sticker_sheet.dart
git commit -m "feat: OverlayStickerSheet에 이모지 탭 추가 및 시간 설정 지원"
```

---

## Task 11: OverlayLayer에 핀치 줌/회전 제스처 + 시간 기반 표시 추가

**Files:**
- Modify: `lib/widgets/editor/overlay_layer.dart`

**Step 1: 시간 기반 표시 추가**

`OverlayLayer`에 `currentPosition` 파라미터를 추가하고, `item.isVisibleAt(currentPosition)`으로 필터링한다.

**Step 2: 핀치 줌 + 회전 제스처 추가**

기존 `GestureDetector`(단일 터치 드래그)를 유지하면서, `Transform.rotate`와 `ScaleGestureRecognizer`를 통해:
- 핀치: `fontSize` 업데이트 (clamp 12~96)
- 회전: `rotation` 업데이트

선택된 스티커에 외곽선(selection border) 표시.

**변경 요약:**
- `OverlayLayer` 파라미터에 `Duration currentPosition` 추가
- `overlays`를 `visibleOverlays = overlays.where((o) => o.isVisibleAt(currentPosition))`로 필터
- 각 스티커에 `GestureDetector`를 확장하여 `onScaleStart`/`onScaleUpdate` 추가
- `_OverlaySticker` 위젯에 `Transform.rotate(angle: item.rotation, ...)` 적용
- 선택 상태 관리를 위해 `selectedOverlayIdProvider` 추가 (video_editor_provider.dart에)

**Step 3: video_editor_provider.dart에 selectedOverlayIdProvider 추가**

```dart
final selectedOverlayIdProvider =
    StateProvider.autoDispose<String?>((ref) => null);
```

**Step 4: Analyze**

Run: `cd wandeung && flutter analyze`
Expected: No issues found

**Step 5: Commit**

```bash
git add lib/widgets/editor/overlay_layer.dart lib/providers/video_editor_provider.dart
git commit -m "feat: OverlayLayer에 핀치 줌/회전 + 시간 기반 표시 추가"
```

---

## Task 12: VideoEditorScreen을 탭 바 레이아웃으로 변경

**Files:**
- Modify: `lib/screens/video_editor_screen.dart`

**Step 1: 하단 영역을 탭 기반으로 교체**

현재 구조:
```
SpeedSegmentBar
SubtitleTimelineTrack
TrimSlider
하단 툴바 (아이콘 버튼)
```

변경 후:
```
탭별 콘텐츠 영역 (selectedEditorTab에 따라 전환)
EditorTabBar
```

**구체적 변경:**

1. import 추가:
   - `editor_tab_bar.dart`
   - `speed_segment_timeline.dart`
   - `text_multi_track_timeline.dart`
   - `sticker_timeline_track.dart`

2. 기존 하단 영역(`SpeedSegmentBar`, `SubtitleTimelineTrack`, `TrimSlider`, 하단 툴바) 전체를 제거하고 다음으로 교체:

```dart
// ─── 탭별 콘텐츠 ──────────────────────
_buildTabContent(ref),

// ─── 하단 탭 바 ──────────────────────
const EditorTabBar(),
const SizedBox(height: 8),
```

3. `_buildTabContent` 메서드 추가:

```dart
Widget _buildTabContent(WidgetRef ref) {
  final tab = ref.watch(selectedEditorTabProvider);
  switch (tab) {
    case EditorTab.trim:
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            TrimSlider(
              controller: _controller,
              height: 60,
              child: TrimTimeline(
                controller: _controller,
                padding: const EdgeInsets.only(top: 10),
              ),
            ),
          ],
        ),
      );

    case EditorTab.speed:
      return SpeedSegmentTimeline(
        totalDuration: _controller.videoDuration,
        currentPosition: _currentPosition,
        onSplit: () {
          ref.read(speedSegmentsProvider.notifier).splitAt(_currentPosition);
        },
      );

    case EditorTab.text:
      return TextMultiTrackTimeline(
        totalDuration: _controller.videoDuration,
        currentPosition: _currentPosition,
        onAddText: () => _showSubtitleEditor(),
        onEditText: (sub) => _showSubtitleEditor(existingItem: sub),
      );

    case EditorTab.sticker:
      return StickerTimelineTrack(
        totalDuration: _controller.videoDuration,
        currentPosition: _currentPosition,
        onAddSticker: _showOverlayStickers,
      );
  }
}
```

4. `_showOverlayStickers` 메서드 수정: `currentPosition`과 `videoDuration` 전달

```dart
void _showOverlayStickers() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => OverlayStickerSheet(
      currentPosition: _currentPosition,
      videoDuration: _controller.videoDuration,
    ),
  );
}
```

5. `OverlayLayer`에 `currentPosition` 전달:

```dart
OverlayLayer(
  previewSize: videoSize,
  currentPosition: _currentPosition,
),
```

6. 배속 표시 배지 수정: 현재 재생 위치의 속도를 보여주도록

```dart
final currentSpeed = segments
    .where((s) =>
        _currentPosition >= s.start && _currentPosition < s.end)
    .firstOrNull
    ?.speed ?? 1.0;
```

7. 기존 `_ToolbarButton` 클래스와 `_showSpeedPicker` 메서드는 더 이상 사용하지 않으므로 제거

**Step 2: 사용하지 않는 import 정리**

기존 `speed_picker_sheet.dart`, `speed_segment_bar.dart` import 제거 (해당 위젯은 더 이상 직접 사용하지 않음).

**Step 3: Analyze**

Run: `cd wandeung && flutter analyze`
Expected: No issues found

**Step 4: Commit**

```bash
git add lib/screens/video_editor_screen.dart
git commit -m "feat: VideoEditorScreen을 탭 바 레이아웃으로 전환"
```

---

## Task 13: 통합 테스트 및 정리

**Files:**
- All modified files

**Step 1: flutter analyze**

Run: `cd wandeung && flutter analyze`
Expected: No issues found

**Step 2: flutter test**

Run: `cd wandeung && flutter test`
Expected: All tests pass

**Step 3: 사용하지 않는 파일 확인**

- `speed_picker_sheet.dart`: `SpeedSegmentTimeline`이 인라인 속도 버튼을 포함하므로, 더 이상 바텀시트로 사용하지 않음. 단, `SpeedPickerSheet`는 `segmentIndex` 파라미터가 있어 혹시 다른 곳에서 참조할 수 있으니, `flutter analyze`에서 unused import 경고가 나오면 제거.
- `speed_segment_bar.dart`: `SpeedSegmentTimeline`으로 대체됨. unused면 제거.
- `subtitle_timeline_track.dart`: `TextMultiTrackTimeline`으로 대체됨. unused면 제거.

**Step 4: Final commit**

```bash
git add -A
git commit -m "chore: 영상 편집 UX 개선 통합 — 미사용 코드 정리"
```
