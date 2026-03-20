import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app.dart';
import '../providers/camera_settings_provider.dart';
import '../providers/user_grade_provider.dart';
import 'camera_tab_screen.dart';
import 'home_tab_screen.dart';
import 'records_tab_screen.dart';
import 'setting_schedule_tab_screen.dart';
import 'stats_tab_screen.dart';

class MainShellScreen extends ConsumerWidget {
  const MainShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(userGradeProvider);
    final currentIndex = ref.watch(bottomNavIndexProvider);

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: const [
          HomeTabScreen(),
          RecordsTabScreen(),
          CameraTabScreen(),
          SettingScheduleTabScreen(),
          StatsTabScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: ClimpickColors.border, width: 1),
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
              icon: Icon(Icons.description_outlined),
              selectedIcon: Icon(Icons.description_rounded),
              label: '기록',
            ),
            NavigationDestination(
              icon: Icon(Icons.videocam_outlined),
              selectedIcon: Icon(Icons.videocam_rounded),
              label: '촬영',
            ),
            NavigationDestination(
              icon: Badge(
                label: Text('Beta', style: TextStyle(fontSize: 8)),
                backgroundColor: ClimpickColors.accent,
                child: Icon(Icons.calendar_month_outlined),
              ),
              selectedIcon: Badge(
                label: Text('Beta', style: TextStyle(fontSize: 8)),
                backgroundColor: ClimpickColors.accent,
                child: Icon(Icons.calendar_month_rounded),
              ),
              label: '세팅일정',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: '통계',
            ),
          ],
        ),
      ),
    );
  }
}
