import 'package:firewatch/config/env_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('produção usa a API HTTPS publicada na Azure', () {
    expect(
      EnvConfig.apiBaseUrl,
      'https://firewatch-api-iago-2026.chilecentral.cloudapp.azure.com',
    );
    expect(Uri.parse(EnvConfig.apiBaseUrl).scheme, 'https');
  });
}
