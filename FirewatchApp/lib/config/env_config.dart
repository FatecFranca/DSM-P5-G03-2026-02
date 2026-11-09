/// Configurações de ambiente do aplicativo.
///
/// Apenas informações públicas do cliente ficam aqui. Credenciais de banco de
/// dados pertencem exclusivamente ao backend.
class EnvConfig {
  // URL base da API FireWatch (produção, HTTPS).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue:
        'https://firewatch-api-iago-2026.chilecentral.cloudapp.azure.com',
  );

  /// Permite validar a camada em um backend local antes da implantação.
  static const String regionalApiBaseUrl = String.fromEnvironment(
    'REGIONAL_API_BASE_URL',
    defaultValue: apiBaseUrl,
  );

  // Ambiente atual: 'production' ou 'development'.
  static const String environment = String.fromEnvironment(
    'APP_ENVIRONMENT',
    defaultValue: 'production',
  );

  static bool get isDevelopment => environment == 'development';

  static String getApiUrl(String endpoint) => '$apiBaseUrl$endpoint';
}
