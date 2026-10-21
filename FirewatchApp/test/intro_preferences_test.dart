import 'package:firewatch/bootstrap.dart';
import 'package:firewatch/features/splash/splash_screen.dart';
import 'package:firewatch/services/intro_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'primeiro acesso é falso e conclusão sobrevive à recarga do armazenamento',
    () async {
      final first = await IntroPreferences.load();
      expect(first.completed, isFalse);
      await first.complete();
      final reopened = await IntroPreferences.load();
      expect(reopened.completed, isTrue);
      expect((await SharedPreferences.getInstance()).getKeys(), {
        IntroPreferences.completedKey,
      });
    },
  );

  testWidgets(
    'falha ao salvar mantém a apresentação e permite nova tentativa',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(onEnter: () async => throw StateError('storage')),
        ),
      );
      await tester.tap(find.text('Entrar no app'));
      await tester.pumpAndSettle();
      expect(
        find.text('Não foi possível salvar sua preferência. Tente novamente.'),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'falha ao carregar preferências apresenta erro e botão de recuperação',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: FirewatchBootstrap(
            loadPreferences: () async => throw StateError('storage'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Não foi possível acessar as preferências deste dispositivo.',
        ),
        findsOneWidget,
      );
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
