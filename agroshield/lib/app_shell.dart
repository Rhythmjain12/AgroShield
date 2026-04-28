import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/home/home_screen.dart';
import 'screens/fire_map/fire_map_screen.dart';
import 'screens/weather/weather_screen.dart';
import 'screens/advisor/advisor_screen.dart';
import 'theme/app_theme.dart';

final activeTabProvider = StateProvider<int>((ref) => 0);

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const _tabs = [
    HomeScreen(),
    FireMapScreen(),
    WeatherScreen(),
    AdvisorScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeIndex = ref.watch(activeTabProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      // Each tab screen manages its own topbar — no shared AppBar.
      body: IndexedStack(
        index: activeIndex,
        children: _tabs,
      ),
      bottomNavigationBar: _DarkBottomNav(
        currentIndex: activeIndex,
        onTap: (i) => ref.read(activeTabProvider.notifier).state = i,
      ),
    );
  }
}

class _DarkBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _DarkBottomNav({required this.currentIndex, required this.onTap});

  static const _items = [
    _NavItem(Icons.local_fire_department_outlined, Icons.local_fire_department, 'Home'),
    _NavItem(Icons.location_on_outlined, Icons.location_on, 'Fire Map'),
    _NavItem(Icons.cloud_outlined, Icons.cloud, 'Weather'),
    _NavItem(Icons.chat_bubble_outline, Icons.chat_bubble, 'Advisor'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.bgNav,
        border: Border(top: BorderSide(color: Color(0x12FFFFFF))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final active = i == currentIndex;
              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 64,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        active ? item.activeIcon : item.icon,
                        size: 24,
                        color: active
                            ? AppTheme.accent
                            : Colors.white.withValues(alpha: 0.28),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: active
                              ? AppTheme.accent
                              : Colors.white.withValues(alpha: 0.30),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}
