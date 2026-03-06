import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/subtitle_item.dart';
import '../../providers/subtitle_provider.dart';
import 'subtitle_style_panel.dart';

/// 자막 추가/편집 바텀시트
class SubtitleEditorSheet extends ConsumerStatefulWidget {
  final Duration currentPosition;
  final Duration videoDuration;
  final SubtitleItem? existingItem;

  const SubtitleEditorSheet({
    super.key,
    required this.currentPosition,
    required this.videoDuration,
    this.existingItem,
  });

  @override
  ConsumerState<SubtitleEditorSheet> createState() =>
      _SubtitleEditorSheetState();
}

class _SubtitleEditorSheetState extends ConsumerState<SubtitleEditorSheet> {
  late TextEditingController _textController;
  late SubtitleItem _item;

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      _item = widget.existingItem!;
      _textController = TextEditingController(text: _item.text);
    } else {
      final start = widget.currentPosition;
      var end = start + const Duration(seconds: 3);
      if (end > widget.videoDuration) end = widget.videoDuration;
      _item = SubtitleItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: '',
        startTime: start,
        endTime: end,
      );
      _textController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final ms = (d.inMilliseconds.remainder(1000) ~/ 100).toString();
    return '$m:$s.$ms';
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingItem != null;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // 핸들
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // 헤더
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Text 편집' : 'Text 추가',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // 텍스트 입력
                  TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      labelText: 'Text',
                      hintText: '텍스트를 입력하세요',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    onChanged: (v) => setState(() {
                      _item = _item.copyWith(text: v);
                    }),
                  ),
                  const SizedBox(height: 16),

                  // 시간 설정
                  const Text('시간 구간',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _TimePickerField(
                          label: '시작',
                          value: _item.startTime,
                          max: _item.endTime,
                          onChanged: (d) =>
                              setState(() => _item = _item.copyWith(startTime: d)),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('~'),
                      ),
                      Expanded(
                        child: _TimePickerField(
                          label: '끝',
                          value: _item.endTime,
                          min: _item.startTime,
                          max: widget.videoDuration,
                          onChanged: (d) =>
                              setState(() => _item = _item.copyWith(endTime: d)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_formatDuration(_item.startTime)} ~ ${_formatDuration(_item.endTime)} (${((_item.endTime - _item.startTime).inMilliseconds / 1000).toStringAsFixed(1)}초)',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 20),

                  // 스타일 패널
                  SubtitleStylePanel(
                    item: _item,
                    onChanged: (updated) => setState(() => _item = updated),
                  ),
                  const SizedBox(height: 20),

                  // 미리보기
                  const Text('미리보기',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Transform.rotate(
                        angle: _item.rotation,
                        child: _SubtitlePreview(item: _item),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // 하단 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _item.text.trim().isEmpty ? null : _save,
                  child: Text(isEditing ? '수정' : '추가'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final finalItem = _item.copyWith(text: _textController.text.trim());
    if (widget.existingItem != null) {
      ref
          .read(subtitlesProvider.notifier)
          .updateSubtitle(finalItem.id, finalItem);
    } else {
      ref.read(subtitlesProvider.notifier).addSubtitle(finalItem);
    }
    Navigator.pop(context);
  }
}

/// 시간 입력 필드 (+/- 0.5초 단위)
class _TimePickerField extends StatelessWidget {
  final String label;
  final Duration value;
  final Duration? min;
  final Duration? max;
  final ValueChanged<Duration> onChanged;

  const _TimePickerField({
    required this.label,
    required this.value,
    this.min,
    this.max,
    required this.onChanged,
  });

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final ms = (d.inMilliseconds.remainder(1000) ~/ 100).toString();
    return '$m:$s.$ms';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove, size: 20),
          onPressed: () {
            final next = value - const Duration(milliseconds: 500);
            final minVal = min ?? Duration.zero;
            if (next >= minVal) onChanged(next);
          },
        ),
        Expanded(
          child: Text(
            '$label: ${_format(value)}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add, size: 20),
          onPressed: () {
            final next = value + const Duration(milliseconds: 500);
            if (max == null || next <= max!) onChanged(next);
          },
        ),
      ],
    );
  }
}

/// 미리보기 위젯
class _SubtitlePreview extends StatelessWidget {
  final SubtitleItem item;
  const _SubtitlePreview({required this.item});

  @override
  Widget build(BuildContext context) {
    Widget text = Text(
      item.text.isEmpty ? 'Text 미리보기' : item.text,
      style: TextStyle(
        fontSize: item.fontSize,
        color: item.color,
        fontWeight: item.isBold ? FontWeight.w800 : FontWeight.normal,
        shadows: item.hasShadow
            ? [
                const Shadow(
                  color: Color(0x80000000),
                  offset: Offset(2, 2),
                  blurRadius: 4,
                ),
              ]
            : null,
      ),
    );

    if (item.strokeColor != null && item.strokeWidth > 0) {
      text = Stack(
        children: [
          Text(
            item.text.isEmpty ? 'Text 미리보기' : item.text,
            style: TextStyle(
              fontSize: item.fontSize,
              fontWeight: item.isBold ? FontWeight.w800 : FontWeight.normal,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = item.strokeWidth * 2
                ..color = item.strokeColor!,
            ),
          ),
          text,
        ],
      );
    }

    if (item.backgroundColor != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: item.backgroundColor!.withOpacity(0.6),
          borderRadius: BorderRadius.circular(4),
        ),
        child: text,
      );
    }

    return text;
  }
}
