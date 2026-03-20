import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app.dart';
import '../providers/record_provider.dart';
import '../utils/constants.dart';

class RecordFilterBar extends ConsumerWidget {
  const RecordFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedColor = ref.watch(selectedColorFilterProvider);
    final selectedStatus = ref.watch(selectedStatusFilterProvider);
    final selectedTag = ref.watch(selectedTagFilterProvider);
    final selectedGym = ref.watch(selectedGymFilterProvider);

    final visitedGymsAsync = ref.watch(userVisitedGymsProvider);
    final visitedGyms = visitedGymsAsync.valueOrNull ?? [];

    final allTagsAsync = ref.watch(userAllTagsProvider);
    final allTags = allTagsAsync.valueOrNull ?? [];

    final activeDc = selectedColor != null
        ? DifficultyColor.values.firstWhere((c) => c.name == selectedColor)
        : null;

    final boxes = <Widget>[
      _SelectBox(
        label: '암장',
        selectedValue: selectedGym,
        selectedDisplay: selectedGym,
        items: visitedGyms
            .map((g) => _SelectItem(value: g, child: Text(g)))
            .toList(),
        onChanged: (v) =>
            ref.read(selectedGymFilterProvider.notifier).state = v,
      ),
      _SelectBox(
        label: '상태',
        selectedValue: selectedStatus,
        selectedDisplay: selectedStatus != null
            ? ClimbingStatus.values.firstWhere((s) => s.name == selectedStatus).label
            : null,
        items: ClimbingStatus.values
            .map((s) => _SelectItem(value: s.name, child: Text(s.label)))
            .toList(),
        onChanged: (v) => ref.read(selectedStatusFilterProvider.notifier).state = v,
      ),
      _SelectBox(
        label: '난이도',
        selectedValue: selectedColor,
        selectedDisplay: activeDc?.korean,
        selectedLeading: activeDc != null ? _ColorDot(activeDc) : null,
        items: DifficultyColor.values
            .map((dc) => _SelectItem(
                  value: dc.name,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _ColorDot(dc),
                    const SizedBox(width: 8),
                    Text(dc.korean),
                  ]),
                ))
            .toList(),
        onChanged: (v) =>
            ref.read(selectedColorFilterProvider.notifier).state = v,
      ),
    ];

    boxes.add(_SelectBox(
      label: '태그',
      selectedValue: selectedTag,
      selectedDisplay: selectedTag,
      items: allTags
          .map((t) => _SelectItem(value: t, child: Text(t)))
          .toList(),
      onChanged: (v) => ref.read(selectedTagFilterProvider.notifier).state = v,
    ));

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...boxes.expand((b) => [b, const SizedBox(width: 8)]),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Select Box ───────────────────────────────────────────────────────────────

class _SelectItem {
  final String value;
  final Widget child;
  const _SelectItem({required this.value, required this.child});
}

class _SelectBox extends StatelessWidget {
  final String label;
  final String? selectedValue;
  final String? selectedDisplay;
  final Widget? selectedLeading;
  final List<_SelectItem> items;
  final ValueChanged<String?> onChanged;

  const _SelectBox({
    required this.label,
    required this.selectedValue,
    required this.selectedDisplay,
    this.selectedLeading,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = selectedValue != null;
    final colorScheme = Theme.of(context).colorScheme;

    // PopupMenuButton은 value=null인 항목을 선택해도 onSelected를 호출하지 않으므로
    // '__clear__' 센티넬 값을 사용해 "전체" 선택을 처리한다.
    const clearSentinel = '__clear__';

    return PopupMenuButton<String>(
      onSelected: (v) => onChanged(v == clearSentinel ? null : v),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: clearSentinel,
          child: Row(children: [
            SizedBox(
              width: 20,
              child: !isActive
                  ? Icon(Icons.check_rounded, size: 16, color: colorScheme.primary)
                  : null,
            ),
            const SizedBox(width: 4),
            Text('전체', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7))),
          ]),
        ),
        const PopupMenuDivider(height: 1),
        ...items.map((item) => PopupMenuItem<String>(
              value: item.value,
              child: Row(children: [
                SizedBox(
                  width: 20,
                  child: item.value == selectedValue
                      ? Icon(Icons.check_rounded, size: 16, color: colorScheme.primary)
                      : null,
                ),
                const SizedBox(width: 4),
                item.child,
              ]),
            )),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? ClimpickColors.accent.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isActive ? ClimpickColors.accent : colorScheme.outline.withOpacity(0.4),
            width: isActive ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive && selectedLeading != null) ...[
              selectedLeading!,
              const SizedBox(width: 6),
            ],
            _buildLabel(context, isActive, colorScheme),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: isActive
                  ? ClimpickColors.accent
                  : colorScheme.onSurface.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(BuildContext context, bool isActive, ColorScheme colorScheme) {
    final text = isActive ? selectedDisplay! : label;
    final style = TextStyle(
      fontSize: 13,
      color: isActive
          ? ClimpickColors.accent
          : colorScheme.onSurface.withOpacity(0.75),
      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
    );

    if (isActive && text.length > 7) {
      return SizedBox(
        width: 7 * style.fontSize! * 0.65,
        height: style.fontSize! * 1.4,
        child: _MarqueeText(text: text, style: style),
      );
    }

    return Text(text, style: style);
  }
}

class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _MarqueeText({required this.text, required this.style});

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _textWidth = 0;
  double _containerWidth = 0;
  final _textKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    final box = _textKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    _textWidth = box.size.width;
    _containerWidth = (context.findRenderObject() as RenderBox).size.width;
    if (_textWidth <= _containerWidth) return;

    final totalScroll = _textWidth + 40; // 40 = gap between repeated text
    _controller.duration =
        Duration(milliseconds: (totalScroll * 30).toInt());
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gap = 40.0;
    return ClipRect(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final offset = _controller.value * (_textWidth + gap);
          return Stack(
            children: [
              Transform.translate(
                offset: Offset(-offset, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(key: _textKey, widget.text,
                        style: widget.style, maxLines: 1),
                    const SizedBox(width: gap),
                    Text(widget.text, style: widget.style, maxLines: 1),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final DifficultyColor dc;
  const _ColorDot(this.dc);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: Color(dc.colorValue),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withOpacity(0.15), width: 0.5),
      ),
    );
  }
}
