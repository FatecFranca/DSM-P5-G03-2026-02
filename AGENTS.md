# Regras permanentes do repositório

## Escopo e segurança

- Preserve regras funcionais e contratos da API; mudanças de UI não devem inventar dados.
- Faça a menor alteração que resolva a tarefa e não sobrescreva trabalho alheio.
- Remova código ou dependências somente após confirmar ausência de referências, rotas e testes.
- Nunca exponha credenciais nem versione `.env`, builds, caches ou artefatos de agentes/IA.

## Aplicativo Flutter

- O app fica em `FirewatchApp/`; siga os tokens e componentes já existentes.
- Mantenha acessibilidade AA, semântica de estados e navegação compreensível.
- Valide UI em 320×568, 390×844, 568×320, 768×1024, 1024×768 e 1440×900; inclua fonte 1,4× no telefone compacto.
- Para mudanças de comportamento, escreva primeiro um teste que falhe e depois implemente a correção.

## Verificação obrigatória

Execute em `FirewatchApp/`:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
```

Quando dependências mudarem, execute antes `flutter pub get`. Faça também uma inspeção visual quando houver dispositivo disponível.

## Git

- Confira `git status` e o diff antes de qualquer alteração ou entrega.
- Use commits semânticos em português e mantenha cada commit com um único propósito.
- Não crie commit, push, tag ou pull request sem autorização explícita do usuário.
