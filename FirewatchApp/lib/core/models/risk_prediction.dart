import 'package:flutter/material.dart';

import 'risk_level.dart';

/// Leituras meteorológicas atuais retornadas pela API para um ponto.
///
/// Os valores vêm de uma consulta real (`POST /api/v1/prever-risco`) e são
/// exibidos diretamente, sem arredondamentos inventados.
class WeatherReadings {
  const WeatherReadings({
    required this.temperature,
    required this.humidity,
    required this.precipitation,
    required this.windSpeed,
  });

  /// Temperatura do ar em graus Celsius.
  final double temperature;

  /// Umidade relativa do ar em porcentagem.
  final double humidity;

  /// Precipitação da última hora, em milímetros.
  final double precipitation;

  /// Velocidade do vento, em km/h.
  final double windSpeed;

  factory WeatherReadings.fromJson(Map<String, dynamic> json) {
    double read(String key) {
      final value = json[key];
      if (value is num) return value.toDouble();
      throw FormatException('Campo climático ausente ou inválido: $key');
    }

    return WeatherReadings(
      temperature: read('temperatura'),
      humidity: read('umidade_ar'),
      precipitation: read('precipitacao_mm'),
      windSpeed: read('vento_kmh'),
    );
  }
}

/// Resultado completo de uma consulta de risco de queimada.
class RiskPrediction {
  const RiskPrediction({
    required this.latitude,
    required this.longitude,
    required this.weather,
    required this.level,
    required this.probability,
    required this.percentageLabel,
    required this.recommendation,
    this.alertColorHex,
  });

  final double latitude;
  final double longitude;
  final WeatherReadings weather;
  final RiskLevel level;

  /// Probabilidade de 0.0 a 1.0 retornada pelo modelo.
  final double probability;

  /// Texto da porcentagem já formatado pela API (ex.: "72.5%").
  final String percentageLabel;

  final String recommendation;

  /// Cor de alerta informada pela API em hexadecimal (ex.: "#DC2626").
  final String? alertColorHex;

  /// Cor de alerta; usa a cor padrão do nível quando a API não informa.
  Color get alertColor => _parseHexColor(alertColorHex) ?? level.color;

  factory RiskPrediction.fromJson(Map<String, dynamic> json) {
    final localization = _asMap(json['localizacao']);
    final weather = _asMap(json['dados_climaticos']);
    final prediction = _asMap(json['predicao']);

    final rawLevel = prediction['nivel_risco']?.toString() ?? '';
    final probabilityValue = prediction['probabilidade'];
    final probability = probabilityValue is num
        ? probabilityValue.toDouble()
        : double.tryParse(probabilityValue?.toString() ?? '') ??
            _probabilityFromPercent(prediction['porcentagem']);

    return RiskPrediction(
      latitude: _asDouble(localization['latitude']) ?? 0,
      longitude: _asDouble(localization['longitude']) ?? 0,
      weather: WeatherReadings.fromJson(weather),
      level: riskLevelFromApi(rawLevel),
      probability: probability.clamp(0.0, 1.0),
      percentageLabel:
          prediction['porcentagem']?.toString() ?? '${(probability * 100).toStringAsFixed(1)}%',
      recommendation: prediction['recomendacao']?.toString() ?? '',
      alertColorHex: prediction['cor_alerta']?.toString(),
    );
  }
}

/// Converte o texto de nível de risco da API para o enum do aplicativo.
RiskLevel riskLevelFromApi(String value) {
  final normalized = value.trim().toUpperCase();
  if (normalized.startsWith('CR') || normalized == 'CRITICO') {
    return RiskLevel.critical;
  }
  if (normalized.startsWith('MOD')) return RiskLevel.moderate;
  return RiskLevel.low;
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  throw const FormatException('Resposta da API em formato inesperado.');
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

double _probabilityFromPercent(Object? value) {
  final parsed = double.tryParse(
    value?.toString().replaceAll('%', '').trim() ?? '',
  );
  if (parsed == null) return 0;
  return (parsed / 100).clamp(0.0, 1.0);
}

Color? _parseHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  final cleaned = hex.replaceAll('#', '').trim();
  if (cleaned.length != 6 && cleaned.length != 8) return null;
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return null;
  return Color(cleaned.length == 6 ? 0xFF000000 | value : value);
}
