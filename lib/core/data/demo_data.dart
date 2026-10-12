import 'package:flutter/material.dart';

import '../models/prevention_tip.dart';
import '../models/risk_alert.dart';
import '../models/risk_level.dart';
import '../models/weather_models.dart';

/// Dados demonstrativos usados apenas para o desenvolvimento da interface.
///
/// Nenhum destes valores representa a realidade: eles existem para que o
/// front-end tenha uma aparência fiel a um aplicativo em produção.
/// Serão substituídos pela API/backend em uma fase futura.
abstract final class DemoSettings {
  static final DateTime lastUpdated = DateTime.now();

  static const double currentRisk = 86.4;
  static const WeatherConditions currentWeather = WeatherConditions(
    temperature: 31.2,
    humidity: 24,
    precipitation: 0.0,
    windSpeed: 18.3,
    windDirection: 'NE',
  );

  static final List<ForecastHour> nextHours = [
    ForecastHour(
      time: DateTime(2024, 1, 1, 0),
      weather: WeatherConditions(temperature: 33.8, humidity: 19, precipitation: 0, windSpeed: 21.0, windDirection: 'NE'),
      risk: 91.2,
    ),
    ForecastHour(
      time: DateTime(2024, 1, 1, 1),
      weather: WeatherConditions(temperature: 34.6, humidity: 17, precipitation: 0, windSpeed: 23.5, windDirection: 'N'),
      risk: 93.8,
    ),
    ForecastHour(
      time: DateTime(2024, 1, 1, 2),
      weather: WeatherConditions(temperature: 33.1, humidity: 20, precipitation: 0, windSpeed: 19.8, windDirection: 'NE'),
      risk: 88.5,
    ),
    ForecastHour(
      time: DateTime(2024, 1, 1, 3),
      weather: WeatherConditions(temperature: 31.8, humidity: 24, precipitation: 0, windSpeed: 17.2, windDirection: 'L'),
      risk: 84.0,
    ),
    ForecastHour(
      time: DateTime(2024, 1, 1, 4),
      weather: WeatherConditions(temperature: 29.5, humidity: 31, precipitation: 0, windSpeed: 14.6, windDirection: 'L'),
      risk: 76.3,
    ),
    ForecastHour(
      time: DateTime(2024, 1, 1, 5),
      weather: WeatherConditions(temperature: 27.9, humidity: 38, precipitation: 0, windSpeed: 12.1, windDirection: 'SE'),
      risk: 68.9,
    ),
    ForecastHour(
      time: DateTime(2024, 1, 1, 6),
      weather: WeatherConditions(temperature: 26.4, humidity: 44, precipitation: 0, windSpeed: 10.3, windDirection: 'SE'),
      risk: 61.5,
    ),
    ForecastHour(
      time: DateTime(2024, 1, 1, 7),
      weather: WeatherConditions(temperature: 25.7, humidity: 49, precipitation: 0, windSpeed: 9.4, windDirection: 'S'),
      risk: 55.2,
    ),
    ForecastHour(
      time: DateTime(2024, 1, 1, 8),
      weather: WeatherConditions(temperature: 26.9, humidity: 45, precipitation: 0, windSpeed: 10.1, windDirection: 'S'),
      risk: 58.7,
    ),
    ForecastHour(
      time: DateTime(2024, 1, 1, 9),
      weather: WeatherConditions(temperature: 29.0, humidity: 36, precipitation: 0, windSpeed: 12.8, windDirection: 'SE'),
      risk: 66.4,
    ),
    ForecastHour(
      time: DateTime(2024, 1, 1, 10),
      weather: WeatherConditions(temperature: 31.6, humidity: 27, precipitation: 0, windSpeed: 15.9, windDirection: 'NE'),
      risk: 78.1,
    ),
    ForecastHour(
      time: DateTime(2024, 1, 1, 11),
      weather: WeatherConditions(temperature: 33.6, humidity: 20, precipitation: 0, windSpeed: 18.8, windDirection: 'NE'),
      risk: 86.4,
    ),
  ];

  static List<ForecastDay> get nextDays {
    final today = DateTime.now();
    return List.generate(7, (i) {
      final day = today.add(Duration(days: i + 1));
      const risks = [72.0, 81.5, 64.2, 55.0, 48.6, 69.3, 77.8];
      const maxT = [32.5, 34.1, 30.8, 28.9, 27.4, 31.0, 33.5];
      const minT = [19.4, 20.8, 18.9, 17.2, 16.8, 19.1, 21.3];
      const hum = [30.0, 26.0, 40.0, 52.0, 58.0, 38.0, 29.0];
      const labels = ['Céu limpo', 'Sol forte', 'Parcialmente nublado', 'Nublado', 'Nublado', 'Sol entre nuvens', 'Sol forte'];
      return ForecastDay(
        day: day,
        maxTemperature: maxT[i],
        minTemperature: minT[i],
        humidity: hum[i],
        risk: risks[i],
        weatherLabel: labels[i],
      );
    });
  }

  /// Evolução estimada do risco para os próximos dias.
  static List<ForecastDay> get riskEvolution => nextDays;

  static final DateTime now = DateTime.now();

  static List<RiskAlert> makeAlerts() {
    final n = now;
    return [
      RiskAlert(
        id: 'al-01',
        severity: RiskLevel.critical,
        title: 'Risco crítico de queimada',
        description:
            'Condições meteorológicas indicam alta probabilidade de incêndios em vegetação seca nas próximas 24 horas.',
        location: 'Região Sul de Franca, SP',
        time: n.subtract(const Duration(minutes: 38)),
        isRead: false,
      ),
      RiskAlert(
        id: 'al-02',
        severity: RiskLevel.moderate,
        title: 'Umidade do ar em níveis moderados',
        description:
            'A umidade relativa do ar atingiu 24%. É recomendável evitar queimadas controladas e soltar balões.',
        location: 'Centro de Franca, SP',
        time: n.subtract(const Duration(hours: 2)),
        isRead: false,
      ),
      RiskAlert(
        id: 'al-03',
        severity: RiskLevel.moderate,
        title: 'Rajadas de vento acima do normal',
        description:
            'Rajadas de até 24 km/h foram registradas. Ventos fortes favorecem a propagação rápida de chamas.',
        location: 'Franca, SP',
        time: n.subtract(const Duration(hours: 5)),
        isRead: true,
      ),
      RiskAlert(
        id: 'al-04',
        severity: RiskLevel.low,
        title: 'Previsão de chuva isolada',
        description:
            'Possibilidade de chuva isolada no fim de semana, com alívio temporário das condições de seca.',
        location: 'Zona Norte de Franca, SP',
        time: n.subtract(const Duration(days: 1)),
        isRead: true,
        extra: true,
      ),
    ];
  }

  static const List<RiskFactor> riskFactors = [
    RiskFactor(
      name: 'Vegetação seca',
      description: 'Acúmulo de biomassa seca aumenta a inflamabilidade da vegetação.',
      weight: 90,
      percent: 28,
    ),
    RiskFactor(
      name: 'Baixa umidade',
      description: 'Umidade relativa do ar abaixo de 30% facilita a propagação de chamas.',
      weight: 85,
      percent: 26,
    ),
    RiskFactor(
      name: 'Temperatura alta',
      description: 'Calor intenso eleva o potencial de ignição de materiais orgânicos.',
      weight: 78,
      percent: 24,
    ),
    RiskFactor(
      name: 'Ventos moderados',
      description: 'Ventos acima de 15 km/h aceleram a expansão do fogo.',
      weight: 72,
      percent: 22,
    ),
  ];

  static const String riskMeaning =
      'O índice de risco é calculado a partir de variáveis meteorológicas e de vegetação. '
      'Quanto maior o percentual, maiores as chances de ocorrência e propagação de queimadas '
      'na região. Valores acima de 70% indicam condições críticas.';

  static const List<PreventionTip> preventionTips = [
    PreventionTip(
      icon: Icons.local_fire_department_outlined,
      title: 'Prevenção de queimadas',
      description:
          'Não queime lixo, entulho ou vegetação. Denuncie queimadas irregulares à Defesa Civil pelo 199.',
      emphasis: true,
    ),
    PreventionTip(
      icon: Icons.water_drop_outlined,
      title: 'Cuidados na baixa umidade',
      description:
          'Com umidade abaixo de 30%, evite atividades que gerem faísca e mantenha recipientes com água em áreas secas.',
    ),
    PreventionTip(
      icon: Icons.yard_outlined,
      title: 'Riscos em áreas de vegetação',
      description:
          'Descartar bitucas de cigarro e garrafas de vidro em áreas verdes é uma das principais causas de incêndio.',
    ),
    PreventionTip(
      icon: Icons.smoke_free_outlined,
      title: 'Ao identificar fumaça',
      description:
          'Identifique a direção do vento, mantenha distância e nunca tente combater o fogo sozinho.',
    ),
    PreventionTip(
      icon: Icons.support_agent_outlined,
      title: 'Como comunicar às autoridades',
      description:
          'Ligue para o Corpo de Bombeiros (193) ou a Defesa Civil (199) informando endereço, ponto de referência e intensidade.',
    ),
  ];
}