import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../app.dart';
import '../models/climbing_record.dart';
import '../providers/camera_settings_provider.dart';
import '../providers/record_provider.dart';
import '../widgets/record_card.dart';
import '../widgets/record_filter_bar.dart';
import '../widgets/reclim_app_bar.dart';

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());
final focusedMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());
final calendarFormatProvider =
    StateProvider<CalendarFormat>((ref) => CalendarFormat.week);


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


class RecordsTabScreen extends ConsumerWidget {
  const RecordsTabScreen({super.key});

  void _resetFilters(WidgetRef ref) {
    ref.read(selectedColorFilterProvider.notifier).state = null;
    ref.read(selectedStatusFilterProvider.notifier).state = null;
    ref.read(selectedTagFilterProvider.notifier).state = null;
    ref.read(selectedGymFilterProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      appBar: const ReclimAppBar(),
      body: Column(
        children: [
          const RecordFilterBar(),
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
            },
            onPageChanged: (focused) {
              ref.read(focusedMonthProvider.notifier).state = focused;
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return const SizedBox.shrink();
                final count = events.length;
                return Positioned(
                  bottom: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: ReclimColors.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(minWidth: 16),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
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
            child: records.when(
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
                            color: ReclimColors.accent.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.terrain_outlined,
                              size: 28,
                              color: ReclimColors.accent.withOpacity(0.4)),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '이 날의 등반 기록이 없습니다',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: ReclimColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () {
                            ref.read(bottomNavIndexProvider.notifier).state = 2;
                          },
                          icon: const Icon(Icons.videocam_rounded, size: 18),
                          label: const Text('촬영하러 가기'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          ),
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
                        const Icon(Icons.filter_list_off_rounded,
                            size: 40,
                            color: ReclimColors.textTertiary),
                        const SizedBox(height: 10),
                        const Text(
                          '필터 조건에 맞는 기록이 없습니다',
                          style: TextStyle(
                              fontSize: 14,
                              color: ReclimColors.textTertiary),
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
            ),
          ),
        ],
      ),
    );
  }
}

