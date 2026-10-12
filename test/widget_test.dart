import 'package:firewatch/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(ProviderScope(child: FirewatchApp()));
  await tester.pump();
}

void main() {
  testWidgets('abre na splash e navega para o dashboard', (tester) async {
    await _pumpApp(tester);

    // Splash exibe nome e slogan.
    expect(find.text('Firewatch'), findsWidgets);

    // Avança o timer da splash.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Dashboard renderizado.
    expect(find.text('Risco de queimada'), findsOneWidget);
    expect(find.text('Início'), findsOneWidget);
    expect(find.text('Alertas'), findsWidgets);
  });

  testWidgets('barra de navegação alterna entre telas', (tester) async {
    await _pumpApp(tester);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Previsão'));
    await tester.pumpAndSettle();
    expect(find.text('Previsão do risco'), findsOneWidget);

    await tester.tap(find.text('Prevenção'));
    await tester.pumpAndSettle();
    expect(find.text('Como se proteger'), findsOneWidget);
  });
}