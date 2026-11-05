import 'dart:async';

import 'package:firewatch/core/providers/app_providers.dart';
import 'package:firewatch/core/theme/app_theme.dart';
import 'package:firewatch/features/monitoring/regional_risk_controller.dart';
import 'package:firewatch/features/monitoring/regional_risk_panel.dart';
import 'package:firewatch/features/onboarding/location_onboarding_screen.dart';
import 'package:firewatch/features/splash/splash_screen.dart';
import 'package:firewatch/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _PendingLocationService extends LocationService {
  final completer = Completer<Never>();

  @override
  Future<Never> getCurrentLocation() => completer.future;
}

double _contrast(Color foreground, Color background) {
  final values = [foreground.computeLuminance(), background.computeLuminance()]
    ..sort();
  return (values.last + 0.05) / (values.first + 0.05);
}

void main() {
  testWidgets('navegação escura mantém contraste AA nos itens selecionados', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          bottomNavigationBar: NavigationBar(
            selectedIndex: 0,
            destinations: [
              NavigationDestination(icon: Icon(Icons.map), label: 'Mapa'),
              NavigationDestination(
                icon: Icon(Icons.notifications),
                label: 'Alertas',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final navigation = Theme.of(
      tester.element(find.byType(NavigationBar)),
    ).navigationBarTheme;
    final selected = {WidgetState.selected};
    final background = navigation.backgroundColor!;
    final labelColor = navigation.labelTextStyle!.resolve(selected)!.color!;
    final iconColor = navigation.iconTheme!.resolve(selected)!.color!;

    expect(_contrast(labelColor, background), greaterThanOrEqualTo(4.5));
    expect(_contrast(iconColor, background), greaterThanOrEqualTo(3));
  });

  testWidgets('splash preserva o label e anuncia o carregamento', (
    tester,
  ) async {
    final pending = Completer<void>();
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SplashScreen(onEnter: () => pending.future),
      ),
    );

    await tester.tap(find.text('Entrar no app'));
    await tester.pump();

    expect(find.text('Entrar no app'), findsOneWidget);
    final node = tester.getSemantics(
      find.bySemanticsLabel('Entrar no app. Carregando.'),
    );
    expect(node.label, 'Entrar no app. Carregando.');
    expect(node.flagsCollection.isLiveRegion, isTrue);
    semantics.dispose();
  });

  testWidgets('permissão preserva o label e anuncia o carregamento', (
    tester,
  ) async {
    final location = _PendingLocationService();
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [locationServiceProvider.overrideWithValue(location)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const LocationOnboardingScreen(),
        ),
      ),
    );

    await tester.tap(find.text('Permitir localização'));
    await tester.pump();

    expect(find.text('Permitir localização'), findsOneWidget);
    final node = tester.getSemantics(
      find.bySemanticsLabel('Permitir localização. Obtendo localização.'),
    );
    expect(node.label, 'Permitir localização. Obtendo localização.');
    expect(node.flagsCollection.isLiveRegion, isTrue);
    semantics.dispose();
  });

  testWidgets('erro regional é anunciado como região viva', (tester) async {
    const message = 'Não foi possível analisar esta região.';
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: RegionalRiskPanel(
            state: const RegionalRiskState(error: message),
            onZone: (_) {},
          ),
        ),
      ),
    );

    final node = tester.getSemantics(find.bySemanticsLabel(message));
    expect(node.label, message);
    expect(node.flagsCollection.isLiveRegion, isTrue);
    semantics.dispose();
  });
}
