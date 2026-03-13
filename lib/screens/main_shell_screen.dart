import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/camera_settings_provider.dart';
import '../providers/user_grade_provider.dart';
import 'camera_tab_screen.dart';
import 'home_tab_screen.dart';
import 'records_tab_screen.dart';
import 'gym_grades_tab_screen.dart';
import 'stats_tab_screen.dart';

class MainShellScreen extends ConsumerWidget {
  const MainShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // SharedPreferences에서 사용자 등급 미리 로드
    ref.watch(userGradeProvider);
    final currentIndex = ref.watch(bottomNavIndexProvider);

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: const [
          HomeTabScreen(),
          RecordsTabScreen(),
          CameraTabScreen(),
          GymGradesTabScreen(),
          StatsTabScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFFE8ECF0), width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) =>
              ref.read(bottomNavIndexProvider.notifier).state = index,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: '홈',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded),
              label: '캘린더',
            ),
            NavigationDestination(
              icon: Icon(Icons.videocam_outlined),
              selectedIcon: Icon(Icons.videocam_rounded),
              label: '촬영',
            ),
            NavigationDestination(
              icon: Icon(Icons.format_list_numbered_outlined),
              selectedIcon: Icon(Icons.format_list_numbered_rounded),
              label: '난이도',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart_rounded),
              label: '통계',
            ),
          ],
        ),
      ),
    );
  }
}
