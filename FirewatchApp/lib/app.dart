import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers/app_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'services/intro_preferences.dart';

/// Raiz do aplicativo Firewatch.
class FirewatchApp extends ConsumerStatefulWidget {
  const FirewatchApp({super.key, required this.intro});
  final IntroPreferences intro;

  @override
  ConsumerState<FirewatchApp> createState() => _FirewatchAppState();
}

class _FirewatchAppState extends ConsumerState<FirewatchApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = AppRouter.create(intro: widget.intro);
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Firewatch',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}
