import 'env_config.dart';

class EnvironmentConfig {
  // Configurações separadas por ambiente
  static const Map<String, Object> dev = {
    'dbHost': 'localhost',
    'dbPort': 5432,
    'apiBaseUrl': 'http://10.0.0.1:8000',
    'environment': 'development',
  };

  static const Map<String, Object> prod = {
    'dbHost': EnvConfig.dbHost,
    'dbPort': EnvConfig.dbPort,
    'apiBaseUrl': EnvConfig.apiBaseUrl,
    'environment': EnvConfig.environment,
  };

  static Map<String, Object> get current => isDevelopment ? dev : prod;

  static bool get isDevelopment => EnvConfig.isDevelopment;
}
