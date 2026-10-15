class EnvConfig {
  // Configurações públicas da API; credenciais do banco ficam no backend.
  static const String dbHost = '57.156.67.130'; // Azure VM IP público
  static const int dbPort = 5432;
  static const String dbName = 'firewatch_db';
  static const String dbUser = 'postgres';

  // URLs da API
  static const String apiBaseUrl = 'http://57.156.67.130:8000';

  // Ambientes disponíveis
  static const String environment = 'production'; // ou 'development'

  // Helper methods
  static bool get isDevelopment => environment == 'development';

  static String getApiUrl(String endpoint) => '$apiBaseUrl$endpoint';
}
