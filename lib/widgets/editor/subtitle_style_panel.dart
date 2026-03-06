import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../models/subtitle_item.dart';
import '../../services/custom_font_service.dart';

class SubtitleStylePanel extends StatefulWidget {
  final SubtitleItem item;
  final ValueChanged<SubtitleItem> onChanged;

  const SubtitleStylePanel({
    super.key,
    required this.item,
    required this.onChanged,
  });

  @override
  State<SubtitleStylePanel> createState() => _SubtitleStylePanelState();
}

class _SubtitleStylePanelState extends State<SubtitleStylePanel> {
  late SubtitleItem _current;
  List<CustomFont> _customFonts = [];

  static const _colorOptions = [
    Color(0xFFFFFFFF), Color(0xFF000000), Color(0xFFFF0000),
    Color(0xFF0000FF), Color(0xFF00FF00), Color(0xFFFFFF00),
    Color(0xFFFF8800), Color(0xFF8800FF), Color(0xFFFF00FF),
  ];

  @override
  void initState() {
    super.initState();
    _current = widget.item;
    _loadCustomFonts();
  }

  @override
  void didUpdateWidget(SubtitleStylePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item != widget.item) {
      _current = widget.item;
    }
  }

  Future<void> _loadCustomFonts() async {
    final fonts = await CustomFontService.loadCustomFonts();
    if (mounted) setState(() => _customFonts = fonts);
  }

  void _update(SubtitleItem updated) {
    setState(() => _current = updated);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 폰트 선택
        const Text('폰트', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...CustomFontService.defaultFonts.map((f) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.name),
                      selected: _current.fontFamily == f.filePath,
                      onSelected: (_) =>
                          _update(_current.copyWith(fontFamily: f.filePath)),
                    ),
                  )),
              ..._customFonts.map((f) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.name),
                      selected: _current.fontFamily == f.filePath,
                      onSelected: (_) =>
                          _update(_current.copyWith(fontFamily: f.filePath)),
                    ),
                  )),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('추가'),
                onPressed: _importFont,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 사이즈
        Row(
          children: [
            const Text('크기', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Text('${_current.fontSize.round()}'),
          ],
        ),
        Slider(
          value: _current.fontSize,
          min: 12,
          max: 72,
          onChanged: (v) => _update(_current.copyWith(fontSize: v)),
        ),

        // 텍스트 색상
        const Text('텍스트 색상', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _buildColorRow(_current.color, (c) => _update(_current.copyWith(color: c))),
        const SizedBox(height: 16),

        // 외곽선
        Row(
          children: [
            const Text('외곽선', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Text('${_current.strokeWidth.round()}'),
          ],
        ),
        Slider(
          value: _current.strokeWidth,
          min: 0,
          max: 5,
          divisions: 5,
          onChanged: (v) => _update(_current.copyWith(
            strokeWidth: v,
            strokeColor:
                v > 0 ? (_current.strokeColor ?? const Color(0xFF000000)) : null,
            clearStroke: v == 0,
          )),
        ),
        if (_current.strokeWidth > 0) ...[
          const Text('외곽선 색상'),
          const SizedBox(height: 4),
          _buildColorRow(
              _current.strokeColor ?? const Color(0xFF000000),
              (c) => _update(_current.copyWith(strokeColor: c))),
          const SizedBox(height: 12),
        ],

        // 배경
        SwitchListTile(
          title: const Text('배경'),
          value: _current.backgroundColor != null,
          contentPadding: EdgeInsets.zero,
          onChanged: (v) {
            if (v) {
              _update(
                  _current.copyWith(backgroundColor: const Color(0xFF000000)));
            } else {
              _update(_current.copyWith(clearBackground: true));
            }
          },
        ),
        if (_current.backgroundColor != null) ...[
          _buildColorRow(
              _current.backgroundColor!,
              (c) => _update(_current.copyWith(backgroundColor: c))),
          const SizedBox(height: 12),
        ],

        // 기울기 (회전)
        Row(
          children: [
            const Text('기울기', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Text('${(_current.rotation * 180 / math.pi).round()}°'),
            if (_current.rotation != 0.0) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _update(_current.copyWith(rotation: 0.0)),
                child: const Icon(Icons.replay, size: 16),
              ),
            ],
          ],
        ),
        Slider(
          value: _current.rotation,
          min: -math.pi / 4, // -45°
          max: math.pi / 4,  // +45°
          onChanged: (v) => _update(_current.copyWith(rotation: v)),
        ),

        // 굵기 & 그림자
        Row(
          children: [
            FilterChip(
              label: const Text('굵게'),
              selected: _current.isBold,
              onSelected: (v) => _update(_current.copyWith(isBold: v)),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('그림자'),
              selected: _current.hasShadow,
              onSelected: (v) => _update(_current.copyWith(hasShadow: v)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildColorRow(Color selected, ValueChanged<Color> onSelect) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _colorOptions
          .map((c) => GestureDetector(
                onTap: () => onSelect(c),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected == c
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300,
                      width: selected == c ? 3 : 1,
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Future<void> _importFont() async {
    final font = await CustomFontService.importFont();
    if (font != null) {
      await _loadCustomFonts();
      _update(_current.copyWith(fontFamily: font.filePath));
    }
  }
}
