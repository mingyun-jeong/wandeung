import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/auth_provider.dart';
import '../providers/record_provider.dart';
import '../widgets/record_card.dart';

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());
final focusedMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

class RecordsTabScreen extends ConsumerWidget {
  const RecordsTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final focusedMonth = ref.watch(focusedMonthProvider);
    final records = ref.watch(recordsByDateProvider(selectedDate));
    final recordDates = ref.watch(recordDatesProvider(focusedMonth));

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '완등',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 22),
            tooltip: '로그아웃',
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 캘린더
          TableCalendar(
            firstDay: DateTime(2020),
            lastDay: DateTime(2030),
            focusedDay: focusedMonth,
            selectedDayPredicate: (day) => isSameDay(day, selectedDate),
            onDaySelected: (selected, focused) {
              ref.read(selectedDateProvider.notifier).state = selected;
              ref.read(focusedMonthProvider.notifier).state = focused;
            },
            onPageChanged: (focused) {
              ref.read(focusedMonthProvider.notifier).state = focused;
            },
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
              markerDecoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              markerSize: 5,
              outsideDaysVisible: false,
              weekendTextStyle: TextStyle(color: colorScheme.error.withOpacity(0.7)),
              defaultTextStyle: const TextStyle(fontSize: 13),
              weekNumberTextStyle: const TextStyle(fontSize: 11),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              leftChevronIcon: Icon(
                Icons.chevron_left_rounded,
                color: colorScheme.onSurface,
              ),
              rightChevronIcon: Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurface,
              ),
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
              final dates = recordDates.valueOrNull ?? {};
              final normalized = DateTime(day.year, day.month, day.day);
              return dates.contains(normalized) ? ['record'] : [];
            },
          ),
          Divider(height: 1, color: colorScheme.outline.withOpacity(0.15)),

          // 선택된 날짜의 기록 목록
          Expanded(
            child: records.when(
              data: (list) => list.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.terrain_outlined,
                            size: 48,
                            color: colorScheme.onSurface.withOpacity(0.2),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '이 날의 등반 기록이 없습니다',
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurface.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: list.length,
                      itemBuilder: (_, i) => RecordCard(record: list[i]),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('오류: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
