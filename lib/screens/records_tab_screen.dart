import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../app.dart';
import '../models/climbing_record.dart';
import '../providers/record_provider.dart';
import '../utils/constants.dart';
import '../widgets/record_card.dart';
import '../widgets/wandeung_app_bar.dart';

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());
final focusedMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());
final calendarFormatProvider =
    StateProvider<CalendarFormat>((ref) => CalendarFormat.month);


List<ClimbingRecord> _applyFilters(
  List<ClimbingRecord> records,
  String? color,
  String? status,
  String? tag,
  String? gymName,
) {
  if (color == null && status == null && tag == null && gymName == null) {
    return records;
  }
  return records.where((r) {
    if (color != null && r.difficultyColor != color) return false;
    if (status != null && r.status != status) return false;
    if (tag != null && !r.tags.contains(tag)) return false;
    if (gymName != null && r.gymName != gymName) return false;
    return true;
  }).toList();
}


class RecordsTabScreen extends ConsumerStatefulWidget {
  const RecordsTabScreen({super.key});

  @override
  ConsumerState<RecordsTabScreen> createState() => _RecordsTabScreenState();
}

class _RecordsTabScreenState extends ConsumerState<RecordsTabScreen> {
  // PageView는 항상 3페이지: [이전날 | 선택날(1) | 다음날]
  // 가운데(1)에서 시작하고, 스와이프 완료 시 날짜를 바꾸고 다시 가운데로 점프
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _resetFilters(WidgetRef ref) {
    ref.read(selectedColorFilterProvider.notifier).state = null;
    ref.read(selectedStatusFilterProvider.notifier).state = null;
    ref.read(selectedTagFilterProvider.notifier).state = null;
    ref.read(selectedGymFilterProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final selectedDate = ref.watch(selectedDateProvider);
    final focusedMonth = ref.watch(focusedMonthProvider);
    final records = ref.watch(recordsByDateProvider(selectedDate));
    final recordCounts = ref.watch(recordCountsByDateProvider(focusedMonth));
    final selectedColor = ref.watch(selectedColorFilterProvider);
    final selectedStatus = ref.watch(selectedStatusFilterProvider);
    final selectedTag = ref.watch(selectedTagFilterProvider);
    final selectedGym = ref.watch(selectedGymFilterProvider);

    final calendarFormat = ref.watch(calendarFormatProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const WandeungAppBar(),
      body: Column(
        children: [
          const _FilterBar(),
          TableCalendar(
            firstDay: DateTime(2020),
            lastDay: DateTime(2030),
            focusedDay: focusedMonth,
            calendarFormat: calendarFormat,
            availableCalendarFormats: const {
              CalendarFormat.month: '주간',
              CalendarFormat.week: '월간',
            },
            onFormatChanged: (format) {
              ref.read(calendarFormatProvider.notifier).state = format;
            },
            selectedDayPredicate: (day) => isSameDay(day, selectedDate),
            onDaySelected: (selected, focused) {
              ref.read(selectedDateProvider.notifier).state = selected;
              ref.read(focusedMonthProvider.notifier).state = focused;
              _resetFilters(ref);
            },
            onPageChanged: (focused) {
              ref.read(focusedMonthProvider.notifier).state = focused;
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return const SizedBox.shrink();
                final count = events.length;
                final dots = count.clamp(1, 4);
                return Positioned(
                  bottom: 2,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(dots, (i) {
                      return Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: i == 0
                              ? WandeungColors.accent
                              : WandeungColors.accent.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
              selectedDecoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: TextStyle(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
              outsideDaysVisible: false,
              weekendTextStyle: TextStyle(color: colorScheme.error.withOpacity(0.7)),
              defaultTextStyle: const TextStyle(fontSize: 13),
              weekNumberTextStyle: const TextStyle(fontSize: 11),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: true,
              formatButtonShowsNext: true,
              formatButtonDecoration: BoxDecoration(
                border: Border.all(color: colorScheme.outline.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(16),
              ),
              formatButtonTextStyle: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
              titleCentered: true,
              titleTextStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              leftChevronIcon: Icon(Icons.chevron_left_rounded, color: colorScheme.onSurface),
              rightChevronIcon: Icon(Icons.chevron_right_rounded, color: colorScheme.onSurface),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
              weekendStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.error.withOpacity(0.5),
              ),
            ),
            eventLoader: (day) {
              final counts = recordCounts.valueOrNull ?? {};
              final normalized = DateTime(day.year, day.month, day.day);
              final count = counts[normalized] ?? 0;
              return List.generate(count, (i) => i);
            },
          ),
          const Divider(height: 1, color: Color(0xFFE8ECF0)),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: 3,
              onPageChanged: (page) {
                if (page == 1) return;
                final delta = page == 0 ? -1 : 1;
                final newDate = selectedDate.add(Duration(days: delta));
                ref.read(selectedDateProvider.notifier).state = newDate;
                ref.read(focusedMonthProvider.notifier).state = newDate;
                _resetFilters(ref);
                // 날짜 변경 후 가운데 페이지로 즉시 복귀
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _pageController.jumpToPage(1);
                });
              },
              itemBuilder: (context, page) {
                // 가운데 페이지(1)만 실제 데이터 표시, 양쪽은 빈 컨테이너
                if (page != 1) return const SizedBox.shrink();
                return records.when(
                  data: (list) {
                    if (list.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: WandeungColors.accent.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.terrain_outlined,
                                  size: 28,
                                  color: WandeungColors.accent.withOpacity(0.4)),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '이 날의 등반 기록이 없습니다',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: WandeungColors.textSecondary),
                            ),
                          ],
                        ),
                      );
                    }

                    final filtered = _applyFilters(
                        list, selectedColor, selectedStatus, selectedTag, selectedGym);
                    final hasActiveFilters = selectedColor != null ||
                        selectedStatus != null ||
                        selectedTag != null ||
                        selectedGym != null;
                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.filter_list_off_rounded,
                                size: 40,
                                color: colorScheme.onSurface
                                    .withOpacity(0.2)),
                            const SizedBox(height: 10),
                            Text(
                              '필터 조건에 맞는 기록이 없습니다',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.onSurface
                                      .withOpacity(0.4)),
                            ),
                            if (hasActiveFilters) ...[
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () => _resetFilters(ref),
                                child: const Text('필터 초기화'),
                              ),
                            ],
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) =>
                          RecordCard(record: filtered[i]),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('오류: $e')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 필터 바 ───────────────────────────────────────────────────────────────────

class _FilterBar extends ConsumerWidget {
  const _FilterBar();

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
          color: isActive ? colorScheme.primaryContainer : Colors.transparent,
          border: Border.all(
            color: isActive ? colorScheme.primary : colorScheme.outline.withOpacity(0.4),
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
                  ? colorScheme.onPrimaryContainer
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
          ? colorScheme.onPrimaryContainer
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
