import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_color_tokens.dart';

/// Persistent bottom-nav chrome around the 5 main tabs. Each branch keeps
/// its own navigation stack via [StatefulShellRoute.indexedStack].
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        backgroundColor: context.colors.surface,
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: navigationShell.goBranch,
        destinations: const [
          NavigationDestination(icon: Icon(LucideIcons.home), label: 'Home'),
          NavigationDestination(
            icon: Icon(LucideIcons.calendarDays),
            label: 'Calendar',
          ),
          NavigationDestination(icon: Icon(LucideIcons.utensils), label: 'Meals'),
          NavigationDestination(
            icon: Icon(LucideIcons.shoppingBag),
            label: 'Groceries',
          ),
          NavigationDestination(icon: Icon(LucideIcons.users), label: 'Family'),
        ],
      ),
    );
  }
}
