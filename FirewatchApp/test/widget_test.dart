import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'package:firewatch/core/models/geo_coordinates.dart';

import 'package:firewatch/app.dart';
import 'package:firewatch/shared/widgets/flame_logo.dart';
import 'package:firewatch/core/providers/app_providers.dart';
import 'package:firewatch/features/monitoring/monitoring_screen.dart';
import 'package:firewatch/services/api_service.dart';
import 'package:firewatch/services/geocoding_service.dart';
import 'package:firewatch/services/intro_preferences.dart';
import 'package:firewatch/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tile transparente de 1x1 usado para não acessar a rede nos testes.
final Uint8List _transparentTile = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpeqz8AAAAASUVORK5CYII=',
);

class _FakeTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_transparentTile);
}

class _DeniedLocationService extends LocationService {
  int calls = 0;

  @override
  Future<GeoCoordinates> getCurrentLocation() async {
    calls++;
    throw const LocationException(
      'Permissão de localização negada. Você pode buscar uma cidade.',
    );
  }
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
      final response = jsonDecode(_riskResponseJson) as Map<String, dynamic>;
      response['localizacao'] = jsonDecode(request.body);
      return http.Response(
        jsonEncode(response),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response(
      '{}',
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

MockClient _geocodingMockClient() {
  return MockClient(
    (request) async => http.Response(
      request.url.host == 'geocoding-api.open-meteo.com'
          ? jsonEncode({
              'results': [
                {
                  'name': 'Franca',
                  'admin1': 'São Paulo',
                  'latitude': -20.5386,
                  'longitude': -47.4008,
                },
              ],
            })
          : _geocodingResponseJson,
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

Future<void> _pumpApp(
  WidgetTester tester, {
  List<Override>? overrides,
  bool resetIntro = true,
}) async {
  if (resetIntro) SharedPreferences.setMockInitialValues({});
  final intro = await IntroPreferences.load();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides ?? _testOverrides(),
      child: FirewatchApp(intro: intro),
    ),
  );
  await tester.pump();
}

Future<void> _openMap(WidgetTester tester, {List<Override>? overrides}) async {
  await _pumpApp(tester, overrides: overrides);
  await tester.tap(find.text('Entrar no app'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Pular'));
  await tester.pumpAndSettle();
}

Future<void> _enterPoint(WidgetTester tester) async {
  await tester.tap(find.text('Escolher localização'));
  await tester.pumpAndSettle();
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), '-20.5386');
  await tester.enterText(fields.at(1), '-47.4008');
  await tester.ensureVisible(find.text('Confirmar coordenadas'));
  await tester.tap(find.text('Confirmar coordenadas'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('entrada persiste e uma nova instância abre diretamente o mapa', (
    tester,
  ) async {
    await _pumpApp(tester);
    expect(find.text('PROJETO INTERDISCIPLINAR • 5º SEMESTRE'), findsOneWidget);
    expect(find.text('PROJETO INTEGRADOR • 5º SEMESTRE'), findsNothing);
    await tester.tap(find.text('Entrar no app'));
    await tester.pumpAndSettle();
    expect((await IntroPreferences.load()).completed, isTrue);
    await tester.tap(find.text('Pular'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    tester.platformDispatcher.defaultRouteNameTestValue = '/splash';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    await _pumpApp(tester, resetIntro: false);
    await tester.pumpAndSettle();
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('Entrar no app'), findsNothing);
    expect(find.text('Onde você está?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GPS negado mantém busca e não impede a entrada persistida', (
    tester,
  ) async {
    final location = _DeniedLocationService();
    final overrides = [
      ..._testOverrides(),
      locationServiceProvider.overrideWithValue(location),
    ];
    await _pumpApp(tester, overrides: overrides);
    expect(location.calls, 0);
    await tester.tap(find.text('Entrar no app'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Permitir localização'));
    await tester.pumpAndSettle();
    expect(location.calls, 1);
    expect(
      find.textContaining('Permissão de localização negada'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Buscar localização'));
    await tester.tap(find.text('Buscar localização'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Franca');
    await tester.tap(find.text('Buscar cidade'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Franca, São Paulo'));
    await tester.pumpAndSettle();
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('Franca, SP'), findsOneWidget);
    expect((await IntroPreferences.load()).completed, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('splash aguarda o toque e mantém as opções de localização', (
    tester,
  ) async {
    await _pumpApp(tester);
    expect(find.byType(FirewatchWordmarkText), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Entrar no app'), findsOneWidget);
    await tester.tap(find.text('Entrar no app'));
    await tester.pumpAndSettle();
    expect(find.text('Onde você está?'), findsOneWidget);
    expect(find.text('Permitir localização'), findsOneWidget);
    expect(find.text('Buscar localização'), findsOneWidget);
  });

  testWidgets('pular abre mapa real sem inventar localização ou risco', (
    tester,
  ) async {
    await _openMap(tester);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('Escolher localização'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(3));
    expect(find.text('Previsão'), findsNothing);
    expect(find.text('Dados demonstrativos'), findsNothing);
    expect(find.text('Risco crítico'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'alertas vazios, prevenção e configurações têm navegação funcional',
    (tester) async {
      await _openMap(tester);
      await tester.tap(find.text('Alertas'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma consulta disponível.'), findsOneWidget);
      await tester.tap(find.text('Prevenção'));
      await tester.pumpAndSettle();
      expect(find.text('Como se proteger'), findsOneWidget);
      await tester.tap(find.byTooltip('Configurações'));
      await tester.pumpAndSettle();
      expect(find.text('Sobre os dados'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.text('Frequência de atualização'), findsNothing);
    },
  );

  testWidgets(
    'coordenadas consultam a API e exibem a mesma análise em alertas',
    (tester) async {
      await _openMap(tester);
      await _enterPoint(tester);
      expect(find.text('Franca, SP'), findsOneWidget);
      expect(find.text('Risco crítico'), findsOneWidget);
      await tester.tap(find.text('Ver análise do local'));
      await tester.pumpAndSettle();
      expect(find.text('86.4%'), findsOneWidget);
      await tester.tap(find.byTooltip('Fechar resultado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alertas'));
      await tester.pumpAndSettle();
      expect(find.text('Risco crítico'), findsOneWidget);
      expect(find.text('Dados demonstrativos'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('falha da API mantém o ponto no mapa e oferece nova tentativa', (
    tester,
  ) async {
    var calls = 0;
    final overrides = _testOverrides();
    overrides[0] = apiServiceProvider.overrideWithValue(
      ApiService(
        baseUrl: 'https://api.example.test',
        client: MockClient((_) async {
          calls++;
          return http.Response(
            '{"detail":"Serviço de previsão indisponível"}',
            503,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );
    await _openMap(tester, overrides: overrides);
    await _enterPoint(tester);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('Serviço de previsão indisponível'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resposta antiga não substitui análise de um novo local', (
    tester,
  ) async {
    final pending = <String, Completer<http.Response>>{};
    final overrides = _testOverrides();
    overrides[0] = apiServiceProvider.overrideWithValue(
      ApiService(
        baseUrl: 'https://api.example.test',
        client: MockClient((request) {
          final lat = (jsonDecode(request.body)['latitude'] as num).toString();
          return (pending[lat] = Completer<http.Response>()).future;
        }),
      ),
    );
    await _openMap(tester, overrides: overrides);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MonitoringScreen)),
    );
    container.read(coordinatesProvider.notifier).state = const GeoCoordinates(
      latitude: -20,
      longitude: -47,
    );
    await tester.pump();
    container.read(coordinatesProvider.notifier).state = const GeoCoordinates(
      latitude: -21,
      longitude: -48,
    );
    await tester.pump();
    http.Response response(double lat, double lon) {
      final json = jsonDecode(_riskResponseJson) as Map<String, dynamic>;
      json['localizacao'] = {'latitude': lat, 'longitude': lon};
      return http.Response(
        jsonEncode(json),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    pending['-21.0']!.complete(response(-21, -48));
    await tester.pumpAndSettle();
    pending['-20.0']!.complete(response(-20, -47));
    await tester.pumpAndSettle();
    expect(container.read(riskPredictionProvider)!.latitude, -21);
    expect(container.read(riskPredictionProvider)!.longitude, -48);
    expect(find.text('-21.0000, -48.0000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('troca nas configurações atualiza coordenadas e consulta', (
    tester,
  ) async {
    await _openMap(tester);
    await _enterPoint(tester);
    await tester.tap(find.byTooltip('Configurações'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Franca, SP'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '-21.1704');
    await tester.enterText(fields.at(1), '-47.8103');
    await tester.ensureVisible(find.text('Confirmar coordenadas'));
    await tester.tap(find.text('Confirmar coordenadas'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MonitoringScreen)),
    );
    expect(container.read(coordinatesProvider)!.latitude, -21.1704);
    expect(container.read(riskPredictionProvider)!.latitude, -21.1704);
    expect(find.text('-21.1704, -47.8103'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mapa e prevenção cabem com fonte ampliada e tema escuro', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _openMap(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MonitoringScreen)),
    );
    container.read(themeModeProvider.notifier).state = ThemeMode.dark;
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prevenção'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Prevenção de queimadas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prevenção de queimadas'));
    await tester.pumpAndSettle();
    expect(find.text('Exemplo demonstrativo'), findsNothing);
  });
  testWidgets('toque no mapa seleciona e consulta coordenadas reais do toque', (
    tester,
  ) async {
    await _openMap(tester);
    final map = find.byType(FlutterMap);
    await tester.tapAt(tester.getTopLeft(map) + const Offset(140, 170));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(map));
    final point = container.read(coordinatesProvider);
    expect(point, isNotNull);
    expect(point!.latitude, isNot(-20.5386));
    final result = container.read(riskPredictionProvider);
    expect(result, isNotNull);
    expect(result!.latitude, point.latitude);
    expect(result.longitude, point.longitude);
    expect(tester.takeException(), isNull);
  });
}
