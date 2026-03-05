import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/video_edit_models.dart';
import '../../providers/camera_settings_provider.dart';
import '../../providers/video_editor_provider.dart';
import '../../utils/constants.dart';

/// V-Grade 스티커를 추가하는 바텀시트
class OverlayStickerSheet extends ConsumerStatefulWidget {
  const OverlayStickerSheet({super.key});

  @override
  ConsumerState<OverlayStickerSheet> createState() =>
      _OverlayStickerSheetState();
}

class _OverlayStickerSheetState extends ConsumerState<OverlayStickerSheet> {
  ClimbingGrade _selectedGrade = ClimbingGrade.v1;
  DifficultyColor _selectedColor = DifficultyColor.blue;

  @override
  void initState() {
    super.initState();
    // 카메라 설정에서 기본 등급/색상 가져오기
    final settings = ref.read(cameraSettingsProvider);
    if (settings.grade != null) _selectedGrade = settings.grade!;
    if (settings.color != null) _selectedColor = settings.color!;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '등급 스티커 추가',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 등급 선택
          const Text('등급', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ClimbingGrade.values.map((grade) {
              final isSelected = grade == _selectedGrade;
              return ChoiceChip(
                label: Text(grade.label),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedGrade = grade),
              );
            }).toList(),
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
          const SizedBox(height: 20),

          // 추가 버튼
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _addSticker,
              child: const Text('추가'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _addSticker() {
    final overlay = OverlayItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: _selectedGrade.label,
      position: const Offset(0.5, 0.3), // 화면 중앙 상단
      fontSize: 24.0,
      color: _selectedColor == DifficultyColor.white
          ? Colors.black87
          : Colors.white,
      backgroundColor: Color(_selectedColor.colorValue),
    );

    ref.read(overlaysProvider.notifier).addOverlay(overlay);
    Navigator.pop(context);
  }
}
