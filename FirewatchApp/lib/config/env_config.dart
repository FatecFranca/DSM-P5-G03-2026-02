/// Configurações de ambiente do aplicativo.
///
/// Apenas informações públicas do cliente ficam aqui. Credenciais de banco de
/// dados pertencem exclusivamente ao backend.
class EnvConfig {
  // URL base da API FireWatch (produção, HTTPS).
  static const String apiBaseUrl =
      'https://firewatch-api.chilecentral.cloudapp.azure.com';

  // Ambiente atual: 'production' ou 'development'.
  static const String environment = 'production';

  static bool get isDevelopment => environment == 'development';

  static String getApiUrl(String endpoint) => '$apiBaseUrl$endpoint';
}
