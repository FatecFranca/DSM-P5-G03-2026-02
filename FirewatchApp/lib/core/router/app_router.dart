import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/alerts/alerts_screen.dart';
import '../../features/monitoring/monitoring_screen.dart';
import '../../features/onboarding/coordinates_screen.dart';
import '../../features/onboarding/location_onboarding_screen.dart';
import '../../features/prevention/prevention_screen.dart';
import '../../features/risk_details/risk_details_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/splash/splash_screen.dart';

/// Roteador do aplicativo usando GoRouter.
abstract final class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter create() {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/splash',
      routes: [
        // Tela de abertura.
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),

        // Onboarding de localização.
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: '/onboarding/location',
          builder: (context, state) => const LocationOnboardingScreen(),
        ),
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: '/onboarding/coordinates',
          builder: (context, state) => const CoordinatesScreen(),
        ),

        // Navegação inferior com estado preservado por aba.
        // Uma única experiência de mapa e consulta real.
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AppShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => const MonitoringScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/alerts',
                  builder: (context, state) => const AlertsScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/prevention',
                  builder: (context, state) => const PreventionScreen(),
                ),
              ],
            ),
          ],
        ),

        GoRoute(path: '/map', redirect: (_, _) => '/'),
        GoRoute(path: '/forecast', redirect: (_, _) => '/'),

        // Telas abertas por cima da navegação inferior.
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: '/risk-details',
          builder: (context, state) => const RiskDetailsScreen(),
        ),
      ],
    );
  }
}
