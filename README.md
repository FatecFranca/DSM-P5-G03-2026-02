# FireWatch

> **Veja o risco antes do fogo.**

O **FireWatch** é um projeto acadêmico de monitoramento e previsão de risco de queimadas.
O sistema recebe as coordenadas de um local, consulta dados meteorológicos em tempo real,
aplica um modelo de Machine Learning e devolve o nível de risco com probabilidades e
recomendações de prevenção.

O projeto é composto por um **aplicativo mobile em Flutter** e por uma **API em FastAPI**
com uma **Regressão Logística balanceada** treinada a partir do dataset preprocessado
em PostgreSQL.

**Equipe:** G03 — FireWatch  
**Curso:** Desenvolvimento de Software Multiplataforma (DSM) — Fatec Franca  
**Projeto Integrador:** 5º semestre — 2026/2  
**Repositório:** <https://github.com/FatecFranca/DSM-P5-G03-2026-02>

---

## Sumário

- [Sobre o projeto](#sobre-o-projeto)
- [Como funciona](#como-funciona)
- [Funcionalidades](#funcionalidades)
- [Arquitetura](#arquitetura)
- [Tecnologias](#tecnologias)
- [Estrutura do repositório](#estrutura-do-repositório)
- [Executando o projeto](#executando-o-projeto)
- [Configuração do backend](#configuração-do-backend)
- [API](#api)
- [Modelo de Machine Learning](#modelo-de-machine-learning)
- [Testes](#testes)
- [Estado atual e próximos passos](#estado-atual-e-próximos-passos)
- [Equipe](#equipe)

---

## Sobre o projeto

Queimadas e incêndios florestais causam impactos ambientais, econômicos e à saúde da
população. O FireWatch foi desenvolvido para facilitar o acesso a uma estimativa de risco
antes que uma ocorrência aconteça.

A partir de uma latitude e longitude, o sistema:

1. consulta a **Open-Meteo** para obter as condições atuais e o histórico recente de chuva;
2. transforma os dados meteorológicos nas features usadas pelo modelo;
3. aplica uma **Regressão Logística balanceada** treinada com dados históricos de risco;
4. retorna a classe de risco — **Baixo**, **Moderado** ou **Crítico** —, as probabilidades de
   cada classe, uma cor de alerta e uma recomendação;
5. apresenta o resultado no aplicativo, junto com os dados climáticos que sustentam a previsão.

> **Aviso:** o FireWatch é uma ferramenta acadêmica de apoio à informação. Ele não substitui
> os órgãos oficiais de defesa civil, bombeiros ou monitoramento ambiental. Em emergências,
> ligue **193 (Bombeiros)** ou **199 (Defesa Civil)**.

---

## Como funciona

```mermaid
flowchart LR
    A[App Flutter] -->|GPS ou coordenadas manuais| B[POST /api/v1/prever-risco]
    B --> C[API FastAPI]
    C -->|Clima atual + 60 dias de chuva| D[Open-Meteo]
    C --> E[Features meteorológicas]
    E --> F[modelo logístico - artefato joblib]
    F --> G[Classe + probabilidades + recomendação]
    G --> A
    C -->|Consultas históricas / health| H[(PostgreSQL)]
    A -->|Nome da cidade| I[Nominatim]
    A -->|Mapa| J[Tiles OpenStreetMap]
```

Fluxo resumido:

```text
GPS / coordenadas
        ↓
Open-Meteo (clima atual + histórico de precipitação)
        ↓
Engenharia de features (4 variáveis)
        ↓
Regressão Logística (3 classes de risco)
        ↓
Risco Baixo / Moderado / Crítico + probabilidades + recomendação
        ↓
Aplicativo Flutter
```

---

## Funcionalidades

### Aplicativo mobile

- **Splash screen** com identidade visual do projeto.
- **Onboarding de localização** com duas opções:
  - solicitar a localização do aparelho via GPS (`geolocator`);
  - informar latitude e longitude manualmente.
- **Tela de monitoramento** (aba "Início"):
  - mapa interativo com tiles do OpenStreetMap centrado nas coordenadas informadas;
  - nome da cidade/estado obtido por geocodificação reversa (Nominatim);
  - painel com temperatura, umidade, precipitação e vento;
  - botão **"Verificar risco aqui"**, que consulta a API real e exibe o resultado.
- **Previsão** com gráficos de temperatura, umidade e evolução do risco por hora e por dia.
- **Mapa de risco** com filtros por nível, legenda e pontos ilustrativos.
- **Alertas** com filtros por severidade e marcação de lidos/não lidos.
- **Prevenção** com orientações de segurança e telefones de emergência.
- **Configurações** de tema claro/escuro, localização e preferências de notificação.
- **Detalhes do risco** com fatores relacionados e gráfico de evolução estimada.
- Suporte a **tema claro e escuro**.

> As telas de previsão, mapa de risco, alertas, prevenção e detalhes do risco ainda usam
> dados demonstrativos. A integração real com a API está implementada no onboarding de
> coordenadas e na tela de monitoramento.

### Backend

- API REST com **FastAPI** e documentação automática em `/docs` e `/redoc`.
- Endpoint de predição a partir de latitude/longitude.
- Consulta à **Open-Meteo** com:
  - cache em memória por coordenada;
  - timeout configurável;
  - repetição automática em falhas de rede e erros `5xx`;
  - modo de fallback offline opcional para desenvolvimento.
- Validação de coordenadas com **Pydantic**.
- Classificação em três níveis com probabilidades, cor e recomendação.
- Health check com estado do modelo e do banco de dados.
- Dataset histórico oficial consultável com filtros, paginação e estatísticas.
- Pool de conexões assíncrono com **asyncpg**.
- CORS configurável por variáveis de ambiente.
- Modelo logístico balanceado validado temporalmente em setembro de 2024.

---

## Arquitetura

O repositório é dividido em dois projetos independentes:

| Projeto | Responsabilidade |
| --- | --- |
| `FirewatchApp/` | Aplicativo mobile em Flutter/Dart |
| `backend/` | API FastAPI, integração com Open-Meteo, acesso ao PostgreSQL e pipeline de ML |

O aplicativo não acessa o banco de dados diretamente. Credenciais e regras de negócio ficam
exclusivamente no backend. A comunicação ocorre por HTTPS com a API, e a API utiliza a
Open-Meteo e o modelo local para produzir a resposta.

A URL reservada para o ambiente de produção é:

```text
https://firewatch-api-iago-2026.chilecentral.cloudapp.azure.com
```

---

## Tecnologias

### Mobile

| Tecnologia | Uso |
| --- | --- |
| **Flutter / Dart** (`SDK >= 3.10`) | Desenvolvimento do aplicativo |
| **Riverpod** | Gerenciamento de estado |
| **go_router** | Navegação e rotas |
| **flutter_map + latlong2** | Mapa interativo |
| **geolocator** | Localização por GPS |
| **http** | Consumo da API |
| **google_fonts / flutter_svg** | Tipografia e ícones vetoriais |

### Backend e Machine Learning

| Tecnologia | Uso |
| --- | --- |
| **Python 3.11+** (validado em 3.13) | Linguagem do backend |
| **FastAPI + Uvicorn** | API HTTP assíncrona |
| **Pydantic v2** | Validação e schemas |
| **asyncpg** | Acesso assíncrono ao PostgreSQL |
| **httpx** | Cliente HTTP para a Open-Meteo |
| **scikit-learn** | Regressão Logística, padronização e métricas |
| **pandas / numpy / scipy** | Manipulação e análise dos dados |
| **joblib** | Carregamento do modelo logístico (`*.joblib`) |
| **python-dotenv** | Carregamento do arquivo `.env` |
| **pytest** | Testes automatizados |

### Serviços externos

| Serviço | Uso |
| --- | --- |
| **Open-Meteo** | Clima atual e histórico de precipitação |
| **Nominatim (OpenStreetMap)** | Geocodificação reversa de coordenadas |
| **OpenStreetMap** | Tiles do mapa na tela de monitoramento |
| **PostgreSQL** | Dataset de treinamento e diagnóstico de conexão |

Nenhum desses serviços exige chave de API para as funcionalidades utilizadas.

---

## Estrutura do repositório

```text
DSM-P5-G03-2026-02/
├── backend/
│   ├── app/
│   │   ├── main.py                 # Criação da API, health check e lifespan
│   │   ├── config.py               # Configurações via variáveis de ambiente
│   │   ├── db.py                   # Pool de conexões PostgreSQL
│   │   ├── models/                 # Schemas de entrada e saída
│   │   ├── routes/dataset.py       # Consulta ao dataset histórico
│   │   ├── routes/risk.py          # Endpoint /api/v1/prever-risco
│   │   └── services/
│   │       ├── weather_service.py  # Integração com a Open-Meteo
│   │       ├── prediction_service.py # Carga e execução do modelo
│   │       └── classificacao.py    # Recomendações e rótulos de risco
│   ├── ml/
│   │   ├── alvo.py                 # Definição das classes e cortes
│   │   ├── dados.py                # Leitura do dataset no PostgreSQL
│   │   ├── features.py             # Engenharia de features
│   │   ├── treinamento.py          # Pipeline legado, não usado no deploy
│   │   ├── avaliacao.py            # Avaliação e cenários climáticos
│   │   └── modelo_risco_fogo_logistica.joblib # Artefato externo ao Git
│   ├── tests/
│   │   ├── test_api.py
│   │   └── test_fallback.py
│   ├── requirements.txt
│   ├── migrations/                 # Schema PostgreSQL versionado
│   ├── scripts/                    # Migration e importação reproduzível
│   ├── ruff.toml
│   └── .env.example
└── FirewatchApp/
    ├── lib/
    │   ├── main.dart
    │   ├── app.dart
    │   ├── config/                 # URL da API e ambientes
    │   ├── core/                   # Tema, modelos, roteador e providers
    │   ├── features/               # Telas por funcionalidade
    │   ├── services/               # API, localização e geocodificação
    │   └── shared/widgets/         # Componentes reutilizáveis
    ├── test/
    │   ├── api_service_test.dart
    │   └── widget_test.dart
    ├── pubspec.yaml
    └── README.md
```

---

## Executando o projeto

### Pré-requisitos

- **Flutter** 3.x com Dart `>= 3.10`
- **Python** 3.11 ou superior
- **PostgreSQL** (necessário para treinar o modelo e testar a conexão com o banco)
- Um emulador ou dispositivo para executar o aplicativo

O backend consegue iniciar em modo degradado sem o banco disponível. O endpoint de predição
também exige o artefato `modelo_risco_fogo_logistica.joblib`, gerado pelo trabalho de Machine
Learning. Ele é ignorado pelo Git e deve ser transferido separadamente para cada ambiente.

### 1. Backend

No Windows:

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

No Linux/macOS:

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Depois de iniciar:

- API: <http://127.0.0.1:8000>
- Documentação Swagger: <http://127.0.0.1:8000/docs>
- Health check: <http://127.0.0.1:8000/health>

Edite o arquivo `backend/.env` com as credenciais do seu PostgreSQL antes de usar os
endpoints que dependem do banco ou de treinar o modelo.

### 2. Dataset histórico no PostgreSQL

Com o PostgreSQL iniciado e o `.env` configurado, aplique o schema e importe o arquivo
oficial. O caminho do CSV é configurável; o importador valida o cabeçalho e cada valor,
processa em lotes e pode ser reexecutado sem duplicar registros:

```bash
cd backend
python -m scripts.aplicar_migrations
python -m scripts.importar_dataset \
  --arquivo "/caminho/para/firewatch_preprocessado.csv"
```

O arquivo esperado possui as colunas `linha_origem`, `data`, `municipio`, `estado`, `bioma`,
`avg_numero_dias_sem_chuva`, `avg_precipitacao`, `avg_risco_fogo`, `avg_frp` e
`bioma_ausente_original`, nessa ordem. O dataset não é versionado no Git. Na implantação,
ele deve ser transferido separadamente para a VM, importado no PostgreSQL e pode ser removido
da VM depois da conferência da importação e do backup.

### 3. Modelo de Machine Learning

O backend não retreina o modelo durante a instalação. Transfira o artefato final por canal
seguro e configure seu caminho no `.env`:

```dotenv
MODEL_PATH=/opt/firewatch/modelo_risco_fogo_logistica.joblib
```

### 4. Aplicativo Flutter

```bash
cd FirewatchApp
flutter pub get
flutter run
```

Na fase de integração mobile, configure a API de produção em
`FirewatchApp/lib/config/env_config.dart` com:

```dart
static const String apiBaseUrl =
    'https://firewatch-api-iago-2026.chilecentral.cloudapp.azure.com';
```

Para usar um backend local, altere essa constante para o endereço correspondente:

```dart
// Emulador Android
static const String apiBaseUrl = 'http://10.0.2.2:8000';

// Simulador iOS, desktop ou dispositivo físico na mesma rede
static const String apiBaseUrl = 'http://localhost:8000';
```

> Em dispositivos físicos, use o IP da máquina na rede local em vez de `localhost`.
> Para HTTP sem TLS, pode ser necessário ajustar a configuração de segurança de rede
> da plataforma.

---

## Configuração do backend

As configurações são carregadas de `backend/.env` por `pydantic-settings` e
`python-dotenv`. Use `backend/.env.example` como base.

| Variável | Padrão | Descrição |
| --- | --- | --- |
| `OPEN_METEO_URL` | `https://api.open-meteo.com/v1/forecast` | URL da API de clima |
| `OPEN_METEO_TIMEOUT` | `10` | Timeout das requisições, em segundos |
| `CACHE_TTL_SEGUNDOS` | `300` | Tempo de cache do clima por coordenada |
| `PERMITIR_FALLBACK_CLIMA` | `false` | Usa estimativa offline quando a Open-Meteo falha |
| `CORS_ORIGINS` | vazio | Origens web explícitas, separadas por vírgula; sem curingas |
| `RISK_RATE_PER_MINUTE` | `60` | Consultas pontuais por IP/minuto em cada processo |
| `REGIONAL_RATE_PER_MINUTE` | `6` | Consultas regionais por IP/minuto em cada processo |
| `DB_HOST` | `localhost` | Host do PostgreSQL |
| `DB_PORT` | `5432` | Porta do PostgreSQL |
| `DB_NAME` | `firewatch_db` | Nome do banco |
| `DB_USER` | `postgres` | Usuário do banco |
| `DB_PASSWORD` | vazio | Senha do banco |
| `DB_POOL_MIN` | `1` | Mínimo de conexões no pool |
| `DB_POOL_MAX` | `5` | Máximo de conexões no pool |
| `DB_CONNECT_TIMEOUT` | `10` | Timeout para obter/conectar ao banco, em segundos |
| `DB_COMMAND_TIMEOUT` | `30` | Timeout padrão das consultas, em segundos |
| `MODEL_PATH` | vazio | Caminho do artefato logístico externo ao Git |

> O fallback climático é destinado a desenvolvimento e demonstrações offline. Em produção,
> mantenha `PERMITIR_FALLBACK_CLIMA=false` para não mascarar indisponibilidades da fonte real.

---

## API

### Endpoints

| Método | Endpoint | Descrição |
| --- | --- | --- |
| `GET` | `/` | Informações gerais da API |
| `GET` | `/health` | Estado do serviço, do modelo e do banco |
| `POST` | `/api/v1/prever-risco` | Predição de risco para uma coordenada |
| `POST` | `/api/v1/risco-regional` | Até nove zonas de risco com recorte territorial e cache |
| `GET` | `/api/v1/dados` | Registros históricos filtrados e paginados |
| `GET` | `/api/v1/dados/estatisticas` | Agregações do dataset histórico |
| `GET` | `/docs` | Documentação Swagger UI |
| `GET` | `/redoc` | Documentação ReDoc |
| `GET` | `/openapi.json` | Especificação OpenAPI |

### Exemplo de requisição

```bash
curl -X POST http://localhost:8000/api/v1/prever-risco \
  -H "Content-Type: application/json" \
  -d '{"latitude": -20.5386, "longitude": -47.4008}'
```

### Exemplo de resposta

```json
{
  "status": "sucesso",
  "localizacao": {
    "latitude": -20.5386,
    "longitude": -47.4008
  },
  "dados_climaticos": {
    "temperatura": 31.0,
    "umidade_ar": 25.0,
    "precipitacao_mm": 0.0,
    "vento_kmh": 18.0
  },
  "predicao": {
    "probabilidade": 0.87,
    "porcentagem": "87.0%",
    "nivel_risco": "CRÍTICO",
    "classe": "Risco Crítico",
    "cor_alerta": "#DC2626",
    "recomendacao": "Alerta máximo. Evite qualquer tipo de queimada de manejo e reporte focos de fumaça à Defesa Civil.",
    "probabilidades": {
      "risco_baixo": 0.02,
      "risco_moderado": 0.11,
      "risco_critico": 0.87
    }
  }
}
```

> Valores ilustrativos. A resposta real varia conforme as condições meteorológicas do local
> e o resultado do modelo.

### Códigos de erro relevantes

| Status | Situação |
| --- | --- |
| `422` | Coordenadas ausentes, inválidas ou fora dos limites |
| `503` | Open-Meteo indisponível ou modelo não carregado |

---

## Modelo de Machine Learning

### Dataset histórico oficial

A tabela `firewatch_preprocessado` mantém os 157.682 registros oficiais de 1º de janeiro a
9 de setembro de 2024. A importação preserva os valores finais sem recalcular classes.

### Variáveis de entrada

| Feature | Descrição |
| --- | --- |
| `avg_numero_dias_sem_chuva` | Quantidade média de dias sem chuva |
| `precipitacao_mm_estimada` | Precipitação convertida para milímetros |
| `dia_ano_seno` | Componente sazonal seno do dia do ano |
| `dia_ano_cosseno` | Componente sazonal cosseno do dia do ano |

A ordem das features de inferência é definida em `backend/ml/modelo_logistico.py` e validada
contra os metadados armazenados no artefato.

### Classes de risco

O alvo é derivado do percentil de `risco_fogo`, convertido em um índice de **0 a 100** e
dividido em três classes:

| Índice | Classe | Nível na API | Cor |
| --- | --- | --- | --- |
| `0 – 29,9` | Risco Baixo | `BAIXO` | `#22C55E` |
| `30 – 69,9` | Risco Moderado | `MODERADO` | `#FACC15` |
| `70 – 100` | Risco Crítico | `CRÍTICO` | `#DC2626` |

Os cortes oficiais ficam em `backend/ml/alvo.py` e são compartilhados por treinamento,
avaliação e API.

### Treinamento

- Algoritmo: `LogisticRegression` com `class_weight="balanced"`
- Pré-processamento: preenchimento pela mediana e `StandardScaler`
- `random_state`: `42`
- Confirmação temporal: registros de 1 a 9 de setembro de 2024
- Acurácia: `84,32%`
- Acurácia balanceada: `52,99%`
- F1 macro: `52,93%`
- Recall da classe Crítico: `91,99%`

O artefato final é `modelo_risco_fogo_logistica.joblib`. O backend apenas valida e executa
esse artefato; o processo científico permanece no projeto de Machine Learning.

---

## Testes

### Backend

```bash
cd backend
python -m pytest -q
```

Os testes reais com o PostgreSQL importado são opt-in para manter a suíte unitária portátil:

```bash
FIREWATCH_TEST_DATABASE=1 python -m pytest -q tests/test_dataset_integration.py
```

A suíte cobre:

- engenharia e normalização das features;
- definição das classes, cortes e rótulos;
- respostas da API, validação de coordenadas e documentação;
- validação, importação, filtros, paginação e estatísticas do dataset histórico;
- consistência entre classe prevista e probabilidades;
- cache, timeout, retry e fallback da Open-Meteo;
- endpoints de health e teste de banco.

### Aplicativo

```bash
cd FirewatchApp
flutter analyze
flutter test
```

Os testes cobrem:

- navegação da splash para o onboarding e entre as abas;
- preenchimento manual de coordenadas;
- abertura da tela de monitoramento com dados simulados da API;
- mensagens de erro quando a API falha;
- timeout, falhas de rede e respostas inválidas no cliente HTTP.

---

## Estado atual e próximos passos

### Implementado

- Backend FastAPI com predição real e documentação automática.
- Integração com Open-Meteo, cache, retry e fallback configurável.
- Modelo logístico externo ao Git, validado e carregado pela API.
- Aplicativo Flutter com onboarding por GPS ou coordenadas manuais.
- Tela de monitoramento com mapa, clima atual e risco real.
- Testes automatizados no backend e no aplicativo.

### Em evolução

- Substituir os dados demonstrativos das telas de previsão, alertas e mapa de risco por
  dados reais.
- Persistir preferências e alertas do usuário.
- Implementar notificações push.
- Ampliar a cobertura de testes de interface.
- Adicionar autenticação e histórico de consultas.
- Automatizar o deploy e a integração contínua.

---

## Equipe

**Equipe G03 — FireWatch**

| Integrante |
| --- |
| **Iago Pinheiro Rodrigues** |
| **Kaio Leandro Rissato** |
| **Pedro Henrique Xavier Constancio** |

Projeto desenvolvido para o **Projeto Integrador do 5º semestre** do curso de
**Desenvolvimento de Software Multiplataforma (DSM)** da **Fatec Franca**, turma **2026/2**.

---

Projeto acadêmico desenvolvido para fins educacionais.
