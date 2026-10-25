import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'calendar_screen.dart';
import 'home_screen.dart';
import 'mood_screen.dart';
import 'stats_screen.dart';

/// Tab đang mở; thông báo (ví dụ nhắc lịch) có thể chuyển tab qua đây.
final shellTab = ValueNotifier<int>(0);

abstract final class ShellTabs {
  static const home = 0;
  static const calendar = 1;
  static const mood = 2;
  static const stats = 3;
}

/// Khung chính với thanh điều hướng: Hôm nay, Lịch, Cảm xúc, Thống kê.
class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: shellTab,
      builder: (context, tab, _) => Scaffold(
        body: IndexedStack(
          index: tab,
          children: const [HomeScreen(), CalendarScreen(), MoodScreen(), StatsScreen()],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) {
            HapticFeedback.selectionClick();
            shellTab.value = i;
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.spa_outlined),
              selectedIcon: Icon(Icons.spa_rounded),
              label: 'Hôm nay',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded),
              label: 'Lịch',
            ),
            NavigationDestination(
              icon: Icon(Icons.mood_outlined),
              selectedIcon: Icon(Icons.mood_rounded),
              label: 'Cảm xúc',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: 'Thống kê',
            ),
          ],
        ),
      ),
    );
  }
}
