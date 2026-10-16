"""Avaliacao detalhada do classificador de risco do FireWatch.

Uso:
    python ml/avaliacao.py
    python ml/avaliacao.py --cenarios

Analisa o ``ml/modelo.pkl`` salvo: metricas das 3 classes, matriz de confusao,
importancia das features, distribuicao das classes no teste, desempenho por
bioma e cenarios climaticos.
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
from sklearn.metrics import classification_report, confusion_matrix  # noqa: E402

from ml.alvo import CLASSES  # noqa: E402
from ml.dados import carregar_dataframe  # noqa: E402
from ml.features import FEATURES, construir_features  # noqa: E402

CAMINHO_MODELO = RAIZ / "ml" / "modelo.pkl"

CENARIOS: list[dict] = [
    {"nome": "Chuva forte", "temp_max": 24.0, "temp_min": 19.0, "umidade": 92.0,
     "precipitacao_mm": 25.0, "velocidade_vento": 9.0, "dias_sem_chuva": 0.0},
    {"nome": "Dia ameno e umido", "temp_max": 27.0, "temp_min": 20.0, "umidade": 78.0,
     "precipitacao_mm": 4.0, "velocidade_vento": 11.0, "dias_sem_chuva": 2.0},
    {"nome": "Seco e ventoso", "temp_max": 34.0, "temp_min": 22.0, "umidade": 30.0,
     "precipitacao_mm": 0.0, "velocidade_vento": 35.0, "dias_sem_chuva": 25.0},
    {"nome": "Calor extremo seco", "temp_max": 40.0, "temp_min": 24.0, "umidade": 15.0,
     "precipitacao_mm": 0.0, "velocidade_vento": 22.0, "dias_sem_chuva": 45.0},
    {"nome": "Frio de inverno", "temp_max": 18.0, "temp_min": 9.0, "umidade": 85.0,
     "precipitacao_mm": 2.0, "velocidade_vento": 20.0, "dias_sem_chuva": 1.0},
    {"nome": "Frio, vento e seco", "temp_max": 16.0, "temp_min": 7.0, "umidade": 30.0,
     "precipitacao_mm": 0.0, "velocidade_vento": 45.0, "dias_sem_chuva": 20.0},
]


def cabecalho(titulo: str) -> None:
    print("\n" + "=" * 70)
    print(titulo)
    print("=" * 70)


def main(com_cenarios: bool = False) -> None:
    if not CAMINHO_MODELO.exists():
        raise SystemExit(f"Modelo nao encontrado: {CAMINHO_MODELO}. Rode ml/treinamento.py.")

    bundle = joblib.load(CAMINHO_MODELO)
    modelo = bundle["modelo"]
    df = carregar_dataframe().sort_values("data").reset_index(drop=True)
    x = df[list(FEATURES)].astype(float)
    y = df["classe"].astype(int)

    cabecalho("INFORMACOES DO MODELO")
    print(f"  Algoritmo     : {bundle['algoritmo']}")
    print(f"  Alvo          : {bundle.get('alvo', 'classe_risco')}")
    print(f"  Dataset       : {bundle['dataset']}")
    print(f"  Treinado em   : {bundle['treinado_em']}")
    print(f"  sklearn       : {bundle['versao_sklearn']}")
    print(f"  Linhas treino : {bundle['linhas_treino']:,}")
    print(f"  Features ({len(FEATURES)}): {', '.join(FEATURES)}")
    print(f"  Classes       : {' | '.join(CLASSES)}")

    corte = int(len(x) * 0.8)
    x_teste, y_teste = x.iloc[corte:], y.iloc[corte:]
    y_pred = modelo.predict(x_teste)

    cabecalho("DESEMPENHO NO CONJUNTO DE TESTE (holdout temporal)")
    relatorio = classification_report(
        y_teste, y_pred, labels=list(range(len(CLASSES))),
        target_names=list(CLASSES), digits=3, zero_division=0,
    )
    print(relatorio)

    cabecalho("MATRIZ DE CONFUSAO (linha=real, coluna=previsto)")
    matriz = confusion_matrix(y_teste, y_pred, labels=list(range(len(CLASSES))))
    cab = "".join(f"{c.split()[1][:7]:>11}" for c in CLASSES)
    print(f"  {'':<17}{cab}")
    for i, linha in enumerate(matriz):
        valores = "".join(f"{v:>11,}" for v in linha)
        print(f"  {CLASSES[i]:<17}{valores}")

    cabecalho("IMPORTANCIA DAS FEATURES")
    imp = bundle["importancias"]
    for nome, valor in sorted(imp.items(), key=lambda kv: -kv[1]):
        print(f"  {nome:<18} {valor:.4f}  {'#' * round(valor * 120)}")

    cabecalho("DISTRIBUICAO DAS CLASSES (no teste)")
    for codigo, classe in enumerate(CLASSES):
        real = int((y_teste == codigo).sum())
        prev = int((np.asarray(y_pred) == codigo).sum())
        print(f"  {classe:<16} real={real:>7,} ({real/len(y_teste):>5.1%})"
              f"   previsto={prev:>7,} ({prev/len(y_teste):>5.1%})")

    if "bioma" in df.columns:
        cabecalho("RISCO MEDIO POR BIOMA (probabilidade de Critico)")
        proba = modelo.predict_proba(x)
        tabela = (
            pd.DataFrame({"bioma": df["bioma"], "p_critico": proba[:, 2]})
            .groupby("bioma")["p_critico"]
            .agg(["size", "mean"])
            .sort_values("mean", ascending=False)
            .round(3)
        )
        print(tabela.to_string())

    if com_cenarios:
        cabecalho("CENARIOS CLIMATICOS")
        print(f"  {'Cenario':<24}{'seca':>6}{'umid.':>7}{'P(crit)':>9}{'classe':>16}")
        for cenario in CENARIOS:
            features = construir_features(cenario)
            vetor = pd.DataFrame([[features[n] for n in FEATURES]], columns=list(FEATURES))
            proba = modelo.predict_proba(vetor)[0]
            classe = CLASSES[int(np.argmax(proba))]
            print(
                f"  {cenario['nome']:<24}{cenario['dias_sem_chuva']:>6.0f}"
                f"{cenario['umidade']:>7.0f}{proba[2] * 100:>8.1f}%{classe:>16}"
            )

    print()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Avalia o classificador do FireWatch.")
    parser.add_argument("--cenarios", action="store_true", help="Adiciona cenarios climaticos.")
    args = parser.parse_args()
    main(com_cenarios=args.cenarios)
