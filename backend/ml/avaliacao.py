"""Avaliacao detalhada do modelo de risco do FireWatch.

Uso:
    python ml/avaliacao.py
    python ml/avaliacao.py --cenarios

Analisa o `ml/modelo.pkl` salvo: metricas, matriz de confusao, curva ROC,
varredura de limiar, desempenho por regiao e desempenho em cenarios climaticos
realisticos comparados a heuristica classica do indice de aridez.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
if str(RAIZ) not in sys.path:
    sys.path.insert(0, str(RAIZ))

import joblib  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
from sklearn.metrics import (  # noqa: E402
    accuracy_score,
    average_precision_score,
    brier_score_loss,
    classification_report,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
    roc_curve,
)
from sklearn.model_selection import train_test_split  # noqa: E402

from ml.dataset import COLUNA_ROTULO, COLUNAS_ENTRADA, gerar_dataset  # noqa: E402
from ml.features import FEATURES, construir_features  # noqa: E402

CAMINHO_MODELO = RAIZ / "ml" / "modelo.pkl"
CAMINHO_DADOS = RAIZ / "data" / "dataset_firewatch_2024.csv"

CENARIOS: list[dict] = [
    {
        "nome": "Chuva forte",
        "temperature_2m": 22.0,
        "relative_humidity_2m": 92.0,
        "precipitation": 22.0,
        "wind_speed_10m": 9.0,
        "apparent_temperature": 24.0,
        "dew_point_2m": 20.5,
        "wind_gusts_10m": 16.0,
        "uv_index_max": 2.0,
        "cloud_cover": 95.0,
    },
    {
        "nome": "Dia ameno e umido",
        "temperature_2m": 24.0,
        "relative_humidity_2m": 78.0,
        "precipitation": 0.0,
        "wind_speed_10m": 11.0,
        "apparent_temperature": 27.0,
        "dew_point_2m": 20.0,
        "wind_gusts_10m": 18.0,
        "uv_index_max": 6.0,
        "cloud_cover": 60.0,
    },
    {
        "nome": "Seco e ventoso",
        "temperature_2m": 33.0,
        "relative_humidity_2m": 28.0,
        "precipitation": 0.0,
        "wind_speed_10m": 38.0,
        "apparent_temperature": 32.0,
        "dew_point_2m": 9.0,
        "wind_gusts_10m": 62.0,
        "uv_index_max": 11.0,
        "cloud_cover": 5.0,
    },
    {
        "nome": "Calor extremo seco",
        "temperature_2m": 40.0,
        "relative_humidity_2m": 15.0,
        "precipitation": 0.0,
        "wind_speed_10m": 22.0,
        "apparent_temperature": 40.0,
        "dew_point_2m": 4.0,
        "wind_gusts_10m": 45.0,
        "uv_index_max": 13.0,
        "cloud_cover": 0.0,
    },
    {
        "nome": "Frio de inverno",
        "temperature_2m": 11.0,
        "relative_humidity_2m": 85.0,
        "precipitation": 0.0,
        "wind_speed_10m": 20.0,
        "apparent_temperature": 8.0,
        "dew_point_2m": 8.5,
        "wind_gusts_10m": 32.0,
        "uv_index_max": 3.0,
        "cloud_cover": 50.0,
    },
    {
        "nome": "Frio com vento e umidade baixa",
        "temperature_2m": 16.0,
        "relative_humidity_2m": 30.0,
        "precipitation": 0.0,
        "wind_speed_10m": 45.0,
        "apparent_temperature": 10.0,
        "dew_point_2m": -2.0,
        "wind_gusts_10m": 70.0,
        "uv_index_max": 5.0,
        "cloud_cover": 10.0,
    },
]


def cabecalho(titulo: str) -> None:
    print("\n" + "=" * 70)
    print(titulo)
    print("=" * 70)


def carregar() -> tuple[dict, pd.DataFrame, pd.DataFrame, pd.Series]:
    if not CAMINHO_MODELO.exists():
        raise SystemExit(f"Modelo nao encontrado: {CAMINHO_MODELO}. Rode ml/treinamento.py.")

    bundle = joblib.load(CAMINHO_MODELO)
    df = pd.read_csv(CAMINHO_DADOS) if CAMINHO_DADOS.exists() else gerar_dataset()

    registros = df[list(COLUNAS_ENTRADA)].to_dict("records")
    x = pd.DataFrame([construir_features(r) for r in registros], columns=list(FEATURES))
    y = df[COLUNA_ROTULO].astype(int)

    return bundle, df, x, y



def prever_cenario(modelo, cenario: dict) -> tuple[float, dict[str, float]]:
    """Probabilidade de risco e features derivadas de um clima hipotetico."""
    features = construir_features(cenario)
    # DataFrame para manter os nomes de coluna esperados pelo pipeline ajustado.
    vetor = pd.DataFrame([features], columns=list(FEATURES))
    return float(modelo.predict_proba(vetor)[0][1]), features


def main(com_cenarios: bool = False) -> None:
    bundle, df, x, y = carregar()
    modelo = bundle["modelo"]

    cabecalho("INFORMACOES DO MODELO")
    print(f"  Algoritmo     : {bundle['algoritmo']}")
    print(f"  Dataset       : {bundle['dataset']}")
    print(f"  Treinado em   : {bundle['treinado_em']}")
    print(f"  sklearn       : {bundle['versao_sklearn']}")
    print(f"  Linhas treino : {bundle['linhas_treino']:,}")
    print(f"  Features ({len(FEATURES)}): {', '.join(FEATURES)}")
    print(f"  Hyperparams   : {bundle['hiperparametros']}")

    cabecalho("METRICAS GLOBAIS (conjunto de teste)")
    _, x_teste, _, y_teste = train_test_split(
        x, y, test_size=0.2, random_state=42, stratify=y
    )
    y_pred = modelo.predict(x_teste)
    y_prob = modelo.predict_proba(x_teste)[:, 1]

    acc = accuracy_score(y_teste, y_pred)
    print(f"  Acuracia            : {acc:.4f}")
    print(f"  Precisao (risco)    : {precision_score(y_teste, y_pred):.4f}")
    print(f"  Sensibilidade       : {recall_score(y_teste, y_pred):.4f}")
    print(f"  F1                  : {f1_score(y_teste, y_pred):.4f}")
    print(f"  ROC-AUC             : {roc_auc_score(y_teste, y_prob):.4f}")
    print(f"  Average Precision   : {average_precision_score(y_teste, y_prob):.4f}")
    print(f"  Brier score (calib.): {brier_score_loss(y_teste, y_prob):.4f}  (menor = melhor)")

    print("\n" + classification_report(y_teste, y_pred, target_names=["sem risco", "risco"], digits=3))

    cm = confusion_matrix(y_teste, y_pred)
    tn, fp, fn, tp = cm.ravel()
    print("Matriz de confusao")
    print(f"  verdadeiro negativo (sem risco, previsto sem risco): {tn}")
    print(f"  falso positivo      (sem risco, previsto risco)   : {fp}")
    print(f"  falso negativo      (risco, previsto sem risco)   : {fn}")
    print(f"  verdadeiro positivo (risco, previsto risco)       : {tp}")
    print(f"\n  Sensibilidade = {tp / (tp + fn):.4f}  (risco real que o modelo detectou)")
    print(f"  Especificidade = {tn / (tn + fp):.4f}  (alarme falso evitado)")

    cabecalho("CURVA ROC")
    fpr, tpr, _ = roc_curve(y_teste, y_prob)
    print(f"  AUC = {np.trapezoid(tpr, fpr):.4f}   (0.5 = aleatorio, 1.0 = perfeito)")
    print(f"  Inicio {fpr[0]:.2f}/{tpr[0]:.2f} -> fim {fpr[-1]:.2f}/{tpr[-1]:.2f}")

    cabecalho("QUALIDADE DAS PROBABILIDADES")
    faixas = [(0.0, 0.25), (0.25, 0.50), (0.50, 0.75), (0.75, 1.01)]
    print(f"  {'Faixa de prob.':<16}{'N':>7}{'% amostras':>12}{'% risco real':>14}{'medio':>10}")
    for lo, hi in faixas:
        m = (y_prob >= lo) & (y_prob < hi)
        if m.sum() == 0:
            continue
        print(
            f"  {f'{lo:.2f} - {min(hi,1.0):.2f}':<16}{m.sum():>7,}{m.mean()*100:>11.1f}%"
            f"{y_teste[m].mean()*100:>13.1f}%{y_prob[m].mean():>10.3f}"
        )
    print("\n  Uma faixa em que '% risco real' acompanha '% amostras' indica")
    print("  que as probabilidades sao bem calibradas.")

    cabecalho("VARREDURA DO LIMIAR DE DECISAO (risco = prob > limiar)")
    print(f"  {'Limiar':>8}{'Acuracia':>11}{'Precisao':>11}{'Sensib.':>10}{'F1':>9}")
    for limiar in (0.30, 0.40, 0.45, 0.50, 0.55, 0.60, 0.70):
        pd_ = (y_prob >= limiar).astype(int)
        print(
            f"  {limiar:>8.2f}{accuracy_score(y_teste, pd_):>11.4f}"
            f"{precision_score(y_teste, pd_, zero_division=0):>11.4f}"
            f"{recall_score(y_teste, pd_, zero_division=0):>10.4f}"
            f"{f1_score(y_teste, pd_, zero_division=0):>9.4f}"
        )
    melhor_limiar = max(
        ((L, f1_score(y_teste, (y_prob >= L).astype(int), zero_division=0))
         for L in (0.30, 0.40, 0.45, 0.50, 0.55, 0.60, 0.70)),
        key=lambda par: par[1],
    )
    print(f"\n  Melhor F1 da varredura: {melhor_limiar[0]:.2f} (F1 = {melhor_limiar[1]:.4f}).")
    print("  O projeto mantem 0.50, o corte natural do classificador: ele da")
    print("  preferencia a sensibilidade, que num sistema de alerta preventivo")
    print("  importa mais do que evitar alguns alarmes falsos. Em uso operacional,")
    print("  um limiar acima de 0.55 evita avisos cansativos se o custo do alarme")
    print("  for alto.")

    cabecalho("IMPORTANCIA DAS FEATURES")
    imp = bundle["importancias"]
    for nome, valor in sorted(imp.items(), key=lambda kv: -kv[1]):
        print(f"  {nome:<22} {valor:.4f}  {'#' * int(round(valor * 120))}")

    if "regiao" in df.columns:
        cabecalho("DESEMPENHO POR REGIAO")
        y_prob_all = modelo.predict_proba(x)[:, 1]
        y_pred_all = (y_prob_all >= 0.5).astype(int)
        tabela = (
            pd.DataFrame({"regiao": df["regiao"], "real": y, "pred": y_pred_all})
            .groupby("regiao")
            .apply(
                lambda g: pd.Series(
                    {
                        "n": len(g),
                        "positivos": round(g["real"].mean(), 3),
                        "acuracia": round((g["real"] == g["pred"]).mean(), 3),
                    }
                ),
                include_groups=False,
            )
            .sort_values("positivos")
        )
        print(tabela.to_string())

    cabecalho("CATEGORIAS DE RISCO (distribuicao das saidas)")
    from app.models.schemas import RiskLevel

    rotulos = [RiskLevel.from_probability(float(p)).label for p in y_prob]
    contagem = pd.Series(rotulos).value_counts()
    for nivel in RiskLevel:
        n = int(contagem.get(nivel.label, 0))
        barra = "#" * int(round(100.0 * n / len(y_prob)))
        print(f"  {nivel.label:<10} {n:>6,}  ({n / len(y_prob):>5.1%})  {barra}")
    print("\n  Recordando os limiares de classificacao da API:")
    for chave, valor in bundle["limiares"].items():
        print(f"    {chave:<10} probabilidade >= {valor}")

    if com_cenarios:
        cabecalho("CENARIOS CLIMATICOS SIMULADOS")
        print(f"  {'Cenario':<34}{'Temp':>7}{'RH%':>6}{'Vento':>8}{'Prob.':>8}{'Nivel':>12}")
        for cenario in CENARIOS:
            prob, _ = prever_cenario(modelo, cenario)
            print(
                f"  {cenario['nome']:<34}{cenario['temperature_2m']:>7.1f}"
                f"{cenario['relative_humidity_2m']:>6.0f}{cenario['wind_speed_10m']:>8.0f}"
                f"{prob * 100:>7.1f}%{RiskLevel.from_probability(prob).label:>12}"
            )

        print("\n  Comparacao com a heuristica classica de aridez (VPD e vento):")
        print(f"  {'Cenario':<34}{'VPD (kPa)':>11}{'Modelo':>10}{'Heuristica':>13}")
        for cenario in CENARIOS:
            prob, features = prever_cenario(modelo, cenario)
            heuristica = 1.0 / (1.0 + np.exp(-(features["aridity_index"] - 55.0) / 12.0))
            print(
                f"  {cenario['nome']:<34}{features['vpd_kpa']:>11.2f}"
                f"{prob * 100:>9.1f}%{heuristica * 100:>12.1f}%"
            )
        print("\n  A heuristica nao considera calor: por isso ela superestima o risco")
        print("  em dias frios e ventosos,situcao em que nao ha calor para deflagrar")
        print("  um incendio. O modelo, treinado com o indice de perigo completo,")
        print("  distingue esses dois casos.")

    print()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Avalia o modelo do FireWatch.")
    parser.add_argument(
        "--cenarios",
        action="store_true",
        help="Adiciona cenarios climaticos simulados ao relatorio.",
    )
    args = parser.parse_args()
    main(com_cenarios=args.cenarios)
