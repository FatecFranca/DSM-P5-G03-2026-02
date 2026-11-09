CREATE TABLE IF NOT EXISTS public.firewatch_preprocessado (
    linha_origem integer PRIMARY KEY CHECK (linha_origem > 0),
    data date NOT NULL,
    municipio text NOT NULL CHECK (municipio <> ''),
    estado text NOT NULL CHECK (estado <> ''),
    bioma text NOT NULL CHECK (bioma <> ''),
    avg_numero_dias_sem_chuva double precision NOT NULL
        CHECK (avg_numero_dias_sem_chuva >= 0),
    avg_precipitacao double precision NOT NULL CHECK (avg_precipitacao >= 0),
    avg_risco_fogo double precision NOT NULL CHECK (avg_risco_fogo BETWEEN 0 AND 100),
    avg_frp double precision NOT NULL CHECK (avg_frp >= 0),
    bioma_ausente_original boolean NOT NULL,
    CONSTRAINT firewatch_preprocessado_data_local_unica
        UNIQUE (data, municipio, estado, bioma)
);

CREATE INDEX IF NOT EXISTS firewatch_preprocessado_data_idx
    ON public.firewatch_preprocessado (data DESC);

CREATE INDEX IF NOT EXISTS firewatch_preprocessado_local_data_idx
    ON public.firewatch_preprocessado (estado, municipio, data DESC);

CREATE INDEX IF NOT EXISTS firewatch_preprocessado_bioma_idx
    ON public.firewatch_preprocessado (bioma);
