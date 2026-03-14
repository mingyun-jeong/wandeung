import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/video_edit_models.dart';

// ─── 배속 구간 관리 ─────────────────────────────────────────

class SpeedSegmentsNotifier extends StateNotifier<List<SpeedSegment>> {
  SpeedSegmentsNotifier() : super([]);

  /// 전체 영상에 단일 배속 적용 (기본값 세팅용)
  void initWithFullRange(Duration videoDuration) {
    state = [
      SpeedSegment(
        start: Duration.zero,
        end: videoDuration,
        speed: 1.0,
      ),
    ];
  }

  /// 구간 추가
  void addSegment(SpeedSegment segment) {
    state = [...state, segment];
  }

  /// 특정 구간의 배속 변경
  void updateSpeed(int index, double speed) {
    if (index < 0 || index >= state.length) return;
    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index) state[i].copyWith(speed: speed) else state[i],
    ];
  }

  /// 구간 삭제
  void removeSegment(int index) {
    if (index < 0 || index >= state.length) return;
    state = [...state]..removeAt(index);
  }

  /// 전체 영상에 균일 배속 적용
  void setUniformSpeed(double speed) {
    if (state.isEmpty) return;
    final start = state.first.start;
    final end = state.last.end;
    state = [SpeedSegment(start: start, end: end, speed: speed)];
  }

  /// 지정 시간 위치에서 구간을 분할
  void splitAt(Duration position) {
    final newSegments = <SpeedSegment>[];
    for (final seg in state) {
      if (position > seg.start && position < seg.end) {
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
  void moveBoundary(int boundaryIndex, Duration newPosition) {
    if (boundaryIndex < 0 || boundaryIndex >= state.length - 1) return;
    final curr = state[boundaryIndex];
    final next = state[boundaryIndex + 1];

    const minDuration = Duration(milliseconds: 200);
    final clampedPos = Duration(
      milliseconds: newPosition.inMilliseconds.clamp(
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

  /// Undo/Redo에서 상태 복원용
  void restoreState(List<SpeedSegment> segments) => state = segments;

  void reset() => state = [];
}

final speedSegmentsProvider = StateNotifierProvider.autoDispose<
    SpeedSegmentsNotifier, List<SpeedSegment>>(
  (ref) => SpeedSegmentsNotifier(),
);

/// 현재 선택된 속도 구간 인덱스 (null이면 없음)
final selectedSpeedSegmentProvider =
    StateProvider.autoDispose<int?>((ref) => null);

// ─── 크롭 줌 구간 관리 ─────────────────────────────────────

class CropSegmentsNotifier extends StateNotifier<List<CropSegment>> {
  CropSegmentsNotifier() : super([]);

  /// 전체 영상에 단일 크롭 구간 (전체 영역) 세팅
  void initWithFullRange(Duration videoDuration) {
    state = [
      CropSegment(
        start: Duration.zero,
        end: videoDuration,
      ),
    ];
  }

  /// 지정 시간 위치에서 구간을 분할
  void splitAt(Duration position) {
    final newSegments = <CropSegment>[];
    for (final seg in state) {
      if (position > seg.start && position < seg.end) {
        newSegments.add(seg.copyWith(end: position));
        newSegments.add(seg.copyWith(start: position, animateTransition: false));
      } else {
        newSegments.add(seg);
      }
    }
    state = newSegments;
  }

  /// 인접 구간 병합 (동일 크롭 영역인 경우)
  void mergeAt(int index) {
    if (index < 0 || index >= state.length - 1) return;
    final curr = state[index];
    final next = state[index + 1];
    final merged = curr.copyWith(end: next.end);
    final newState = <CropSegment>[];
    for (int i = 0; i < state.length; i++) {
      if (i == index) {
        newState.add(merged);
      } else if (i == index + 1) {
        // skip merged segment
      } else {
        newState.add(state[i]);
      }
    }
    state = newState;
  }

  /// 특정 구간의 크롭 영역 수정
  void updateCropRect(int index, Rect newRect) {
    if (index < 0 || index >= state.length) return;
    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index) state[i].copyWith(cropRect: newRect) else state[i],
    ];
  }

  /// 전환 애니메이션 토글
  void toggleAnimation(int index, bool value) {
    if (index < 0 || index >= state.length) return;
    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index)
          state[i].copyWith(animateTransition: value)
        else
          state[i],
    ];
  }

  /// 해당 구간 크롭 초기화 (전체 영역)
  void resetCrop(int index) {
    if (index < 0 || index >= state.length) return;
    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index)
          state[i].copyWith(cropRect: const Rect.fromLTWH(0, 0, 1, 1))
        else
          state[i],
    ];
  }

  /// 구간 경계 이동
  void moveBoundary(int boundaryIndex, Duration newPosition) {
    if (boundaryIndex < 0 || boundaryIndex >= state.length - 1) return;
    final curr = state[boundaryIndex];
    final next = state[boundaryIndex + 1];

    const minDuration = Duration(milliseconds: 200);
    final clampedPos = Duration(
      milliseconds: newPosition.inMilliseconds.clamp(
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

  /// 현재 시점의 크롭 구간 반환
  CropSegment? getCropAt(Duration position) {
    return state
        .where((s) => position >= s.start && position < s.end)
        .firstOrNull;
  }

  /// Undo/Redo에서 상태 복원용
  void restoreState(List<CropSegment> segments) => state = segments;

  void reset() => state = [];
}

final cropSegmentsProvider = StateNotifierProvider.autoDispose<
    CropSegmentsNotifier, List<CropSegment>>(
  (ref) => CropSegmentsNotifier(),
);

/// 현재 선택된 크롭 구간 인덱스 (null이면 없음)
final selectedCropSegmentProvider =
    StateProvider.autoDispose<int?>((ref) => null);

// ─── 오버레이 관리 ──────────────────────────────────────────

class OverlaysNotifier extends StateNotifier<List<OverlayItem>> {
  OverlaysNotifier() : super([]);

  void addOverlay(OverlayItem item) {
    state = [...state, item];
  }

  void updatePosition(String id, Offset position) {
    state = [
      for (final item in state)
        if (item.id == id) item.copyWith(position: position) else item,
    ];
  }

  void updateOverlay(String id, OverlayItem updated) {
    state = [
      for (final item in state) if (item.id == id) updated else item,
    ];
  }

  void removeOverlay(String id) {
    state = state.where((item) => item.id != id).toList();
  }

  /// Undo/Redo에서 상태 복원용
  void restoreState(List<OverlayItem> overlays) => state = overlays;

  void reset() => state = [];
}

final overlaysProvider =
    StateNotifierProvider.autoDispose<OverlaysNotifier, List<OverlayItem>>(
  (ref) => OverlaysNotifier(),
);

// ─── 내보내기 진행률 ────────────────────────────────────────

/// null = 내보내기 중 아님, 0.0~1.0 = 진행률
final exportProgressProvider =
    StateProvider.autoDispose<double?>((ref) => null);

/// 내보내기 상태
enum ExportStatus { exporting, completed, cancelled, error }

final exportStatusProvider =
    StateProvider.autoDispose<ExportStatus>((ref) => ExportStatus.exporting);

// ─── 편집 탭 ─────────────────────────────────────────────

/// 편집 화면 하단 탭
enum EditorTab { trim, speed, zoom, text, sticker }

/// 현재 선택된 편집 탭
final selectedEditorTabProvider =
    StateProvider.autoDispose<EditorTab>((ref) => EditorTab.trim);

/// 현재 선택된 오버레이 스티커 ID (null이면 없음)
final selectedOverlayIdProvider =
    StateProvider.autoDispose<String?>((ref) => null);
