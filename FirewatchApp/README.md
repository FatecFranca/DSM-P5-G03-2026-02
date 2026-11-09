# Firewatch

Aplicativo Flutter para acompanhamento do risco de queimadas, com mapa,
alertas da última consulta e orientações de prevenção.

## Executar

Na pasta `FirewatchApp`, instale as dependências e inicie o aplicativo:

```sh
flutter pub get
flutter run
```

O endereço base da API está definido em `lib/config/env_config.dart`
(`https://firewatch-api-iago-2026.chilecentral.cloudapp.azure.com`). As telas de
onboarding (coordenadas), monitoramento (mapa + condições + previsão de risco)
e o fluxo de entrada consomem a API real.

Para desenvolvimento Android com um backend local:

```sh
flutter run \
  --dart-define=APP_ENVIRONMENT=development \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

## Verificações

```sh
flutter analyze
flutter test
```
