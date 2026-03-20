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
import '../widgets/climpick_app_bar.dart';

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

  void _selectGym(ClimbingGym gym) {
    // google_place_id로 기존 gym 조회 → gym_id 필터 설정
    // Places 검색 결과에는 DB id가 없으므로 name으로 표시, gym_id는 DB 조회 후 설정
    _findAndSetGymFilter(gym);
    _searchController.text = gym.name;
    setState(() => _showSearchResults = false);
    FocusScope.of(context).unfocus();
  }

  Future<void> _findAndSetGymFilter(ClimbingGym gym) async {
    // google_place_id로 climbing_gyms에서 ID 조회
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

    // DB에 없는 암장 → 이름으로 필터 (등록된 일정이 없을 것)
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
    final focusedMonth = ref.watch(settingFocusedMonthProvider);
    final selectedDate = ref.watch(settingSelectedDateProvider);
    final gymFilter = ref.watch(settingGymFilterProvider);
    final yearMonth = _yearMonthStr(focusedMonth);
    final schedulesAsync = ref.watch(settingSchedulesProvider(yearMonth));

    return Scaffold(
      appBar: const ClimpickAppBar(),
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
                    color: ClimpickColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: ClimpickColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Beta',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: ClimpickColors.accent,
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
                  color: ClimpickColors.textTertiary,
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
                  borderSide: const BorderSide(color: ClimpickColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: ClimpickColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: ClimpickColors.accent, width: 1.5),
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

          // ─── 내 암장 목록 (기본) or 캘린더 (암장 선택 시) ───
          if (!_showSearchResults && gymFilter == null)
            _buildFavoriteGymList(),

          if (!_showSearchResults && gymFilter != null)
            Expanded(
              child: Column(
                children: [
                  _buildCalendar(
                      focusedMonth, selectedDate, schedulesAsync),
                  const Divider(height: 1, color: ClimpickColors.border),
                  Expanded(
                    child: _buildScheduleList(
                        selectedDate, schedulesAsync, gymFilter),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

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
                      size: 40, color: ClimpickColors.textTertiary.withOpacity(0.5)),
                  const SizedBox(height: 12),
                  const Text(
                    '암장을 검색해서 세팅일정을 확인하세요',
                    style: TextStyle(
                      fontSize: 14,
                      color: ClimpickColors.textSecondary,
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
                      color: ClimpickColors.textPrimary,
                    ),
                  ),
                );
              }
              final gym = gyms[i - 1];
              return ListTile(
                leading: const Icon(Icons.location_on_outlined,
                    color: ClimpickColors.accent),
                title: Text(gym.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: gym.address != null
                    ? Text(gym.address!,
                        style: const TextStyle(
                            fontSize: 12,
                            color: ClimpickColors.textTertiary),
                        overflow: TextOverflow.ellipsis)
                    : null,
                onTap: () => _selectGym(gym),
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

  Widget _buildSearchResults() {
    final gymsAsync = ref.watch(gymsProvider);
    return Expanded(
      child: gymsAsync.when(
        data: (gyms) {
          if (gyms.isEmpty) {
            return const Center(
              child: Text(
                '검색 결과가 없습니다',
                style: TextStyle(color: ClimpickColors.textSecondary),
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
                    color: ClimpickColors.accent),
                title: Text(gym.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: gym.address != null
                    ? Text(gym.address!,
                        style: const TextStyle(
                            fontSize: 12,
                            color: ClimpickColors.textTertiary),
                        overflow: TextOverflow.ellipsis)
                    : null,
                onTap: () => _selectGym(gym),
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

  Widget _buildCalendar(
    DateTime focusedMonth,
    DateTime selectedDate,
    AsyncValue<List<GymSettingSchedule>> schedulesAsync,
  ) {
    // 날짜별 세팅 이벤트 수 계산
    final schedules = schedulesAsync.valueOrNull ?? [];
    final dateCounts = <DateTime, int>{};
    for (final schedule in schedules) {
      for (final dateStr in schedule.allDates) {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          final dt = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
          dateCounts[dt] = (dateCounts[dt] ?? 0) + 1;
        }
      }
    }

    final colorScheme = Theme.of(context).colorScheme;

    return TableCalendar(
      firstDay: DateTime(2020),
      lastDay: DateTime(2030),
      focusedDay: focusedMonth,
      calendarFormat: _calendarFormat,
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
        markerBuilder: (context, day, events) {
          final normalized = DateTime(day.year, day.month, day.day);
          final count = dateCounts[normalized] ?? 0;
          if (count == 0) return const SizedBox.shrink();
          return Positioned(
            bottom: 1,
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: ClimpickColors.accent,
                shape: BoxShape.circle,
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
        final count = dateCounts[normalized] ?? 0;
        return List.generate(count, (i) => i);
      },
    );
  }

  Widget _buildScheduleList(
    DateTime selectedDate,
    AsyncValue<List<GymSettingSchedule>> schedulesAsync,
    String? gymFilter,
  ) {
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final dateLabel = '${selectedDate.month}월 ${selectedDate.day}일';

    return schedulesAsync.when(
      data: (schedules) {
        // 선택된 날짜에 세팅이 있는 스케줄만 필터
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
          // 암장 필터가 있고 데이터가 없으면 공유 유도
          if (gymFilter != null) {
            final gymName = ref.read(settingGymFilterNameProvider) ?? '';
            return _buildEmptyWithSharePrompt(gymName, dateLabel);
          }
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
                    color: ClimpickColors.textPrimary,
                  ),
                ),
              );
            }
            final entry = matchingEntries[i - 1];
            return _SettingCard(entry: entry);
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
              color: ClimpickColors.accent.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.event_busy_outlined,
                size: 28, color: ClimpickColors.accent.withOpacity(0.4)),
          ),
          const SizedBox(height: 12),
          Text(
            '$dateLabel\n등록된 세팅일정이 없습니다',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: ClimpickColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWithSharePrompt(String gymName, String dateLabel) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: ClimpickColors.accent.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.event_busy_outlined,
                size: 28, color: ClimpickColors.accent.withOpacity(0.4)),
          ),
          const SizedBox(height: 12),
          const Text(
            '아직 등록된 세팅일정이 없습니다',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: ClimpickColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleDateEntry {
  final GymSettingSchedule schedule;
  final List<SettingSector> sectors;
  const _ScheduleDateEntry({required this.schedule, required this.sectors});
}

class _SettingCard extends StatelessWidget {
  final _ScheduleDateEntry entry;
  const _SettingCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final schedule = entry.schedule;
    final sectorNames = entry.sectors.map((s) => s.name).join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on,
                    size: 16, color: ClimpickColors.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    schedule.gymName ?? '',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: ClimpickColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$sectorNames 세팅',
              style: const TextStyle(
                fontSize: 13,
                color: ClimpickColors.textSecondary,
              ),
            ),
            if (schedule.submitterDisplayName != null) ...[
              const SizedBox(height: 4),
              Text(
                '정보 공유자: ${schedule.submitterDisplayName}',
                style: const TextStyle(
                  fontSize: 12,
                  color: ClimpickColors.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
