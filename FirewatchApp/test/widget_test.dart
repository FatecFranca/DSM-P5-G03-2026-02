import 'dart:typed_data';

import 'package:firewatch/app.dart';
import 'package:firewatch/core/providers/app_providers.dart';
import 'package:firewatch/features/monitoring/monitoring_screen.dart';
import 'package:firewatch/services/api_service.dart';
import 'package:firewatch/services/geocoding_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Tile transparente de 1x1 usado para não acessar a rede nos testes.
final Uint8List _transparentTile = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,
  0xAE, 0x42, 0x60, 0x82,
]);

class _FakeTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_transparentTile);
}

const String _riskResponseJson = '''
{
  "status": "sucesso",
  "localizacao": {"latitude": -20.5386, "longitude": -47.4008},
  "dados_climaticos": {
    "temperatura": 31.2,
    "umidade_ar": 24.0,
    "precipitacao_mm": 0.0,
    "vento_kmh": 18.3
  },
  "predicao": {
    "probabilidade": 0.864,
    "porcentagem": "86.4%",
    "nivel_risco": "CRÍTICO",
    "cor_alerta": "#DC2626",
    "recomendacao": "Alerta máximo. Evite qualquer tipo de queimada de manejo."
  }
}
''';

const String _geocodingResponseJson = '''
{
  "address": {"city": "Franca", "ISO3166-2-lvl4": "BR-SP"}
}
''';

MockClient _apiMockClient() {
  return MockClient((request) async {
    if (request.url.path.contains('prever-risco')) {
      return http.Response(
        _riskResponseJson,
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response('{}', 200, headers: {'content-type': 'application/json'});
  });
}

MockClient _geocodingMockClient() {
  return MockClient(
    (_) async => http.Response(
      _geocodingResponseJson,
      200,
      headers: {'content-type': 'application/json'},
    ),
  );
}

List<Override> _testOverrides() => [
      apiServiceProvider.overrideWithValue(
        ApiService(client: _apiMockClient(), baseUrl: 'https://api.example.test'),
      ),
      geocodingServiceProvider.overrideWithValue(
        GeocodingService(client: _geocodingMockClient()),
      ),
      mapTileProviderProvider.overrideWithValue(_FakeTileProvider()),
    ];

Future<void> _pumpApp(WidgetTester tester, {List<Override>? overrides}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides ?? const [],
      child: FirewatchApp(),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('abre na splash e navega para o onboarding de localização',
      (tester) async {
    await _pumpApp(tester);

    // Splash exibe nome e frase.
    expect(find.text('firewatch'), findsWidgets);

    // Toca em "Começar" para avançar.
    await tester.tap(find.text('Começar'));
    await tester.pumpAndSettle();

    // Onboarding de localização renderizado.
    expect(find.text('Onde você está?'), findsOneWidget);
    expect(find.text('Permitir localização'), findsOneWidget);
    expect(find.text('Digitar coordenadas'), findsOneWidget);
    expect(find.text('Pular'), findsOneWidget);
  });

  testWidgets('a splash permanece até o toque em Começar', (tester) async {
    await _pumpApp(tester);

    // Mesmo após alguns segundos, ainda está na splash (sem avanço automático).
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('Onde você está?'), findsNothing);
    expect(find.text('Começar'), findsOneWidget);
  });

  testWidgets('pular do onboarding abre o dashboard', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Começar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pular'));
    await tester.pumpAndSettle();

    // Dashboard renderizado.
    expect(find.text('Risco de queimada'), findsOneWidget);
    expect(find.text('Início'), findsOneWidget);
    expect(find.text('Alertas'), findsWidgets);
  });

  testWidgets('barra de navegação alterna entre telas', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Começar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pular'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Previsão'));
    await tester.pumpAndSettle();
    expect(find.text('Previsão do risco'), findsOneWidget);

    await tester.tap(find.text('Prevenção'));
    await tester.pumpAndSettle();
    expect(find.text('Como se proteger'), findsOneWidget);
  });

  testWidgets('coordenadas confirmadas abrem o mapa de monitoramento',
      (tester) async {
    await _pumpApp(tester, overrides: _testOverrides());

    // Boas-vindas -> onboarding -> formulário de coordenadas.
    await tester.tap(find.text('Começar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Digitar coordenadas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Digitar coordenadas'));
    await tester.pumpAndSettle();

    // Preenche as coordenadas.
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), '-20.5386');
    await tester.enterText(fields.at(1), '-47.4008');
    await tester.tap(find.text('Confirmar coordenadas'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Tela de monitoramento com painel e botão de ação.
    expect(find.text('CONDIÇÕES AGORA'), findsOneWidget);
    expect(find.text('Verificar risco aqui'), findsOneWidget);

    // Cidade resolvida via geocoding e dados reais da API.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Franca, SP'), findsOneWidget);
    expect(find.text('31.2'), findsOneWidget);

    // Verifica o risco e confirma o painel de resultado.
    await tester.tap(find.text('Verificar risco aqui'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Risco de queimada'), findsOneWidget);
    expect(find.text('Crítico'), findsWidgets);

    // Descarta eventuais erros de imagem dos tiles de rede.
    tester.takeException();
  });
}
