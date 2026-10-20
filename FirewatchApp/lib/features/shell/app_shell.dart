import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Telas acessíveis pela navegação inferior.
enum ShellDestination {
  map('Mapa', Icons.map_outlined, Icons.map_rounded),
  alerts('Alertas', Icons.notifications_outlined, Icons.notifications_rounded),
  prevention(
    'Prevenção',
    Icons.health_and_safety_outlined,
    Icons.health_and_safety_rounded,
  );

  const ShellDestination(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Estrutura principal do aplicativo com a barra de navegação inferior.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final destinations = ShellDestination.values;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.activeIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
