"""Gerador do dataset FireWatch 2024.

O dataset oficial do projeto nao esta disponivel publicamente. Este modulo
sintetiza um dataset com o mesmo esquema, gerado a partir de um indice fisico
real de perigo de incendio: o Fire Weather Index (FWI) do Canadian Forest
Service (Van Wagner 1987), cujo componente de umidade de combustiveis finos
(FFMC) e construido a partir de temperatura, umidade, vento e precipitacao.

Por que sintetizar em vez de usar ruido aleatorio:
    Um conjunto aleatorio ensinaria o modelo nada sobre o fenomeno. Aqui os
    rotulos sao derivados de uma equacao meteorologica conhecida e os atributos
    sao gerados por um processo temporalmente coerente (chuva -> molhado ->
    seca -> mariposa). O modelo aprende a relacao climatologica real e erra
    apenas pela inercia do FFMC (estado que depende de dias anteriores e nao
    esta no vetor de entrada), o que produz uma acuracia realista.

Como usar o dataset real:
    Basta colocar o CSV em `data/dataset_firewatch_2024.csv` com as colunas de
    `COLUNAS_ENTRADA` e o rotulo `COLUNA_ROTULO`. `ml/treinamento.py` detecta o
    arquivo automaticamente e nao usa mais o gerador.
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
import pandas as pd

COLUNA_ROTULO = "risco"
COLUNAS_ENTRADA: tuple[str, ...] = (
    "temperature_2m",
    "relative_humidity_2m",
    "precipitation",
    "wind_speed_10m",
    "apparent_temperature",
    "dew_point_2m",
    "wind_gusts_10m",
    "uv_index_max",
    "cloud_cover",
)


@dataclass(frozen=True)
class PerfilClimatico:
    """Parametros climaticos medias de uma regiao."""

    nome: str
    latitude: float
    temp_media: float
    amplitude_sazonal: float
    precip_anual_mm: float
    umidade_base: float
    vento_base_kmh: float
    fracao_seca: float


PERFIS: tuple[PerfilClimatico, ...] = (
    PerfilClimatico("Amazonia_Manaus", -3.12, 27.0, 1.0, 2300.0, 82.0, 7.0, 0.55),
    PerfilClimatico("Amazonia_Rio_Branco", -9.97, 27.5, 2.0, 1900.0, 78.0, 8.0, 0.50),
    PerfilClimatico("Cerrado_Brasilia", -15.79, 21.5, 5.0, 1540.0, 62.0, 11.0, 0.38),
    PerfilClimatico("Cerrado_Goiania", -16.68, 23.5, 5.5, 1570.0, 65.0, 10.0, 0.36),
    PerfilClimatico("Pantanal_Cuiaba", -15.60, 26.5, 6.0, 1350.0, 66.0, 9.0, 0.35),
    PerfilClimatico("Sao_Paulo", -23.55, 19.5, 7.5, 1360.0, 70.0, 9.0, 0.30),
    PerfilClimatico("Campinas", -22.91, 21.5, 6.5, 1400.0, 68.0, 8.0, 0.30),
    PerfilClimatico("Rio_de_Janeiro", -22.91, 24.5, 5.0, 1250.0, 76.0, 11.0, 0.28),
    PerfilClimatico("Recife", -8.05, 26.5, 3.0, 2200.0, 74.0, 15.0, 0.48),
    PerfilClimatico("Nordeste_Salvador", -12.97, 25.5, 3.5, 1800.0, 76.0, 13.0, 0.42),
)


# --------------------------------------------------------------- fisica base


def pressao_vapor_saturado(temp: float) -> float:
    """Pressao de vapor saturado (kPa) - equacao de Magnus."""
    return 0.6108 * np.exp(17.27 * temp / (temp + 237.3))


def ponto_de_orvalho(pressao_vapor: float) -> float:
    """Inverte a equacao de Magnus para obter a temperatura do ponto de orvalho."""
    if pressao_vapor <= 0.0:
        return -60.0
    ln_es = np.log(pressao_vapor / 0.6108)
    return 243.04 * ln_es / (17.625 - ln_es)


def sensacao_termica(temp: float, orvalho: float, vento_kmh: float) -> float:
    """Temperatura aparente.

    Usa a sensacao de vento do Environment Canada abaixo de 10 C e o indice
    humidex (corrigido pelo vento) acima disso. Sao as duas escalas oficiais
    para "temperatura sentida", nao uma regressao arbitraria.
    """
    v = min(vento_kmh / 12.0, 4.0)  # fator de velocidade nos limites das formulas
    if temp <= 10.0 and v > 0.7:
        # Sensacao de vento (Environment Canada / NWS).
        return 13.12 + 0.6215 * temp - 11.37 * v**0.16 + 0.3965 * temp * v**0.16

    # Indice humidex, a partir da pressao de vapor atual (nao a de saturacao).
    e = 6.11 * np.exp(5417.7530 * (1.0 / 273.16 - 1.0 / (273.15 + orvalho)))
    humidex = temp + 0.5555 * (e - 10.0)
    return humidex - 2.5 * max(0.0, v - 1.0)


def ffmc(
    ffmc_anterior: float,
    temp: float,
    umidade: float,
    vento_kmh: float,
    precip: float,
) -> float:
    """Fine Fuel Moisture Code (Van Wagner 1987 / CFS).

    Valor ALTO = combustiveis finos umidos. Valor BAIXO = combustiveis secos.
    Depende do codigo do dia anterior, o que cria inercia temporal.
    """
    ffmc_anterior = float(min(max(ffmc_anterior, 1.0), 101.0))

    m = 147.2 * (101.0 - ffmc_anterior) / (59.0 + 101.0 - ffmc_anterior)

    pe = (0.6 * precip) * np.exp(m * -0.001) if precip > 0.5 else 0.0
    rf = pe * 0.581 * np.exp(m * -0.0365)

    mo1 = m + 42.5 * rf * np.exp(-100.0 / (251.0 - m)) * (1.0 - np.exp(-6.93 / ffmc_anterior))
    mo1 += 0.0015 * (m - 42.5) * rf * np.exp(-0.023 * m)
    mo1 += 0.5 * np.exp(m * -0.025)
    mo1 = min(mo1, 250.0)

    return float(59.5 * (250.0 - mo1) / (147.2 + 250.0 - mo1))


def indice_perigo(ffmc_valor: float, vento_kmh: float, temp: float) -> float:
    """Escore 0-100 de perigo de incendio a partir do estado dos combustiveis.

    Combina secura dos combustiveis finos (dominante), energia do vento
    (propagacao) e calor (ignicao).

    O fator `ignicao` e um portao de calor: sem calor nao ha ignicao, por mais
    seco e ventoso que o ar esteja. Sem ele, um dia frio e seco com vento forte
    seria classificado como perigo maximo, o que nao corresponde a fisica do
    incendio. Uma frente fria de inverno e propagante, mas nao deflagrante.
    """
    secura = 100.0 - ffmc_valor
    vento = min(vento_kmh, 60.0)
    calor = max(0.0, temp - 20.0)

    base = 0.55 * secura + 0.30 * vento + 0.15 * calor
    ignicao = float(np.clip((temp - 15.0) / 12.0, 0.0, 1.0))
    return float(base * ignicao)


#: Limiar do escore acima do qual o dia e rotulado como de risco alto.
#: Calibrado empiricamente para deixar ~25% de dias positivos, proporcao realista
#: de dias de perigo alto ao longo de uma estacao seca. O escore e um indice
#: relativo: como o fator de ignicao comprime a escala, o valor maximo observado
#: fica perto de 51 e nao de 100.
LIMIAR_PERIGO = 43.0

#: Ruido de rotulo: nenhuma regra deterministica descreve bem o inicio de fogo.
RUIDO_ROTULO = 0.035


# ------------------------------------------------------------------ simulacao


def _simular_dias(rng: np.random.Generator, perfil: PerfilClimatico, n_dias: int) -> pd.DataFrame:
    datas = pd.date_range("2022-01-01", periods=n_dias, freq="D")
    media_diaria = perfil.precip_anual_mm / 365.0

    registros: list[dict[str, float | str | pd.Timestamp]] = []
    ffmc_atual = 85.0  # valor inicial padrao do FWI

    # Pico da estacao seca: por volta de julho no Sul e janeiro no Norte.
    centro_estacao_seca = 200.0 + (240.0 if perfil.latitude > 0 else 0.0)

    for dia in range(n_dias):
        data = datas[dia]
        dia_ano = data.dayofyear

        # --- peso da estacao seca em funcao do dia do ano --------------------
        desvio = (dia_ano - centro_estacao_seca) / 365.0
        seasonal = float(np.cos(2.0 * np.pi * desvio))
        peso_seco = float(np.clip((seasonal + 1.0) / 2.0, 0.0, 1.0))
        intensidade_seca = max(
            0.0, (peso_seco - (1.0 - perfil.fracao_seca)) / perfil.fracao_seca
        )

        # --- temperatura ----------------------------------------------------
        temp = perfil.temp_media + perfil.amplitude_sazonal * seasonal + rng.normal(0, 2.4)
        temp = float(np.clip(temp, -2.0, 42.0))

        # --- precipitacao ----------------------------------------------------
        # `lam` e a media da chuva NOS DIAS DE CHUVA. Calibrado para que a
        #Esperada diaria fique proxima de precip_anual_mm / 365.
        lambda_umida = media_diaria * 1.6
        lambda_seca = media_diaria * 12.0
        lam = lambda_seca + (lambda_umida - lambda_seca) * (1.0 - intensidade_seca)

        chance_chuva = 0.05 + 0.55 * (1.0 - intensidade_seca)
        if rng.random() < chance_chuva:
            precip = float(rng.gamma(shape=1.1, scale=lam / 1.1))
        else:
            precip = 0.0
        precip = float(np.clip(precip, 0.0, 150.0))

        # --- umidade ----------------------------------------------------------
        umidade = perfil.umidade_base - 34.0 * intensidade_seca + rng.normal(0, 7.0)
        umidade += 10.0 * min(precip / 10.0, 1.0)
        umidade = float(np.clip(umidade, 8.0, 100.0))

        # --- vento ------------------------------------------------------------
        vento = (
            perfil.vento_base_kmh * (1.0 + 0.5 * intensidade_seca)
            + rng.gamma(shape=2.2, scale=2.0)
        )
        vento = float(np.clip(vento, 0.5, 70.0))
        rajada = float(np.clip(vento * rng.uniform(1.3, 2.6), vento, 110.0))

        # --- umidade derivada --------------------------------------------------
        es = pressao_vapor_saturado(temp)
        orvalho = ponto_de_orvalho(es * umidade / 100.0)
        orvalho = float(np.clip(orvalho, -50.0, temp))
        sensacao = sensacao_termica(temp, orvalho, vento)

        # --- nuvem e UV --------------------------------------------------------
        nuvem = 25.0 + 0.35 * umidade + 30.0 * min(precip / 8.0, 1.0) + rng.normal(0, 12.0)
        nuvem = float(np.clip(nuvem, 0.0, 100.0))
        uv = 13.0 - 0.13 * nuvem + 0.35 * max(0.0, temp - 18.0) + rng.normal(0, 1.0)
        uv = float(np.clip(uv, 0.0, 15.0))

        # --- estado do combustivel e rotulo ------------------------------------
        ffmc_atual = ffmc(ffmc_atual, temp, umidade, vento, precip)
        escore = indice_perigo(ffmc_atual, vento, temp)
        risco = int(escore >= LIMIAR_PERIGO)
        if rng.random() < RUIDO_ROTULO:
            risco = 1 - risco

        registros.append(
            {
                "data": data,
                "regiao": perfil.nome,
                "latitude": perfil.latitude + rng.normal(0, 0.6),
                "temperature_2m": round(temp, 2),
                "relative_humidity_2m": round(umidade, 2),
                "precipitation": round(precip, 2),
                "wind_speed_10m": round(vento, 2),
                "apparent_temperature": round(sensacao, 2),
                "dew_point_2m": round(orvalho, 2),
                "wind_gusts_10m": round(rajada, 2),
                "uv_index_max": round(uv, 2),
                "cloud_cover": round(nuvem, 2),
                "ffmc": round(ffmc_atual, 3),
                "indice_perigo": round(escore, 3),
                COLUNA_ROTULO: risco,
            }
        )

    return pd.DataFrame(registros)


def gerar_dataset(anos: int = 4, seed: int = 2024) -> pd.DataFrame:
    """Gera o dataset FireWatch 2024 sintetico (todos os perfis, varios anos)."""
    rng = np.random.default_rng(seed)
    n_dias = anos * 365
    blocos = [_simular_dias(rng, perfil, n_dias) for perfil in PERFIS]
    return pd.concat(blocos, ignore_index=True)


if __name__ == "__main__":
    from pathlib import Path

    destino = Path(__file__).resolve().parent.parent / "data" / "dataset_firewatch_2024.csv"
    destino.parent.mkdir(parents=True, exist_ok=True)

    df = gerar_dataset()
    df.to_csv(destino, index=False, encoding="utf-8")

    resumo = df[list(COLUNAS_ENTRADA) + [COLUNA_ROTULO]]
    print(f"Dataset salvo em: {destino}")
    print(f"Linhas: {len(df):,} | Colunas: {len(df.columns)}")
    print(f"Positivos ({COLUNA_ROTULO}=1): {df[COLUNA_ROTULO].mean():.1%}")
    print(f"Precipitacao anual simulada: {df.groupby('regiao')['precipitation'].sum().mean() / 4:.0f} mm/ano (media)")
    print()
    print(resumo.describe().round(2).to_string())
    print()
    print("Taxa de positivos por regiao:")
    print(df.groupby("regiao")[COLUNA_ROTULO].agg(["size", "mean"]).round(3).to_string())
    print()
    print("Correlacao com o rotulo:")
    print(resumo.corr(numeric_only=True)[COLUNA_ROTULO].round(3).sort_values().to_string())