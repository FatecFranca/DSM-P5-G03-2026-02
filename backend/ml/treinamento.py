"""Treinamento do modelo de risco de incendio do FireWatch.

Uso:
    python ml/treinamento.py              # usa/gera o dataset e salva ml/modelo.pkl
    python ml/treinamento.py --reavaliar  # reavalia modelo.pkl sem retreinar
    python ml/treinamento.py --forcar-dataset  # regenera o CSV sintetico

Fluxo:
    dataset -> features (ml/features.py) -> holdout estratificado
            -> busca em grade (RandomForest) -> metricas -> modelo.pkl
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
if str(RAIZ) not in sys.path:
    sys.path.insert(0, str(RAIZ))

import joblib  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
from sklearn.ensemble import RandomForestClassifier  # noqa: E402
from sklearn.impute import SimpleImputer  # noqa: E402
from sklearn.metrics import (  # noqa: E402
    accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
)
from sklearn.model_selection import GridSearchCV, StratifiedKFold, cross_val_score, train_test_split  # noqa: E402
from sklearn.pipeline import Pipeline  # noqa: E402

from ml.dataset import COLUNA_ROTULO, COLUNAS_ENTRADA, gerar_dataset  # noqa: E402
from ml.features import FEATURES, construir_features  # noqa: E402

CAMINHO_DADOS = RAIZ / "data" / "dataset_firewatch_2024.csv"
CAMINHO_MODELO = RAIZ / "ml" / "modelo.pkl"
NOME_DATASET = "FireWatch 2024"

#: Limiares de classificacao do risco, por porcentagem de probabilidade.
LIMITARES = {
    "moderado": 0.25,
    "alto": 0.50,
    "critico": 0.75,
}


# ------------------------------------------------------------------ dados


def carregar_dataset(forcar: bool = False) -> pd.DataFrame:
    """Le o CSV do projeto; se nao existir, gera o sintetico."""
    if forcar and CAMINHO_DADOS.exists():
        CAMINHO_DADOS.unlink()

    if CAMINHO_DADOS.exists():
        df = pd.read_csv(CAMINHO_DADOS)
        origem = f"CSV do projeto ({CAMINHO_DADOS.name})"
    else:
        df = gerar_dataset()
        CAMINHO_DADOS.parent.mkdir(parents=True, exist_ok=True)
        df.to_csv(CAMINHO_DADOS, index=False, encoding="utf-8")
        origem = f"gerado por ml/dataset.py -> {CAMINHO_DADOS.name}"

    faltando = [c for c in (*COLUNAS_ENTRADA, COLUNA_ROTULO) if c not in df.columns]
    if faltando:
        raise SystemExit(
            f"O dataset esta com colunas obrigatorias ausentes: {faltando}\n"
            f"Esperado: {list(COLUNAS_ENTRADA)} + rotulo '{COLUNA_ROTULO}'."
        )

    print(f"Dataset: {origem}")
    print(f"  linhas={len(df):,}  features={len(COLUNAS_ENTRADA)}  "
          f"positivos={df[COLUNA_ROTULO].mean():.1%}")

    return df


def montar_xy(df: pd.DataFrame) -> tuple[pd.DataFrame, pd.Series]:
    """Aplica a engenharia de features e separa X/y."""
    registros = df[list(COLUNAS_ENTRADA)].to_dict("records")
    matriz = pd.DataFrame([construir_features(r) for r in registros], columns=list(FEATURES))

    if not np.isfinite(matriz.to_numpy(dtype=float)).all():
        raise SystemExit("Features com valores nao finitos apos a engenharia.")

    return matriz, df[COLUNA_ROTULO].astype(int)


# -------------------------------------------------------------- modelagem


def construir_pipeline() -> Pipeline:
    """Imputacao de mediana + Random Forest.

    O imputer cobre campos opcionais que a Open-Meteo pode nao devolver na
    inferencia (UV, nuvem, sensacao termica).
    """
    return Pipeline(
        [
            ("imputer", SimpleImputer(strategy="median")),
            (
                "rf",
                RandomForestClassifier(
                    n_estimators=300,
                    max_depth=None,
                    min_samples_leaf=2,
                    class_weight="balanced_subsample",
                    n_jobs=-1,
                    random_state=42,
                ),
            ),
        ]
    )


def buscar_hiperparametros(x: pd.DataFrame, y: pd.Series) -> tuple[Pipeline, dict]:
    """Busca em grade com validacao cruzada estratificada."""
    grade = {
        "rf__n_estimators": [300, 600],
        "rf__max_depth": [None, 12, 20],
        "rf__min_samples_leaf": [1, 2, 4],
        "rf__max_features": ["sqrt", 0.6],
    }
    cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)

    busca = GridSearchCV(
        estimator=construir_pipeline(),
        param_grid=grade,
        scoring="roc_auc",
        cv=cv,
        n_jobs=-1,
        refit=True,
        verbose=0,
    )
    busca.fit(x, y)
    return busca.best_estimator_, busca.best_params_


def avaliar(y_real: pd.Series, y_pred: np.ndarray, y_prob: np.ndarray) -> dict:
    """Calcula as metricas do classificador binario de risco."""
    metricas = {
        "accuracy": round(float(accuracy_score(y_real, y_pred)), 4),
        "precision": round(float(precision_score(y_real, y_pred, zero_division=0)), 4),
        "recall": round(float(recall_score(y_real, y_pred, zero_division=0)), 4),
        "f1": round(float(f1_score(y_real, y_pred, zero_division=0)), 4),
        "roc_auc": round(float(roc_auc_score(y_real, y_prob)), 4),
    }
    return metricas


def imprimir_relatorio(y_real: pd.Series, y_pred: np.ndarray, metricas: dict) -> None:
    print("\n" + "=" * 66)
    print("METRICAS NO CONJUNTO DE TESTE (holdout 20%)")
    print("=" * 66)
    for chave in ("accuracy", "precision", "recall", "f1", "roc_auc"):
        print(f"  {chave:<12} {metricas[chave]:.4f}")

    cm = confusion_matrix(y_real, y_pred)
    print("\nMatriz de confusao (linhas = real, colunas = previsto):")
    print(f"               previsto 0   previsto 1")
    print(f"  real 0        {cm[0][0]:>8}   {cm[0][1]:>8}")
    print(f"  real 1        {cm[1][0]:>8}   {cm[1][1]:>8}")

    print("\nRelatorio de classificacao:")
    print(classification_report(y_real, y_pred, target_names=["sem risco", "risco"], digits=3))


# ------------------------------------------------------------- persistencia


def salvar_modelo(
    modelo: Pipeline,
    metricas: dict,
    hiperparametros: dict,
    x: pd.DataFrame,
) -> Path:
    """Grava o bundle consumido por app/services/prediction_service.py."""
    estimador = modelo.named_steps["rf"]
    importancias = dict(zip(FEATURES, estimador.feature_importances_.round(5)))

    # Medianas do treino: sao o fallback do imputer em producao.
    imputador: SimpleImputer = modelo.named_steps["imputer"]
    medianas = dict(zip(FEATURES, imputador.statistics_.round(4)))

    bundle = {
        "modelo": modelo,
        "features": list(FEATURES),
        "medianas": medianas,
        "limiares": LIMITARES,
        "algoritmo": "RandomForestClassifier",
        "metricas": metricas,
        "hiperparametros": hiperparametros,
        "importancias": importancias,
        "dataset": NOME_DATASET,
        "linhas_treino": int(len(x)),
        "treinado_em": datetime.now(timezone.utc).isoformat(),
        "versao_sklearn": __import__("sklearn").__version__,
    }

    CAMINHO_MODELO.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump(bundle, CAMINHO_MODELO, compress=3)

    tamanho_kb = CAMINHO_MODELO.stat().st_size / 1024
    print(f"\nModelo salvo em: {CAMINHO_MODELO}  ({tamanho_kb:.0f} KB)")

    print("\nImportancia das features:")
    for nome, valor in sorted(importancias.items(), key=lambda kv: -kv[1]):
        barra = "#" * int(round(valor * 100))
        print(f"  {nome:<22} {valor:.4f}  {barra}")

    return CAMINHO_MODELO


# -------------------------------------------------------------------- main


def treinar(forcar_dataset: bool = False) -> Path:
    print("=" * 66)
    print("FireWatch - treinamento do modelo de risco de incendio")
    print("=" * 66)

    df = carregar_dataset(forcar=forcar_dataset)
    x, y = montar_xy(df)

    # Holdout estratificado: preserva a proporcao de risco entre treino e teste.
    x_treino, x_teste, y_treino, y_teste = train_test_split(
        x, y, test_size=0.2, random_state=42, stratify=y
    )
    print(f"\nTreino: {len(x_treino):,} amostras | Teste: {len(x_teste):,} amostras")

    print("\nBuscando hiperparametros (GridSearchCV, 5-fold, scoring ROC-AUC)...")
    modelo, melhores = buscar_hiperparametros(x_treino, y_treino)
    print(f"  melhores parametros: {json.dumps(melhores, default=str)}")

    scores_cv = cross_val_score(
        modelo, x_treino, y_treino, cv=5, scoring="accuracy", n_jobs=-1
    )
    print(f"  acuracia na CV (5-fold): {scores_cv.mean():.4f} +/- {scores_cv.std():.4f}")

    y_pred = modelo.predict(x_teste)
    y_prob = modelo.predict_proba(x_teste)[:, 1]
    metricas = avaliar(y_teste, y_pred, y_prob)
    metricas["cv_accuracy_mean"] = round(float(scores_cv.mean()), 4)
    metricas["cv_accuracy_std"] = round(float(scores_cv.std()), 4)

    imprimir_relatorio(y_teste, y_pred, metricas)
    return salvar_modelo(modelo, metricas, melhores, x_treino)


def reavaliar() -> None:
    """Reaplica as metricas sobre o modelo.pkl ja salvo."""
    if not CAMINHO_MODELO.exists():
        raise SystemExit(f"Modelo nao encontrado: {CAMINHO_MODELO}. Rode o treinamento antes.")

    bundle = joblib.load(CAMINHO_MODELO)
    df = carregar_dataset()
    x, y = montar_xy(df)

    x_treino, x_teste, y_treino, y_teste = train_test_split(
        x, y, test_size=0.2, random_state=42, stratify=y
    )
    modelo = bundle["modelo"]
    y_pred = modelo.predict(x_teste)
    y_prob = modelo.predict_proba(x_teste)[:, 1]

    print(f"Algoritmo : {bundle['algoritmo']}")
    print(f"Treinado  : {bundle['treinado_em']}")
    print(f"Dataset   : {bundle['dataset']} ({bundle['linhas_treino']:,} linhas de treino)")
    imprimir_relatorio(y_teste, y_pred, avaliar(y_teste, y_pred, y_prob))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Treina o modelo do FireWatch.")
    parser.add_argument(
        "--forcar-dataset",
        action="store_true",
        help="Regenera o CSV sintetico antes de treinar.",
    )
    parser.add_argument(
        "--reavaliar",
        action="store_true",
        help="Reavalia o modelo.pkl salvo, sem retreinar.",
    )
    args = parser.parse_args()

    if args.reavaliar:
        reavaliar()
    else:
        treinar(forcar_dataset=args.forcar_dataset)