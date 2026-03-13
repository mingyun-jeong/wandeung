import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/video_edit_models.dart';
import '../../providers/camera_settings_provider.dart';
import '../../providers/video_editor_provider.dart';
import '../../utils/constants.dart';

/// V-Grade 스티커 + 이모지를 추가하는 바텀시트
class OverlayStickerSheet extends ConsumerStatefulWidget {
  final Duration currentPosition;
  final Duration videoDuration;

  const OverlayStickerSheet({
    super.key,
    required this.currentPosition,
    required this.videoDuration,
  });

  @override
  ConsumerState<OverlayStickerSheet> createState() =>
      _OverlayStickerSheetState();
}

class _OverlayStickerSheetState extends ConsumerState<OverlayStickerSheet> {
  ClimbingGrade _selectedGrade = ClimbingGrade.v1;
  DifficultyColor _selectedColor = DifficultyColor.blue;

  static const _emojiCategories = {
    '클라이밍': ['🧗', '💪', '🔥', '⛰️', '🏔️', '🪨', '🎯', '👏', '🧗‍♂️', '🧗‍♀️'],
    '감정': ['😆', '😤', '🥲', '😎', '🤯', '🫣', '😱', '🥳', '😮‍💨', '🫠'],
    '기타': ['⭐', '❤️', '✨', '🎉', '👍', '💯', '🏆', '🥇', '💥', '🔔'],
  };

  @override
  void initState() {
    super.initState();
    // 카메라 설정에서 기본 등급/색상 가져오기
    final settings = ref.read(cameraSettingsProvider);
    if (settings.grade != null) _selectedGrade = settings.grade!;
    if (settings.color != null) _selectedColor = settings.color!;
  }

  Duration get _stickerStartTime => widget.currentPosition;
  Duration get _stickerEndTime {
    final end = widget.currentPosition + const Duration(seconds: 3);
    return end > widget.videoDuration ? widget.videoDuration : end;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '스티커 추가',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 탭 바
            const TabBar(
              tabs: [
                Tab(text: '등급'),
                Tab(text: '이모지'),
              ],
            ),
            const SizedBox(height: 12),

            // 탭 콘텐츠
            SizedBox(
              height: 320,
              child: TabBarView(
                children: [
                  _buildGradeTab(),
                  _buildEmojiTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradeTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 등급 선택
          const Text('등급', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<ClimbingGrade>(
            value: _selectedGrade,
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: ClimbingGrade.values.map((grade) {
              return DropdownMenuItem(
                value: grade,
                child: Text(grade.label),
              );
            }).toList(),
            onChanged: (grade) {
              if (grade != null) setState(() => _selectedGrade = grade);
            },
          ),
          const SizedBox(height: 16),

          // 색상 선택
          const Text('색상', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DifficultyColor.values.map((color) {
              final isSelected = color == _selectedColor;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = color),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(color.colorValue),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // 미리보기
          Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Color(_selectedColor.colorValue),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Color(_selectedColor.colorValue).withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                _selectedGrade.label,
                style: TextStyle(
                  color: _selectedColor == DifficultyColor.white
                      ? Colors.black87
                      : Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 추가 버튼
          SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _addGradeSticker,
                child: const Text('추가'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _emojiCategories.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.key,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: entry.value.map((emoji) {
                  return GestureDetector(
                    onTap: () => _addEmojiSticker(emoji),
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _addGradeSticker() {
    final overlay = OverlayItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: _selectedGrade.label,
      position: const Offset(0.5, 0.3),
      fontSize: 24.0,
      color: _selectedColor == DifficultyColor.white
          ? Colors.black87
          : Colors.white,
      backgroundColor: Color(_selectedColor.colorValue),
      startTime: _stickerStartTime,
      endTime: _stickerEndTime,
    );

    ref.read(overlaysProvider.notifier).addOverlay(overlay);
    Navigator.pop(context);
  }

  void _addEmojiSticker(String emoji) {
    final overlay = OverlayItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: emoji,
      position: const Offset(0.5, 0.3),
      fontSize: 48.0,
      color: Colors.white,
      startTime: _stickerStartTime,
      endTime: _stickerEndTime,
    );

    ref.read(overlaysProvider.notifier).addOverlay(overlay);
    Navigator.pop(context);
  }
}
