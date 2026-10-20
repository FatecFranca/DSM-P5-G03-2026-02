import 'dart:convert';

import 'package:firewatch/core/models/risk_level.dart';
import 'package:firewatch/core/models/risk_prediction.dart';
import 'package:firewatch/services/geocoding_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'busca real de cidades valida coordenadas e preserva nomes acentuados',
    () async {
      final service = GeocodingService(
        client: MockClient((request) async {
          expect(request.url.host, 'geocoding-api.open-meteo.com');
          expect(request.url.queryParameters['name'], 'Ribeirão Preto');
          expect(request.url.queryParameters['countryCode'], 'BR');
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'results': [
                  {
                    'name': 'Ribeirão Preto',
                    'admin1': 'São Paulo',
                    'latitude': -21.17,
                    'longitude': -47.81,
                  },
                  {'name': 'Inválida', 'latitude': 150, 'longitude': -47},
                  {'name': 'Incompleta'},
                ],
              }),
            ),
            200,
          );
        }),
      );
      addTearDown(service.close);
      final places = await service.search('Ribeirão Preto');
      expect(places, hasLength(1));
      expect(places.single.label, 'Ribeirão Preto, São Paulo');
      expect(places.single.coordinates.latitude, -21.17);
    },
  );

  test('busca distingue resultado vazio de falha do serviço', () async {
    var fail = false;
    final service = GeocodingService(
      client: MockClient(
        (_) async => fail ? http.Response('{}', 503) : http.Response('{}', 200),
      ),
    );
    addTearDown(service.close);
    expect(await service.search('Cidade'), isEmpty);
    fail = true;
    await expectLater(
      service.search('Cidade'),
      throwsA(isA<GeocodingException>()),
    );
  });

  test('app preserva classe e probabilidades retornadas pela VM', () {
    final result = RiskPrediction.fromJson({
      'localizacao': {'latitude': -20.5386, 'longitude': -47.4008},
      'dados_climaticos': {
        'temperatura': 18.2,
        'umidade_ar': 70,
        'precipitacao_mm': 0,
        'vento_kmh': 4.8,
      },
      'predicao': {
        'nivel_risco': 'MODERADO',
        'probabilidade': .1027,
        'porcentagem': '10.3%',
        'probabilidades': {
          'risco_baixo': .3373,
          'risco_moderado': .56,
          'risco_critico': .1027,
        },
      },
    });
    expect(result.level, RiskLevel.moderate);
    expect(result.probability, .1027);
    expect(result.classProbabilities['risco_moderado'], .56);
    expect(result.classProbabilities, hasLength(3));
  });

  test('resposta com classe desconhecida não vira risco baixo', () {
    expect(() => riskLevelFromApi('INDEFINIDO'), throwsFormatException);
  });
}
