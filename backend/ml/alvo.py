"""Definicao canonica do alvo de classificacao de risco de incendio.

O indice de risco e levado para a escala 0-100 pelo percentil do ``risco_fogo``
observado no banco e cortado em tres classes:

- ``Risco Baixo``    -> indice 0 a 30
- ``Risco Moderado`` -> indice 31 a 70
- ``Risco Critico``  -> indice 71 a 100

Este e o unico lugar onde a definicao das classes e dos cortes vive. Tanto o
treinamento (``ml/treinamento.py``) quanto a inferencia em producao
(``app/services``) importam daqui.
"""

from __future__ import annotations

#: Cortes do indice 0-100 que separam as 3 classes.
CORTES_INDICE: tuple[float, float] = (30.0, 70.0)

#: Rotulos completos das classes, na ordem dos codigos 0 / 1 / 2.
CLASSES: tuple[str, ...] = (
    "Risco Baixo",
    "Risco Moderado",
    "Risco Crítico",
)

#: Rotulos curtos usados pela API (compativeis com o parser do app Flutter).
NIVEIS: tuple[str, ...] = ("BAIXO", "MODERADO", "CRÍTICO")

#: Cor de alerta de cada classe (mesma ordem dos codigos).
CORES: tuple[str, ...] = ("#22C55E", "#FACC15", "#DC2626")

#: Numero de classes.
N_CLASSES: int = len(CLASSES)


def codigo_do_indice(indice: float) -> int:
    """Codigo da classe (0=Baixo, 1=Moderado, 2=Critico) para um indice 0-100."""
    if indice < CORTES_INDICE[0]:
        return 0
    if indice < CORTES_INDICE[1]:
        return 1
    return 2


def nivel_do_codigo(codigo: int) -> str:
    """Rotulo curto (BAIXO/MODERADO/CRÍTICO) de um codigo de classe."""
    return NIVEIS[codigo]


def classe_do_codigo(codigo: int) -> str:
    """Rotulo completo (Risco Baixo/Moderado/Crítico) de um codigo de classe."""
    return CLASSES[codigo]


def cor_do_codigo(codigo: int) -> str:
    """Cor de alerta hexadecimal de um codigo de classe."""
    return CORES[codigo]
