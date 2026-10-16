"""Treinamento do classificador de risco de incendio do FireWatch.

Uso:
    python ml/treinamento.py              # le o banco e salva ml/modelo.pkl
    python ml/treinamento.py --reavaliar  # reavalia o modelo.pkl sem retreinar
    python ml/treinamento.py --buscar     # busca de hiperparametros (mais lento)

Fluxo:
    banco (firewatch_dados) -> indice de risco 0-100 (percentil do risco_fogo)
        -> 3 classes (Risco Baixo / Moderado / Critico) -> RandomForestClassifier
        -> modelo.pkl

A definicao das classes e dos cortes do indice 0-100 esta em :mod:`ml.alvo`.
"""

from __future__ import annotations

import argparse
import contextlib
import json
import sys
from datetime import UTC, datetime
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
if str(RAIZ) not in sys.path:
    sys.path.insert(0, str(RAIZ))

import joblib  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
from sklearn.ensemble import RandomForestClassifier  # noqa: E402
from sklearn.metrics import (  # noqa: E402
    accuracy_score,
    balanced_accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
    roc_auc_score,
)
from sklearn.model_selection import GridSearchCV, KFold, cross_val_score  # noqa: E402

from ml.alvo import CLASSES, CORTES_INDICE, N_CLASSES, NIVEIS  # noqa: E402
from ml.dados import carregar_dataframe  # noqa: E402
from ml.features import FEATURES  # noqa: E402

CAMINHO_MODELO = RAIZ / "ml" / "modelo.pkl"
NOME_DATASET = "FireWatch (banco firewatch_dados)"


# ------------------------------------------------------------------- dados


def carregar_dataset() -> pd.DataFrame:
    """Le o dataset de treino diretamente do banco PostgreSQL."""
    df = carregar_dataframe()
    print(f"Dataset: {NOME_DATASET}")
    print(
        f"  linhas={len(df):,}  features={len(FEATURES)}  "
        f"periodo={df['data'].min()}..{df['data'].max()}"
    )
    return df


def separar_xy(df: pd.DataFrame) -> tuple[pd.DataFrame, pd.Series]:
    """Separa a matriz de features e o alvo (codigo da classe)."""
    x = df[list(FEATURES)].astype(float).reset_index(drop=True)
    y = df["classe"].astype(int).reset_index(drop=True)
    if not np.isfinite(x.to_numpy()).all():
        raise SystemExit("Features com valores nao finitos.")
    return x, y


# --------------------------------------------------------------- modelagem


def construir_modelo() -> RandomForestClassifier:
    return RandomForestClassifier(
        n_estimators=300,
        max_depth=24,
        min_samples_leaf=25,
        max_features=0.6,
        n_jobs=-1,
        random_state=42,
        class_weight=None,
    )


def buscar_hiperparametros(
    x: pd.DataFrame, y: pd.Series
) -> tuple[RandomForestClassifier, dict]:
    """Busca em grade leve, com validacao cruzada, otimizando o F1 macro."""
    grade = {
        "n_estimators": [300, 500],
        "min_samples_leaf": [10, 25, 50],
        "max_features": [0.5, 0.8],
    }
    cv = KFold(n_splits=4, shuffle=True, random_state=42)
    busca = GridSearchCV(
        estimator=construir_modelo(),
        param_grid=grade,
        scoring="f1_macro",
        cv=cv,
        n_jobs=-1,
        refit=True,
    )
    busca.fit(x, y)
    return busca.best_estimator_, busca.best_params_


def avaliar(y_real: pd.Series, y_pred: np.ndarray, y_proba: np.ndarray) -> dict:
    """Metricas de classificacao das 3 classes."""
    y_real_arr = np.asarray(y_real)
    relatorio = classification_report(
        y_real_arr, y_pred, labels=list(range(N_CLASSES)),
        target_names=list(CLASSES), output_dict=True, zero_division=0,
    )
    matriz = confusion_matrix(y_real_arr, y_pred, labels=list(range(N_CLASSES)))
    metricas: dict = {
        "accuracy": round(float(accuracy_score(y_real_arr, y_pred)), 4),
        "balanced_accuracy": round(float(balanced_accuracy_score(y_real_arr, y_pred)), 4),
        "f1_macro": round(float(f1_score(y_real_arr, y_pred, average="macro")), 4),
        "f1_weighted": round(float(f1_score(y_real_arr, y_pred, average="weighted")), 4),
        "matriz_confusao": matriz.tolist(),
        "por_classe": {
            classe: {
                "precisao": round(float(relatorio[classe]["precision"]), 4),
                "sensibilidade": round(float(relatorio[classe]["recall"]), 4),
                "f1": round(float(relatorio[classe]["f1-score"]), 4),
                "suporte": int(relatorio[classe]["support"]),
            }
            for classe in CLASSES
        },
    }
    # ROC-AUC e apenas informativa: nao deve derrubar o treinamento.
    with contextlib.suppress(Exception):
        metricas["roc_auc_ovr"] = round(
            float(roc_auc_score(y_real_arr, y_proba, average="macro", multi_class="ovr")),
            4,
        )
    return metricas


def imprimir_relatorio(metricas: dict) -> None:
    print("\n" + "=" * 66)
    print("METRICAS NO CONJUNTO DE TESTE (holdout temporal 20%)")
    print("=" * 66)
    for chave in ("accuracy", "balanced_accuracy", "f1_macro", "f1_weighted", "roc_auc_ovr"):
        if chave in metricas:
            print(f"  {chave:<18} {metricas[chave]:.4f}")

    print("\n  Por classe:")
    print(f"    {'classe':<16}{'precisao':>10}{'sensib.':>10}{'f1':>10}{'suporte':>10}")
    for classe, m in metricas.get("por_classe", {}).items():
        print(
            f"    {classe:<16}{m['precisao']:>10.3f}{m['sensibilidade']:>10.3f}"
            f"{m['f1']:>10.3f}{m['suporte']:>10}"
        )

    matriz = metricas.get("matriz_confusao")
    if matriz:
        print("\n  Matriz de confusao (linha=real, coluna=previsto):")
        cab = "".join(f"{c.split()[1][:6]:>10}" for c in CLASSES)
        print(f"    {'':<16}{cab}")
        for i, linha in enumerate(matriz):
            valores = "".join(f"{v:>10,}" for v in linha)
            print(f"    {CLASSES[i]:<16}{valores}")


# ------------------------------------------------------------- persistencia


def salvar_modelo(
    modelo: RandomForestClassifier,
    x: pd.DataFrame,
    extra: dict,
) -> Path:
    importancias = dict(zip(FEATURES, modelo.feature_importances_.round(5), strict=True))

    bundle = {
        "modelo": modelo,
        "algoritmo": "RandomForestClassifier",
        "alvo": "classe_risco",
        "features": list(FEATURES),
        "classes": list(CLASSES),
        "niveis": list(NIVEIS),
        "cortes_indice": list(CORTES_INDICE),
        "importancias": importancias,
        "dataset": NOME_DATASET,
        "linhas_treino": len(x),
        "treinado_em": datetime.now(UTC).isoformat(),
        "versao_sklearn": __import__("sklearn").__version__,
        **extra,
    }

    CAMINHO_MODELO.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump(bundle, CAMINHO_MODELO, compress=3)

    tamanho_kb = CAMINHO_MODELO.stat().st_size / 1024
    print(f"\nModelo salvo em: {CAMINHO_MODELO}  ({tamanho_kb:.0f} KB)")
    print("\nImportancia das features:")
    for nome, valor in sorted(importancias.items(), key=lambda kv: -kv[1]):
        barra = "#" * round(valor * 100)
        print(f"  {nome:<18} {valor:.4f}  {barra}")
    return CAMINHO_MODELO


# -------------------------------------------------------------------- main


def treinar(buscar: bool = False) -> Path:
    print("=" * 66)
    print("FireWatch - treinamento do classificador de risco de incendio")
    print("=" * 66)

    df = carregar_dataset()
    x, y = separar_xy(df)
    print("\nDistribuicao das classes:")
    for codigo, classe in enumerate(CLASSES):
        n = int((y == codigo).sum())
        print(f"  {classe:<16} {n:>7,}  ({n / len(y):>5.1%})")

    # Holdout temporal: treina no passado, testa no futuro (mais honesto).
    df_ordenado = df.sort_values("data").reset_index(drop=True)
    x = df_ordenado[list(FEATURES)].astype(float)
    y = df_ordenado["classe"].astype(int)
    corte = int(len(x) * 0.8)
    x_treino, x_teste = x.iloc[:corte], x.iloc[corte:]
    y_treino, y_teste = y.iloc[:corte], y.iloc[corte:]
    print(f"\nTreino: {len(x_treino):,} | Teste: {len(x_teste):,} (temporal)")

    if buscar:
        print("\nBuscando hiperparametros (GridSearchCV, 4-fold, F1 macro)...")
        modelo, melhores = buscar_hiperparametros(x_treino, y_treino)
        print(f"  melhores parametros: {json.dumps(melhores, default=str)}")
    else:
        modelo = construir_modelo()
        modelo.fit(x_treino, y_treino)
        melhores = modelo.get_params()

    y_pred = modelo.predict(x_teste)
    y_proba = modelo.predict_proba(x_teste)
    metricas = avaliar(y_teste, y_pred, y_proba)

    scores_cv = cross_val_score(
        modelo, x_treino, y_treino,
        cv=KFold(n_splits=4, shuffle=True, random_state=42),
        scoring="f1_macro", n_jobs=-1,
    )
    metricas["cv_f1_macro_mean"] = round(float(scores_cv.mean()), 4)
    metricas["cv_f1_macro_std"] = round(float(scores_cv.std()), 4)

    imprimir_relatorio(metricas)

    extra = {"metricas": metricas, "hiperparametros": melhores}
    return salvar_modelo(modelo, x_treino, extra)


def reavaliar() -> None:
    """Reaplica as metricas sobre o modelo.pkl ja salvo."""
    if not CAMINHO_MODELO.exists():
        raise SystemExit(f"Modelo nao encontrado: {CAMINHO_MODELO}. Rode o treinamento.")

    bundle = joblib.load(CAMINHO_MODELO)
    df = carregar_dataset().sort_values("data").reset_index(drop=True)
    x = df[list(FEATURES)].astype(float)
    y = df["classe"].astype(int)
    corte = int(len(x) * 0.8)
    x_teste, y_teste = x.iloc[corte:], y.iloc[corte:]

    modelo = bundle["modelo"]
    y_pred = modelo.predict(x_teste)
    y_proba = modelo.predict_proba(x_teste)

    print(f"Algoritmo : {bundle['algoritmo']}")
    print(f"Treinado  : {bundle['treinado_em']}")
    print(f"Dataset   : {bundle['dataset']} ({bundle['linhas_treino']:,} linhas de treino)")
    imprimir_relatorio(avaliar(y_teste, y_pred, y_proba))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Treina o classificador do FireWatch.")
    parser.add_argument("--buscar", action="store_true", help="Busca de hiperparametros.")
    parser.add_argument("--reavaliar", action="store_true", help="Reavalia o modelo salvo.")
    args = parser.parse_args()

    if args.reavaliar:
        reavaliar()
    else:
        treinar(buscar=args.buscar)
