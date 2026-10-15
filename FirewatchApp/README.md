# Firewatch

Aplicativo Flutter para acompanhamento do risco de queimadas, com telas de
previsão, mapa, alertas e orientações de prevenção.

## Executar

Na pasta `FirewatchApp`, instale as dependências e inicie o aplicativo:

```sh
flutter pub get
flutter run
```

O endereço base da API está definido em `lib/config/env_config.dart`. O
aplicativo ainda apresenta dados demonstrativos nas telas que não foram
integradas ao backend.

## Verificações

```sh
flutter analyze
flutter test
```
