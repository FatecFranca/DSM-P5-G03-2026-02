# Firewatch

Aplicativo Flutter para acompanhamento do risco de queimadas, com telas de
previsão, mapa, alertas e orientações de prevenção.

## Executar

Na pasta `FirewatchApp`, instale as dependências e inicie o aplicativo:

```sh
flutter pub get
flutter run
```

O endereço base da API está definido em `lib/config/env_config.dart`
(`https://firewatch-api.chilecentral.cloudapp.azure.com`). As telas de
onboarding (coordenadas), monitoramento (mapa + condições + previsão de risco)
e o fluxo de entrada consomem a API real. As demais telas ainda usam dados
demonstrativos.

## Verificações

```sh
flutter analyze
flutter test
```
