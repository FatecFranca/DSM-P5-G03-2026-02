import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/env_config.dart';

class ApiService {
  ApiService({http.Client? client, String baseUrl = EnvConfig.apiBaseUrl})
    : _client = client ?? http.Client(),
      _baseUri = Uri.parse(baseUrl);

  final http.Client _client;
  final Uri _baseUri;

  void close() => _client.close();

  Future<Map<String, dynamic>> dbTest() async {
    final uri = _baseUri.resolve('/api/v1/db-test');
    final response = await _client.get(uri);
    return _decodeResponse(response, uri);
  }

  Future<Map<String, dynamic>> preverRisco(
    double latitude,
    double longitude,
  ) async {
    final uri = _baseUri.resolve('/api/v1/prever-risco');
    final response = await _client.post(
      uri,
      body: jsonEncode({'latitude': latitude, 'longitude': longitude}),
      headers: {'Content-Type': 'application/json'},
    );

    return _decodeResponse(response, uri);
  }

  Map<String, dynamic> _decodeResponse(http.Response response, Uri uri) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'A API retornou o status HTTP ${response.statusCode}.',
        uri,
      );
    }

    final Object? decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw const FormatException('A resposta da API deve ser um objeto JSON.');
  }
}
