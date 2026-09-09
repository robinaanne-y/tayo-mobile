import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: navigationShell.goBranch,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_rounded),
            label: 'Calendar',
          ),
          NavigationDestination(icon: Icon(Icons.restaurant_rounded), label: 'Meals'),
          NavigationDestination(
            icon: Icon(Icons.shopping_basket_rounded),
            label: 'Groceries',
          ),
          NavigationDestination(icon: Icon(Icons.groups_rounded), label: 'Family'),
        ],
      ),
    );
  }
}
