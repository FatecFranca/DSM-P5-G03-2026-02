# Contorno do Brasil

`brasil.geojson`: malha simplificada oficial do IBGE, obtida em 21/10/2026.

Fonte: https://servicodados.ibge.gov.br/api/v3/malhas/paises/BR?formato=application/vnd.geo+json&qualidade=maxima

Documentação: https://servicodados.ibge.gov.br/api/docs/malhas?versao=3

Usada para validar o centro solicitado e recortar as células regionais no território
brasileiro. A simplificação limita a precisão junto à costa e às fronteiras; não
usar esta geometria para demarcação territorial ou decisões em escala de rua.
