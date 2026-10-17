import 'env_config.dart';

/// Configurações separadas por ambiente.
///
/// O cliente consome apenas a URL base da API; configurações de banco ficam
/// restritas ao backend.
class EnvironmentConfig {
  static const Map<String, Object> dev = {
    // 10.0.2.2 aponta para o host no emulador Android.
    'apiBaseUrl': 'http://10.0.2.2:8000',
    'environment': 'development',
  };

  static const Map<String, Object> prod = {
    'apiBaseUrl': EnvConfig.apiBaseUrl,
    'environment': EnvConfig.environment,
  };

  static Map<String, Object> get current => isDevelopment ? dev : prod;

  static bool get isDevelopment => EnvConfig.isDevelopment;
}
