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

  void reset() => state = [];
}

final speedSegmentsProvider = StateNotifierProvider.autoDispose<
    SpeedSegmentsNotifier, List<SpeedSegment>>(
  (ref) => SpeedSegmentsNotifier(),
);

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
