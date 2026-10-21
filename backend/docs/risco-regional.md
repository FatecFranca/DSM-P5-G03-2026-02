# Zonas de risco

`POST /api/v1/risco-regional` recebe o centro da análise:

```json
{"latitude": -20.5386, "longitude": -47.4008}
```

O servidor avalia até nove células estáveis de 0,1° em uma grade 3 × 3, recortada
pela malha simplificada do Brasil do IBGE. O espaçamento é experimental, varia em
quilômetros conforme a latitude e não representa precisão por rua.

A previsão do centro de cada célula representa uma amostra da área. Em células
recortadas cujo centro fica fora do país, utiliza-se um ponto interno ao polígono.
Não há interpolação entre classes, detecção de fogo ou cálculo de propagação.

## Resposta

Retorna uma FeatureCollection GeoJSON com `estado` (`completo`, `parcial` ou
`sem_dados`), `centro`, `bbox` em ordem oeste/sul/leste/norte, `resolucao_graus`,
`versao_modelo` (SHA-256 do artefato carregado), `gerado_em` e `features`.

Cada Feature possui `id`, geometria Polygon/MultiPolygon e `properties`:

- `amostra`: latitude e longitude usadas na inferência.
- `estado`: `ok` ou `sem_dados`.
- `resultado`: o mesmo contrato da consulta pontual, sem reclassificação no cliente.
- `consultado_em`, `expira_em`: validade operacional do resultado.
- `horario_meteorologico`: referência da fonte convertida para UTC, quando disponível.
- `celula_meteorologica`: coordenadas efetivas da fonte, quando disponíveis.

Uma falha não é convertida em risco baixo e não recebe previsão fictícia. Campos
meteorológicos necessários ausentes também tornam a amostra indisponível. O modo
de estimativa climática local é desabilitado para a camada regional.
Valores fora da faixa física também são rejeitados na região. A consulta pontual
preserva o recorte de valores finitos, aplicado antes da validação do schema.

## Limites e operação

- Duas inferências simultâneas e até 32 amostras em andamento por processo.
- Cache de até 256 previsões, por célula/versão, com TTL de cinco minutos.
- Pedidos simultâneos compartilham as mesmas amostras em andamento.
- Até 12 segundos de execução por amostra, além da espera pela vaga.
- Entradas fora do Brasil: 422; fila cheia: 429; modelo indisponível: 503.
- Atualização explícita no aplicativo; gestos no mapa não disparam novas análises.

O TTL não indica a frequência de atualização da Open-Meteo. O aplicativo informa
o centro analisado e os horários, mostra falhas parciais e neutraliza a camada
quando uma de suas previsões vence. A lista de zonas oferece seleção acessível.

Os limites e o cache são locais ao processo. Ao adotar múltiplos workers/réplicas,
coordenar fila e cache em infraestrutura compartilhada. Reiniciar o serviço ao
atualizar o artefato do modelo; não substituir o arquivo de um processo em uso.

## Executar e implantar

Instalar `requirements.txt` no ambiente Python compatível com o artefato, incluindo
Shapely, e disponibilizar o mesmo `ml/modelo.pkl` utilizado na consulta pontual.
Executar a API pelo comando habitual, por exemplo:

```shell
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
python -m pytest tests/test_regional.py -q
```

No Flutter, a rota regional usa a mesma VM da consulta pontual por padrão. Publicar
o backend atualizado antes de disponibilizar a funcionalidade aos usuários. Uma
VM sem a nova rota retorna 404; o app informa que a API precisa ser atualizada.

Para validar um backend regional local no navegador, mantendo a consulta pontual
na VM, usar na pasta `FirewatchApp`:

```shell
flutter run -d edge --dart-define=REGIONAL_API_BASE_URL=http://127.0.0.1:8000
```

Esse backend local precisa de modelo e dados reais; o parâmetro não cria um modelo
local nem simula respostas. O backend deve permitir a origem local nas regras de
CORS. Não usar um endereço HTTP local em uma publicação de produção.

## Verificação

Testes regionais cobrem fronteiras, oceanos/países vizinhos, concorrência,
deduplicação, limites, expiração, versão do modelo e falhas parciais. O Flutter
verifica contrato, seleção, layout reduzido, vencimento e respostas antigas.
Fixtures são restritas aos testes; a aplicação não as utiliza como fallback.

## Proteções e publicação

- `/api/v1/db-test` foi removido; `/health` continua disponível.
- CORS vem bloqueado por padrão. Configure `CORS_ORIGINS` somente com as origens
  web necessárias. `*` não é aceito. O aplicativo Android não depende de CORS.
- Limites padrão por IP/minuto: 60 consultas pontuais e 6 regionais. Ajustar com
  `RISK_RATE_PER_MINUTE` e `REGIONAL_RATE_PER_MINUTE`. Excesso retorna 429 e
  `Retry-After`; preflight não consome a cota.
- O limite é por processo e não substitui autenticação. Em múltiplos workers,
  aplicar limite compartilhado no proxy. Configure o servidor para confiar em
  cabeçalhos de IP encaminhado somente quando vierem do proxy controlado.
- Preserve `.env` e `ml/modelo.pkl` da VM, que não pertencem ao Git. Não treine
  nem troque o modelo só para publicar esta rota. Faça backup antes da atualização.
- Instale as dependências em ambiente compatível com o modelo, confirme que
  `app/data/brasil.geojson` foi publicado e reinicie o serviço pelo mecanismo já
  usado na VM. Se o modelo não carregar, não considere o deploy concluído.
- Depois da publicação, validar `/health`, a rota pontual e a regional com clima
  real. Entradas `NaN`/`Infinity` devem retornar 422 em ambas as rotas.

O workflow de validação executa `flutter analyze`, `flutter test` e `pytest` em
checkout limpo. Os testes de inferência com artefato real são pulados quando ele
não está presente; a regressão com o modelo da VM continua sendo necessária.
