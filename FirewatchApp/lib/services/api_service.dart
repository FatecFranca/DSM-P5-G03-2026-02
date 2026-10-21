import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/env_config.dart';

/// Erro devolvido pela API FireWatch ou pela camada de rede.
///
/// Estende [http.ClientException] para preservar o contrato de erros de
/// transporte já usado pelo aplicativo, acrescentando o status HTTP e a
/// mensagem amigável informada pela API (campo `detail`).
class ApiException extends http.ClientException {
  ApiException(String message, {this.statusCode, Uri? uri})
    : super(message, uri);

  /// Código HTTP retornado pela API (nulo em falhas de rede/timeout).
  final int? statusCode;

  @override
  String toString() => message;
}

/// Cliente HTTP da API FireWatch.
///
/// Endpoints disponíveis (conforme o Swagger da API):
/// - `GET /health`
/// - `GET /`
/// - `GET /api/v1/db-test`
/// - `POST /api/v1/prever-risco`
class ApiService {
  ApiService({
    http.Client? client,
    String baseUrl = EnvConfig.apiBaseUrl,
    Duration timeout = _defaultTimeout,
    String? regionalBaseUrl,
  }) : _client = client ?? http.Client(),
       _baseUri = Uri.parse(baseUrl),
       _regionalBaseUri = Uri.parse(
         regionalBaseUrl ??
             (baseUrl == EnvConfig.apiBaseUrl
                 ? EnvConfig.regionalApiBaseUrl
                 : baseUrl),
       ),
       _timeout = timeout;

  final http.Client _client;
  final Uri _baseUri;
  final Uri _regionalBaseUri;

  /// Tempo máximo de espera por resposta da API.
  final Duration _timeout;

  static const Duration _defaultTimeout = Duration(seconds: 20);

  void close() => _client.close();

  /// Uma requisição regional, com quantidade de células controlada pelo servidor.
  Future<Map<String, dynamic>> preverRegiao(double latitude, double longitude) {
    final uri = _regionalBaseUri.resolve('/api/v1/risco-regional');
    return _send(
      () => _client.post(
        uri,
        body: jsonEncode({'latitude': latitude, 'longitude': longitude}),
        headers: {'Content-Type': 'application/json'},
      ),
      uri,
      timeout: const Duration(seconds: 75),
    );
  }

  /// Verifica a saúde do serviço e do modelo de previsão.
  Future<Map<String, dynamic>> health() {
    final uri = _baseUri.resolve('/health');
    return _send(() => _client.get(uri), uri);
  }

  /// Testa a conexão da API com o banco de dados.
  Future<Map<String, dynamic>> dbTest() {
    final uri = _baseUri.resolve('/api/v1/db-test');
    return _send(() => _client.get(uri), uri);
  }

  /// Prediz o risco de incêndio para as coordenadas informadas.
  Future<Map<String, dynamic>> preverRisco(double latitude, double longitude) {
    final uri = _baseUri.resolve('/api/v1/prever-risco');
    return _send(
      () => _client.post(
        uri,
        body: jsonEncode({'latitude': latitude, 'longitude': longitude}),
        headers: {'Content-Type': 'application/json'},
      ),
      uri,
    );
  }

  /// Executa a requisição aplicando timeout e convertendo falhas de rede em
  /// [ApiException] com mensagem amigável.
  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
    Uri uri, {
    Duration? timeout,
  }) async {
    final http.Response response;
    try {
      response = await request().timeout(timeout ?? _timeout);
    } on TimeoutException {
      throw ApiException(
        'Tempo de conexão esgotado. Verifique sua internet e tente novamente.',
        uri: uri,
      );
    } catch (_) {
      throw ApiException(
        'Não foi possível conectar ao serviço. Verifique sua conexão.',
        uri: uri,
      );
    }

    return _decodeResponse(response, uri);
  }

  Map<String, dynamic> _decodeResponse(http.Response response, Uri uri) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _messageFor(response),
        statusCode: response.statusCode,
        uri: uri,
      );
    }

    final Object? decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();

    throw const FormatException('A resposta da API deve ser um objeto JSON.');
  }

  /// Mensagem amigável para respostas de erro, priorizando o campo `detail`
  /// quando a API informa um texto.
  String _messageFor(http.Response response) {
    final detail = _detailFrom(response.body);
    if (detail != null && detail.isNotEmpty) return detail;

    return switch (response.statusCode) {
      400 => 'Requisição inválida.',
      404 => 'Recurso não encontrado na API.',
      422 => 'As coordenadas informadas são inválidas.',
      429 => 'Muitas regiões em análise. Aguarde e tente novamente.',
      500 => 'Erro interno no serviço. Tente novamente mais tarde.',
      503 =>
        'Serviço de previsão indisponível no momento. Tente novamente mais tarde.',
      _ => 'A API retornou o status HTTP ${response.statusCode}.',
    };
  }

  String? _detailFrom(String body) {
    if (body.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] is String) {
        final detail = (decoded['detail'] as String).trim();
        if (detail.isNotEmpty) return detail;
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}
