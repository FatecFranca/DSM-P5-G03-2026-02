import 'dart:async';
import 'dart:convert';

import 'package:firewatch/core/models/regional_risk.dart';
import 'package:firewatch/core/models/risk_level.dart';
import 'package:firewatch/features/monitoring/regional_risk_controller.dart';
import 'package:firewatch/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

import 'fixtures/regional_response.dart';

void main() {
  test('preserva a classe moderada mesmo com P(crítico) abaixo de 30%', () {
    final region = RegionalRisk.fromJson(regionalResponse());
    expect(region.zones.length, 9);
    expect(region.zones.first.prediction!.level, RiskLevel.moderate);
    expect(region.zones.first.prediction!.probability, 0.1);
    expect(region.zones.first.contains(region.zones.first.sample), isTrue);
    expect(region.zones.first.contains(const LatLng(0, 0)), isFalse);
  });

  test('multipolígonos respeitam lacunas e partes separadas', () {
    final json = regionalResponse();
    final feature = (json['features'] as List).first as Map<String, dynamic>;
    feature['geometry'] = {
      'type': 'MultiPolygon',
      'coordinates': [
        [
          [
            [0, 0],
            [4, 0],
            [4, 4],
            [0, 4],
            [0, 0],
          ],
          [
            [1, 1],
            [2, 1],
            [2, 2],
            [1, 2],
            [1, 1],
          ],
        ],
        [
          [
            [5, 0],
            [6, 0],
            [6, 1],
            [5, 1],
            [5, 0],
          ],
        ],
      ],
    };
    final zone = RiskZone.fromJson(feature);
    expect(zone.contains(const LatLng(0.5, 0.5)), isTrue);
    expect(zone.contains(const LatLng(1.5, 1.5)), isFalse);
    expect(zone.contains(const LatLng(0.5, 5.5)), isTrue);
  });

  test('ausência de dados e expiração nunca significam risco baixo', () {
    final zone = RegionalRisk.fromJson(
      regionalResponse(missing: true),
    ).zones.first;
    expect(zone.prediction, isNull);
    expect(zone.isFresh(DateTime.now()), isFalse);
    final old = RegionalRisk.fromJson(
      regionalResponse(now: DateTime.utc(2020)),
    ).zones.first;
    expect(old.isFresh(DateTime.now()), isFalse);
  });

  test(
    'rejeita excesso, duplicatas, horário sem fuso e resultado de outro local',
    () {
      var json = regionalResponse();
      (json['features'] as List).add((json['features'] as List).first);
      expect(() => RegionalRisk.fromJson(json), throwsFormatException);
      json = regionalResponse();
      json['features'][1]['id'] = json['features'][0]['id'];
      expect(() => RegionalRisk.fromJson(json), throwsFormatException);
      json = regionalResponse();
      json['features'][0]['properties']['expira_em'] = '2026-10-21T15:00:00';
      expect(() => RegionalRisk.fromJson(json), throwsFormatException);
      json = regionalResponse();
      json['features'][0]['properties']['resultado']['localizacao'] = {
        'latitude': 0,
        'longitude': 0,
      };
      expect(() => RegionalRisk.fromJson(json), throwsFormatException);
    },
  );

  test('respostas antigas não substituem a última região solicitada', () async {
    final first = Completer<http.Response>();
    final second = Completer<http.Response>();
    var calls = 0;
    final api = ApiService(
      client: MockClient((_) => ++calls == 1 ? first.future : second.future),
    );
    final controller = RegionalRiskController(api);
    final oldRequest = controller.analyze(const LatLng(-20.5386, -47.4008));
    final newRequest = controller.analyze(const LatLng(-23.55, -46.63));
    final current = regionalResponse();
    current['centro'] = {'latitude': -23.55, 'longitude': -46.63};
    second.complete(http.Response(jsonEncode(current), 200));
    await newRequest;
    first.complete(http.Response(jsonEncode(regionalResponse()), 200));
    await oldRequest;
    expect(controller.state.region!.center.latitude, -23.55);
    controller.dispose();
    api.close();
  });

  test(
    'API sem nova rota informa implantação pendente, sem fallback fictício',
    () async {
      var calls = 0;
      final api = ApiService(
        client: MockClient((request) async {
          calls++;
          expect(request.url.path, '/api/v1/risco-regional');
          return http.Response('{}', 404);
        }),
      );
      final controller = RegionalRiskController(api);
      await controller.analyze(const LatLng(-20.5386, -47.4008));
      expect(controller.state.error, contains('não estão disponíveis'));
      expect(controller.state.region, isNull);
      expect(calls, 1);
      controller.dispose();
      api.close();
    },
  );

  test(
    'limpar a região impede que uma resposta pendente restaure a camada antiga',
    () async {
      final pending = Completer<http.Response>();
      final api = ApiService(client: MockClient((_) => pending.future));
      final controller = RegionalRiskController(api);
      final request = controller.analyze(const LatLng(-20.5386, -47.4008));
      controller.clear();
      pending.complete(http.Response(jsonEncode(regionalResponse()), 200));
      await request;
      expect(controller.state.region, isNull);
      expect(controller.state.loading, isFalse);
      expect(controller.state.error, isNull);
      controller.dispose();
      api.close();
    },
  );

  testWidgets('o vencimento remove a validade da camada sem nova requisição', (
    tester,
  ) async {
    final api = ApiService(
      client: MockClient(
        (_) async => http.Response(jsonEncode(regionalResponse()), 200),
      ),
    );
    final controller = RegionalRiskController(api);
    await controller.analyze(const LatLng(-20.5386, -47.4008));
    expect(controller.state.expired, isFalse);
    await tester.pump(const Duration(minutes: 6));
    expect(controller.state.expired, isTrue);
    controller.dispose();
    api.close();
  });
}
