import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../app.dart';
import '../config/supabase_config.dart';
import '../models/climbing_gym.dart';
import '../models/gym_setting_schedule.dart';
import '../providers/favorite_gym_provider.dart';
import '../providers/gym_provider.dart';
import '../providers/setting_schedule_provider.dart';
import '../utils/constants.dart';
import '../widgets/reclim_app_bar.dart';
import 'setting_schedule_detail_screen.dart';

class SettingScheduleTabScreen extends ConsumerStatefulWidget {
  const SettingScheduleTabScreen({super.key});

  @override
  ConsumerState<SettingScheduleTabScreen> createState() =>
      _SettingScheduleTabScreenState();
}

class _SettingScheduleTabScreenState
    extends ConsumerState<SettingScheduleTabScreen> {
  final _searchController = TextEditingController();
  bool _showSearchResults = false;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _yearMonthStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}';

  /// 즐겨찾기 암장 선택 (DB id가 이미 있으므로 바로 설정)
  void _selectFavoriteGym(ClimbingGym gym) {
    ref.read(settingGymFilterProvider.notifier).state = gym.id;
    ref.read(settingGymFilterNameProvider.notifier).state = gym.name;
  }

  /// 검색 결과에서 암장 선택 (Google Places → DB 조회 필요)
  void _selectSearchGym(ClimbingGym gym) {
    _findAndSetGymFilter(gym);
    _searchController.text = gym.name;
    setState(() => _showSearchResults = false);
    FocusScope.of(context).unfocus();
  }

  Future<void> _findAndSetGymFilter(ClimbingGym gym) async {
    if (gym.googlePlaceId != null) {
      final existing = await SupabaseConfig.client
          .from('climbing_gyms')
          .select('id')
          .eq('google_place_id', gym.googlePlaceId!)
          .maybeSingle();

      if (existing != null) {
        ref.read(settingGymFilterProvider.notifier).state =
            existing['id'] as String;
        ref.read(settingGymFilterNameProvider.notifier).state = gym.name;
        return;
      }
    }

    ref.read(settingGymFilterProvider.notifier).state = '__not_found__';
    ref.read(settingGymFilterNameProvider.notifier).state = gym.name;
  }

  void _clearGymFilter() {
    ref.read(settingGymFilterProvider.notifier).state = null;
    ref.read(settingGymFilterNameProvider.notifier).state = null;
    _searchController.clear();
    setState(() => _showSearchResults = false);
  }

  @override
  Widget build(BuildContext context) {
    final gymFilter = ref.watch(settingGymFilterProvider);
    final focusedMonth = ref.watch(settingFocusedMonthProvider);
    final selectedDate = ref.watch(settingSelectedDateProvider);
    final yearMonth = _yearMonthStr(focusedMonth);

    return Scaffold(
      appBar: const ReclimAppBar(),
      body: Column(
        children: [
          // ─── 타이틀 + Beta 뱃지 ───
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                const Text(
                  '세팅일정',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: ReclimColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: ReclimColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Beta',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: ReclimColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── 암장 검색 바 ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '암장 검색...',
                hintStyle: const TextStyle(
                  color: ReclimColors.textTertiary,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: gymFilter != null
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: _clearGymFilter,
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: ReclimColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: ReclimColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: ReclimColors.accent, width: 1.5),
                ),
              ),
              onChanged: (query) {
                if (query.isNotEmpty) {
                  ref.read(searchQueryProvider.notifier).state = query;
                  setState(() => _showSearchResults = true);
                } else {
                  setState(() => _showSearchResults = false);
                }
              },
              onSubmitted: (_) =>
                  setState(() => _showSearchResults = false),
            ),
          ),

          // ─── 검색 결과 드롭다운 ───
          if (_showSearchResults) _buildSearchResults(),

          // ─── 기본: 내 암장 목록 ───
          if (!_showSearchResults && gymFilter == null) _buildFavoriteGymList(),

          // ─── 암장 선택됨: 캘린더 + 목록 ───
          if (!_showSearchResults && gymFilter != null)
            Expanded(
              child: Column(
                children: [
                  _buildCalendar(
                    focusedMonth,
                    selectedDate,
                    ref.watch(settingSchedulesProvider(yearMonth)),
                  ),
                  const Divider(height: 1, color: ReclimColors.border),
                  Expanded(
                    child: _buildScheduleList(
                      selectedDate,
                      ref.watch(settingSchedulesProvider(yearMonth)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 내 암장 목록
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFavoriteGymList() {
    final favoriteGymsAsync = ref.watch(favoriteGymsProvider);
    return Expanded(
      child: favoriteGymsAsync.when(
        data: (gyms) {
          if (gyms.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search,
                      size: 40,
                      color: ReclimColors.textTertiary.withOpacity(0.5)),
                  const SizedBox(height: 12),
                  const Text(
                    '암장을 검색해서 세팅일정을 확인하세요',
                    style: TextStyle(
                      fontSize: 14,
                      color: ReclimColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: gyms.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    '내 암장',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: ReclimColors.textPrimary,
                    ),
                  ),
                );
              }
              final gym = gyms[i - 1];
              return ListTile(
                leading: const Icon(Icons.location_on_outlined,
                    color: ReclimColors.accent),
                title: Text(gym.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: gym.address != null
                    ? Text(gym.address!,
                        style: const TextStyle(
                            fontSize: 12,
                            color: ReclimColors.textTertiary),
                        overflow: TextOverflow.ellipsis)
                    : null,
                trailing: const Icon(Icons.chevron_right,
                    size: 18, color: ReclimColors.textTertiary),
                onTap: () => _selectFavoriteGym(gym),
                contentPadding: EdgeInsets.zero,
                dense: true,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 검색 결과
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSearchResults() {
    final gymsAsync = ref.watch(gymsProvider);
    return Expanded(
      child: gymsAsync.when(
        data: (gyms) {
          if (gyms.isEmpty) {
            return const Center(
              child: Text(
                '검색 결과가 없습니다',
                style: TextStyle(color: ReclimColors.textSecondary),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: gyms.length,
            itemBuilder: (_, i) {
              final gym = gyms[i];
              return ListTile(
                leading: const Icon(Icons.location_on_outlined,
                    color: ReclimColors.accent),
                title: Text(gym.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: gym.address != null
                    ? Text(gym.address!,
                        style: const TextStyle(
                            fontSize: 12,
                            color: ReclimColors.textTertiary),
                        overflow: TextOverflow.ellipsis)
                    : null,
                onTap: () => _selectSearchGym(gym),
                contentPadding: EdgeInsets.zero,
                dense: true,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 캘린더
  // ═══════════════════════════════════════════════════════════════════════════

  Map<DateTime, List<_CalendarDayEntry>> _buildCalendarData(
      List<GymSettingSchedule> schedules) {
    final result = <DateTime, List<_CalendarDayEntry>>{};
    for (final schedule in schedules) {
      final dateColors = <String, List<Color>>{};
      for (final sector in schedule.sectors) {
        Color? c;
        if (sector.color != null) {
          final dc = DifficultyColor.values
              .where((d) => d.name == sector.color)
              .firstOrNull;
          if (dc != null) c = Color(dc.colorValue);
        }
        for (final dateStr in sector.dates) {
          dateColors.putIfAbsent(dateStr, () => []);
          if (c != null) dateColors[dateStr]!.add(c);
        }
      }

      for (final entry in dateColors.entries) {
        final parts = entry.key.split('-');
        if (parts.length != 3) continue;
        final dt = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        result.putIfAbsent(dt, () => []);
        result[dt]!.add(_CalendarDayEntry(
          gymName: schedule.gymName ?? '',
          colors: entry.value,
        ));
      }
    }
    return result;
  }

  Widget _buildCalendar(
    DateTime focusedMonth,
    DateTime selectedDate,
    AsyncValue<List<GymSettingSchedule>> schedulesAsync,
  ) {
    final schedules = schedulesAsync.valueOrNull ?? [];
    final calendarData = _buildCalendarData(schedules);
    final colorScheme = Theme.of(context).colorScheme;

    return TableCalendar(
      firstDay: DateTime(2020),
      lastDay: DateTime(2030),
      focusedDay: focusedMonth,
      calendarFormat: _calendarFormat,
      rowHeight: 64,
      availableCalendarFormats: const {
        CalendarFormat.month: '월',
        CalendarFormat.twoWeeks: '2주',
        CalendarFormat.week: '주',
      },
      onFormatChanged: (format) {
        setState(() => _calendarFormat = format);
      },
      selectedDayPredicate: (day) => isSameDay(day, selectedDate),
      onDaySelected: (selected, focused) {
        ref.read(settingSelectedDateProvider.notifier).state = selected;
        ref.read(settingFocusedMonthProvider.notifier).state = focused;
      },
      onPageChanged: (focused) {
        ref.read(settingFocusedMonthProvider.notifier).state = focused;
      },
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) =>
            _buildDayCell(day, calendarData, false, false),
        selectedBuilder: (context, day, focusedDay) =>
            _buildDayCell(day, calendarData, true, false),
        todayBuilder: (context, day, focusedDay) =>
            _buildDayCell(day, calendarData, isSameDay(day, selectedDate), true),
      ),
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        cellMargin: EdgeInsets.zero,
        tableBorder: const TableBorder(),
        markersMaxCount: 0,
        weekendTextStyle:
            TextStyle(color: colorScheme.error.withOpacity(0.7)),
        defaultTextStyle: const TextStyle(fontSize: 13),
      ),
      headerStyle: HeaderStyle(
        formatButtonVisible: true,
        titleCentered: true,
        titleTextStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        leftChevronIcon:
            Icon(Icons.chevron_left_rounded, color: colorScheme.onSurface),
        rightChevronIcon:
            Icon(Icons.chevron_right_rounded, color: colorScheme.onSurface),
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
        final normalized = DateTime(day.year, day.month, day.day);
        return calendarData[normalized] ?? [];
      },
    );
  }

  Widget _buildDayCell(
    DateTime day,
    Map<DateTime, List<_CalendarDayEntry>> calendarData,
    bool isSelected,
    bool isToday,
  ) {
    final normalized = DateTime(day.year, day.month, day.day);
    final entries = calendarData[normalized] ?? [];
    final colorScheme = Theme.of(context).colorScheme;
    final isWeekend = day.weekday == 6 || day.weekday == 7;

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        // 날짜 숫자 (선택: 원형 배경)
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: isSelected
              ? const BoxDecoration(
                  color: ReclimColors.accent,
                  shape: BoxShape.circle,
                )
              : isToday
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: ReclimColors.accent, width: 1.5),
                    )
                  : null,
          child: Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  isSelected || isToday ? FontWeight.w700 : FontWeight.w400,
              color: isSelected
                  ? Colors.white
                  : isToday
                      ? ReclimColors.accent
                      : isWeekend
                          ? colorScheme.error.withOpacity(0.7)
                          : ReclimColors.textPrimary,
            ),
          ),
        ),
        if (entries.isNotEmpty) ...[
          const SizedBox(height: 2),
          _buildColorDots(entries.first, isSelected),
        ],
      ],
    );
  }

  Widget _buildColorDots(_CalendarDayEntry entry, bool isSelected) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = entry.colors;

    if (colors.isEmpty) {
      // 색상 정보 없으면 기본 dot
      return Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: ReclimColors.accent,
          shape: BoxShape.circle,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: colors.take(4).map((c) => Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? colorScheme.onPrimary.withOpacity(0.3)
                    : ReclimColors.border,
                width: 0.5,
              ),
            ),
          )).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 선택된 날짜의 일정 목록
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildScheduleList(
    DateTime selectedDate,
    AsyncValue<List<GymSettingSchedule>> schedulesAsync,
  ) {
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final dateLabel = '${selectedDate.month}월 ${selectedDate.day}일';

    return schedulesAsync.when(
      data: (schedules) {
        final matchingEntries = <_ScheduleDateEntry>[];
        for (final schedule in schedules) {
          final sectors = schedule.sectorsForDate(dateStr);
          if (sectors.isNotEmpty) {
            matchingEntries.add(_ScheduleDateEntry(
              schedule: schedule,
              sectors: sectors,
            ));
          }
        }

        if (matchingEntries.isEmpty) {
          return _buildEmptyState(dateLabel);
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          itemCount: matchingEntries.length + 1,
          itemBuilder: (_, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  dateLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ReclimColors.textPrimary,
                  ),
                ),
              );
            }
            final entry = matchingEntries[i - 1];
            return _SettingCard(entry: entry, dateStr: dateStr);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
    );
  }

  Widget _buildEmptyState(String dateLabel) {
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
            child: Icon(Icons.event_busy_outlined,
                size: 28, color: ReclimColors.accent.withOpacity(0.4)),
          ),
          const SizedBox(height: 12),
          Text(
            '$dateLabel\n등록된 세팅일정이 없습니다',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: ReclimColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Helper classes
// ═════════════════════════════════════════════════════════════════════════════

class _CalendarDayEntry {
  final String gymName;
  final List<Color> colors;
  const _CalendarDayEntry({required this.gymName, required this.colors});
}

class _ScheduleDateEntry {
  final GymSettingSchedule schedule;
  final List<SettingSector> sectors;
  const _ScheduleDateEntry({required this.schedule, required this.sectors});
}

class _SettingCard extends StatelessWidget {
  final _ScheduleDateEntry entry;
  final String dateStr;

  const _SettingCard({required this.entry, required this.dateStr});

  @override
  Widget build(BuildContext context) {
    final schedule = entry.schedule;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SettingScheduleDetailScreen(
                schedule: schedule,
                selectedDate: dateStr,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on,
                      size: 16, color: ReclimColors.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      schedule.gymName ?? '',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ReclimColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      size: 18, color: ReclimColors.textTertiary),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: entry.sectors.map((sector) {
                  Color? sectorColor;
                  if (sector.color != null) {
                    final dc = DifficultyColor.values
                        .where((d) => d.name == sector.color)
                        .firstOrNull;
                    if (dc != null) sectorColor = Color(dc.colorValue);
                  }
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (sectorColor != null) ...[
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: sectorColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: ReclimColors.border,
                              width: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        '${sector.name} 세팅',
                        style: const TextStyle(
                          fontSize: 13,
                          color: ReclimColors.textSecondary,
                        ),
                      ),
                      if (sector.timeRangeLabel != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          sector.timeRangeLabel!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: ReclimColors.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
