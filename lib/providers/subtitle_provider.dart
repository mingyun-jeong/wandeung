import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subtitle_item.dart';

class SubtitlesNotifier extends StateNotifier<List<SubtitleItem>> {
  SubtitlesNotifier() : super([]);

  void addSubtitle(SubtitleItem item) {
    state = [...state, item];
  }

  void updateSubtitle(String id, SubtitleItem updated) {
    state = [
      for (final item in state) if (item.id == id) updated else item,
    ];
  }

  void removeSubtitle(String id) {
    state = state.where((item) => item.id != id).toList();
  }

  void updatePosition(String id, Offset position) {
    state = [
      for (final item in state)
        if (item.id == id) item.copyWith(position: position) else item,
    ];
  }

  void reset() => state = [];
}

final subtitlesProvider = StateNotifierProvider.autoDispose<SubtitlesNotifier,
    List<SubtitleItem>>(
  (ref) => SubtitlesNotifier(),
);

/// 현재 선택된 자막 ID (편집 중)
final selectedSubtitleIdProvider =
    StateProvider.autoDispose<String?>((ref) => null);
