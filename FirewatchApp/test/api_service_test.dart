import 'dart:convert';

import 'package:firewatch/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ApiService', () {
    test('consulta a saúde do serviço', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url, Uri.https('api.example.test', '/health'));
        return http.Response('{"status":"ok"}', 200);
      });
      final service = ApiService(
        client: client,
        baseUrl: 'https://api.example.test/',
      );
      addTearDown(service.close);

      expect(await service.health(), {'status': 'ok'});
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

    test(
      'lança ApiException com o status para resposta HTTP malsucedida',
      () async {
        final service = ApiService(
          client: MockClient(
            (_) async => http.Response('{"detail":"Modelo indisponível"}', 503),
          ),
          baseUrl: 'https://api.example.test',
        );
        addTearDown(service.close);

        await expectLater(
          service.health(),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', 503)
                .having((e) => e.message, 'message', 'Modelo indisponível'),
          ),
        );
      },
    );

    test('traduz 422 com lista de validação em mensagem amigável', () async {
      final service = ApiService(
        client: MockClient(
          (_) async => http.Response(
            '{"detail":[{"loc":["body","latitude"],"msg":"invalid"}]}',
            422,
          ),
        ),
        baseUrl: 'https://api.example.test',
      );
      addTearDown(service.close);

      await expectLater(
        service.preverRisco(999, 999),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 422)
              .having(
                (e) => e.message,
                'message',
                'As coordenadas informadas são inválidas.',
              ),
        ),
      );
    });

    test('converte timeout em ApiException', () async {
      final service = ApiService(
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return http.Response('{}', 200);
        }),
        baseUrl: 'https://api.example.test',
        timeout: const Duration(milliseconds: 30),
      );
      addTearDown(service.close);

      await expectLater(service.health(), throwsA(isA<ApiException>()));
    });

    test('converte falha de rede em ApiException', () async {
      final service = ApiService(
        client: MockClient(
          (_) async => throw http.ClientException('sem rota para o host'),
        ),
        baseUrl: 'https://api.example.test',
      );
      addTearDown(service.close);

      await expectLater(service.health(), throwsA(isA<ApiException>()));
    });

    test('rejeita uma resposta que não seja um objeto JSON', () async {
      final service = ApiService(
        client: MockClient((_) async => http.Response('[]', 200)),
        baseUrl: 'https://api.example.test',
      );
      addTearDown(service.close);

      expect(service.health(), throwsFormatException);
    });
  });
}
