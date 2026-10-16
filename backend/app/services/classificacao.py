"""Faixas, rotulos e recomendacoes de risco de incendio.

As classes e os cortes do indice 0-100 vivem em :mod:`ml.alvo` (fonte unica
compartilhada com o treinamento). Aqui ficam apenas os textos exibidos ao
usuario.
"""

from __future__ import annotations

from ml.alvo import (  # noqa: F401 - reexportado para conveniencia
    CLASSES,
    CORES,
    CORTES_INDICE,
    NIVEIS,
    classe_do_codigo,
    codigo_do_indice,
    cor_do_codigo,
    nivel_do_codigo,
)

#: Recomendacao textual de cada nivel de risco.
RECOMENDACOES: dict[str, str] = {
    "BAIXO": (
        "Condições favoráveis. Nenhuma ação urgente; evite jogar lixo ou faíscas "
        "e acompanhe os avisos oficiais."
    ),
    "MODERADO": (
        "Atenção: umidade em queda e temperaturas elevadas. Não faça queimadas e "
        "mantenha o terreno ao redor limpo e úmido."
    ),
    "CRÍTICO": (
        "Alerta máximo. Evite qualquer tipo de queimada de manejo e reporte focos "
        "de fumaça à Defesa Civil."
    ),
}

__all__ = [
    "CLASSES",
    "CORES",
    "CORTES_INDICE",
    "NIVEIS",
    "RECOMENDACOES",
    "classe_do_codigo",
    "codigo_do_indice",
    "cor_do_codigo",
    "nivel_do_codigo",
]
