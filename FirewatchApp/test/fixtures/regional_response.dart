/// Resposta controlada apenas para testes de contrato e interface.
Map<String, dynamic> regionalResponse({DateTime? now, bool missing = false}) {
  final time = now ?? DateTime.now().toUtc();
  return {
    'type': 'FeatureCollection',
    'estado': missing ? 'sem_dados' : 'completo',
    'centro': {'latitude': -20.5386, 'longitude': -47.4008},
    'bbox': [-47.6, -20.7, -47.3, -20.4],
    'resolucao_graus': 0.1,
    'versao_modelo': 'modelo-teste',
    'gerado_em': time.toIso8601String(),
    'features': [for (var i = 0; i < 9; i++) _feature(i, time, missing)],
  };
}

Map<String, dynamic> _feature(int index, DateTime time, bool missing) {
  final west = -47.6 + (index % 3) * 0.1;
  final south = -20.7 + (index ~/ 3) * 0.1;
  final sample = {'latitude': south + 0.05, 'longitude': west + 0.05};
  return {
    'type': 'Feature',
    'id': 'zona-$index',
    'geometry': {
      'type': 'Polygon',
      'coordinates': [
        [
          [west, south],
          [west + 0.1, south],
          [west + 0.1, south + 0.1],
          [west, south + 0.1],
          [west, south],
        ],
      ],
    },
    'properties': {
      'amostra': sample,
      'estado': missing ? 'sem_dados' : 'ok',
      'consultado_em': missing ? null : time.toIso8601String(),
      'expira_em': missing
          ? null
          : time.add(const Duration(minutes: 5)).toIso8601String(),
      'horario_meteorologico': null,
      'resultado': missing
          ? null
          : {
              'localizacao': sample,
              'dados_climaticos': {
                'temperatura': 30,
                'umidade_ar': 40,
                'precipitacao_mm': 0,
                'vento_kmh': 10,
              },
              'predicao': {
                'probabilidade': 0.1,
                'porcentagem': '10.0%',
                'nivel_risco': 'MODERADO',
                'recomendacao': 'Acompanhe os avisos oficiais.',
                'probabilidades': {
                  'risco_baixo': 0.3,
                  'risco_moderado': 0.6,
                  'risco_critico': 0.1,
                },
              },
            },
    },
  };
}
