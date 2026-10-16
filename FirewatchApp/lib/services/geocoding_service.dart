import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/models/geo_coordinates.dart';

/// Falha ao resolver o nome do local a partir das coordenadas.
class GeocodingException implements Exception {
  const GeocodingException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Resolve o nome da cidade/estado a partir de coordenadas usando o
/// Nominatim (OpenStreetMap), serviço gratuito que não exige chave de API.
class GeocodingService {
  GeocodingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _userAgent = 'FireWatch/1.0 (projeto integrador)';
  static const Duration _timeout = Duration(seconds: 8);

  static final Map<String, String> _cache = {};

  void close() => _client.close();

  /// Retorna um rótulo legível (ex.: "Franca, SP") ou `null` quando o
  /// serviço não consegue identificar a cidade.
  Future<String?> reverse(GeoCoordinates coordinates) async {
    final key =
        '${coordinates.latitude.toStringAsFixed(4)},${coordinates.longitude.toStringAsFixed(4)}';
    if (_cache.containsKey(key)) return _cache[key];

    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'format': 'jsonv2',
      'lat': coordinates.latitude.toString(),
      'lon': coordinates.longitude.toString(),
      'addressdetails': '1',
      'accept-language': 'pt-BR',
    });

    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: {'User-Agent': _userAgent, 'Accept': 'application/json'})
          .timeout(_timeout);
    } catch (error) {
      throw GeocodingException('Não foi possível consultar o nome do local: $error');
    }

    if (response.statusCode != 200) {
      throw GeocodingException(
        'Serviço de localização retornou o status ${response.statusCode}.',
      );
    }

    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const GeocodingException('Resposta de geocodificação inválida.');
    }

    final label = _labelFrom(decoded);
    _cache[key] = label;
    return label.isEmpty ? null : label;
  }

  String _labelFrom(Map<String, dynamic> payload) {
    final address = payload['address'];
    if (address is! Map) return '';
    final map = address.cast<String, dynamic>();

    final city = _firstNonEmpty([
      map['city'],
      map['town'],
      map['village'],
      map['municipality'],
      map['county'],
    ]);
    final state = _stateCode(map);

    if (city == null) return state ?? '';
    if (state == null) return city;
    return '$city, $state';
  }

  String? _stateCode(Map<String, dynamic> address) {
    final iso = address['ISO3166-2-lvl4']?.toString();
    if (iso != null && iso.contains('-')) {
      return iso.split('-').last;
    }
    return _firstNonEmpty([address['state_code'], address['state']]);
  }

  String? _firstNonEmpty(List<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }
}
