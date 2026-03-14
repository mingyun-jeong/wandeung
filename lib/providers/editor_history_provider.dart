import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/subtitle_item.dart';
import '../models/video_edit_models.dart';
import 'subtitle_provider.dart';
import 'video_editor_provider.dart';

/// 편집 상태 스냅샷
class EditorSnapshot {
  final List<SpeedSegment> speedSegments;
  final List<SubtitleItem> subtitles;
  final List<OverlayItem> overlays;
  final List<CropSegment> cropSegments;

  const EditorSnapshot({
    required this.speedSegments,
    required this.subtitles,
    required this.overlays,
    required this.cropSegments,
  });
}

/// Undo/Redo 가능 여부를 노출하는 상태
class EditorHistoryState {
  final bool canUndo;
  final bool canRedo;

  const EditorHistoryState({this.canUndo = false, this.canRedo = false});
}

class EditorHistoryNotifier extends StateNotifier<EditorHistoryState> {
  final Ref _ref;
  final List<EditorSnapshot> _undoStack = [];
  final List<EditorSnapshot> _redoStack = [];
  static const _maxHistory = 30;

  EditorHistoryNotifier(this._ref) : super(const EditorHistoryState());

  /// 현재 상태를 스냅샷으로 저장 (편집 동작 직전에 호출)
  void saveSnapshot() {
    final snapshot = EditorSnapshot(
      speedSegments: List.unmodifiable(_ref.read(speedSegmentsProvider)),
      subtitles: List.unmodifiable(_ref.read(subtitlesProvider)),
      overlays: List.unmodifiable(_ref.read(overlaysProvider)),
      cropSegments: List.unmodifiable(_ref.read(cropSegmentsProvider)),
    );
    _undoStack.add(snapshot);
    if (_undoStack.length > _maxHistory) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
    _updateState();
  }

  /// 마지막 편집을 되돌리기
  void undo() {
    if (_undoStack.isEmpty) return;

    // 현재 상태를 redo 스택에 저장
    _redoStack.add(_currentSnapshot());

    // 이전 상태 복원
    final snapshot = _undoStack.removeLast();
    _restoreSnapshot(snapshot);
    _updateState();
  }

  /// 되돌린 편집을 다시 적용
  void redo() {
    if (_redoStack.isEmpty) return;

    // 현재 상태를 undo 스택에 저장
    _undoStack.add(_currentSnapshot());

    // 다음 상태 복원
    final snapshot = _redoStack.removeLast();
    _restoreSnapshot(snapshot);
    _updateState();
  }

  EditorSnapshot _currentSnapshot() {
    return EditorSnapshot(
      speedSegments: List.unmodifiable(_ref.read(speedSegmentsProvider)),
      subtitles: List.unmodifiable(_ref.read(subtitlesProvider)),
      overlays: List.unmodifiable(_ref.read(overlaysProvider)),
      cropSegments: List.unmodifiable(_ref.read(cropSegmentsProvider)),
    );
  }

  void _restoreSnapshot(EditorSnapshot snapshot) {
    _ref.read(speedSegmentsProvider.notifier).restoreState(
          snapshot.speedSegments,
        );
    _ref.read(subtitlesProvider.notifier).restoreState(snapshot.subtitles);
    _ref.read(overlaysProvider.notifier).restoreState(snapshot.overlays);
    _ref.read(cropSegmentsProvider.notifier).restoreState(snapshot.cropSegments);
  }

  void _updateState() {
    state = EditorHistoryState(
      canUndo: _undoStack.isNotEmpty,
      canRedo: _redoStack.isNotEmpty,
    );
  }
}

final editorHistoryProvider =
    StateNotifierProvider.autoDispose<EditorHistoryNotifier, EditorHistoryState>(
  (ref) => EditorHistoryNotifier(ref),
);
