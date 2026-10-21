import 'package:flutter/material.dart';

import 'app.dart';
import 'core/theme/app_theme.dart';
import 'services/intro_preferences.dart';

/// Aguarda o armazenamento local antes de decidir a primeira rota.
class FirewatchBootstrap extends StatefulWidget {
  const FirewatchBootstrap({super.key, this.loadPreferences});

  final Future<IntroPreferences> Function()? loadPreferences;

  @override
  State<FirewatchBootstrap> createState() => _FirewatchBootstrapState();
}

class _FirewatchBootstrapState extends State<FirewatchBootstrap> {
  late Future<IntroPreferences> _preferences;

  @override
  void initState() {
    super.initState();
    _preferences = _load();
  }

  Future<IntroPreferences> _load() =>
      (widget.loadPreferences ?? IntroPreferences.load)();

  @override
  Widget build(BuildContext context) => FutureBuilder<IntroPreferences>(
    future: _preferences,
    builder: (context, snapshot) {
      if (snapshot.hasData) return FirewatchApp(intro: snapshot.requireData);
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: snapshot.hasError
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Não foi possível acessar as preferências deste dispositivo.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () =>
                                setState(() => _preferences = _load()),
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      )
                    : const CircularProgressIndicator(),
              ),
            ),
          ),
        ),
      );
    },
  );
}
