/// Condições meteorológicas de um ponto no tempo.
class WeatherConditions {
  const WeatherConditions({
    required this.temperature,
    required this.humidity,
    required this.precipitation,
    required this.windSpeed,
    required this.windDirection,
  });

  final double temperature;
  final double humidity;
  final double precipitation;
  final double windSpeed;
  final String windDirection;

  WeatherConditions copyWith({
    double? temperature,
    double? humidity,
    double? precipitation,
    double? windSpeed,
    String? windDirection,
  }) {
    return WeatherConditions(
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      precipitation: precipitation ?? this.precipitation,
      windSpeed: windSpeed ?? this.windSpeed,
      windDirection: windDirection ?? this.windDirection,
    );
  }
}

/// Previsão por hora.
class ForecastHour {
  const ForecastHour({
    required this.time,
    required this.weather,
    required this.risk,
  });

  final DateTime time;
  final WeatherConditions weather;
  final double risk;

  String get label => '${time.hour.toString().padLeft(2, '0')}h';
}

/// Previsão por dia.
class ForecastDay {
  const ForecastDay({
    required this.day,
    required this.maxTemperature,
    required this.minTemperature,
    required this.humidity,
    required this.risk,
    required this.weatherLabel,
  });

  final DateTime day;
  final double maxTemperature;
  final double minTemperature;
  final double humidity;
  final double risk;
  final String weatherLabel;

  String get weekdayLabel {
    const days = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    return days[day.weekday - 1];
  }

  String get shortDay {
    const days = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
    return days[day.weekday - 1];
  }
}

/// Fator que compõe a classificação do risco.
class RiskFactor {
  const RiskFactor({
    required this.name,
    required this.description,
    required this.weight,
    required this.percent,
  });

  final String name;
  final String description;

  /// Peso do fator na composição do risco (0 a 100).
  final double weight;

  /// Contribuição percentual deste fator.
  final double percent;
}