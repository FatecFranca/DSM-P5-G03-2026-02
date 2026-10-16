"""Pipeline de Machine Learning do FireWatch."""

from ml.alvo import CLASSES, CORTES_INDICE, NIVEIS
from ml.features import FEATURES, construir_features, vetor_features

__all__ = [
    "CLASSES",
    "CORTES_INDICE",
    "FEATURES",
    "NIVEIS",
    "construir_features",
    "vetor_features",
]
