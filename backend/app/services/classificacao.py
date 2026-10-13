"""Serviço de classificação de risco de incêndio em três faixas."""

from __future__ import annotations

from typing import TypedDict


class Classificacao(TypedDict):
    nivel_risco: str
    cor_alerta: str


RECOMENDACOES: dict[str, str] = {
    "BAIXO": "Condições favoráveis. Nenhuma ação urgente; evite jogar lixo ou faíscas e acompanhe os avisos oficiais.",
    "MODERADO": "Atenção: umidade em queda e temperaturas elevadas. Não faça queimadas e mantenha o terreno ao redor limpo e úmido.",
    "CRÍTICO": "Alerta máximo. Evite qualquer tipo de queimada de manejo e reporte focos de fumaça à Defesa Civil.",
}


def classificar(prob: float) -> Classificacao:
    """Classifica probabilidade de incêndio em três faixas."""
    if prob < 0.30:
        return {"nivel_risco": "BAIXO", "cor_alerta": "#22C55E"}
    if prob < 0.70:
        return {"nivel_risco": "MODERADO", "cor_alerta": "#FACC15"}
    return {"nivel_risco": "CRÍTICO", "cor_alerta": "#DC2626"}
