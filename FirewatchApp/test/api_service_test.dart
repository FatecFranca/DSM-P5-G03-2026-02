import 'dart:convert';

import 'package:firewatch/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ApiService', () {
    test('consulta o endpoint de teste do banco', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url, Uri.https('api.example.test', '/api/v1/db-test'));
        return http.Response('{"connected":true}', 200);
      });
      final service = ApiService(
        client: client,
        baseUrl: 'https://api.example.test/',
      );
      addTearDown(service.close);

      expect(await service.dbTest(), {'connected': true});
    });

    test('envia coordenadas e decodifica a previsão', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url,
          Uri.https('api.example.test', '/api/v1/prever-risco'),
        );
        expect(request.headers['content-type'], 'application/json');
        expect(jsonDecode(request.body), {
          'latitude': -20.5394,
          'longitude': -47.4014,
        });
        return http.Response('{"nivel":"baixo"}', 200);
      });
      final service = ApiService(
        client: client,
        baseUrl: 'https://api.example.test',
      );
      addTearDown(service.close);

      expect(await service.preverRisco(-20.5394, -47.4014), {'nivel': 'baixo'});
    });

    test('lança erro para resposta HTTP malsucedida', () async {
      final service = ApiService(
        client: MockClient(
          (_) async => http.Response('Serviço indisponível', 503),
        ),
        baseUrl: 'https://api.example.test',
      );
      addTearDown(service.close);

      expect(service.dbTest(), throwsA(isA<http.ClientException>()));
    });

    test('rejeita uma resposta que não seja um objeto JSON', () async {
      final service = ApiService(
        client: MockClient((_) async => http.Response('[]', 200)),
        baseUrl: 'https://api.example.test',
      );
      addTearDown(service.close);

      expect(service.dbTest(), throwsFormatException);
    });
  });
}
