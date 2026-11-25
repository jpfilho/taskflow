-- Adiciona suporte à unidade de trabalho real do SAP (UniTrabRea: H, HR, MIN)
-- na tabela public.horas_sap e normaliza minutos para horas na view de apontamentos.

ALTER TABLE public.horas_sap
  ADD COLUMN IF NOT EXISTS uni_trab_rea VARCHAR(10);

COMMENT ON COLUMN public.horas_sap.uni_trab_rea IS
  'Unidade de trabalho real exportada do SAP (ex: H, HR, MIN). Quando MIN/M, os cálculos convertem trabalho_real / 60.0.';

CREATE OR REPLACE FUNCTION public.fn_horas_sap_normalizar_horas(
  p_valor numeric,
  p_unidade text
)
RETURNS numeric
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_valor IS NULL THEN 0
    WHEN UPPER(TRIM(COALESCE(p_unidade, 'H'))) IN ('MIN', 'M') THEN p_valor / 60.0
    ELSE p_valor
  END;
$$;

CREATE OR REPLACE VIEW public.horas_apontadas_por_empregado_ordem_mes AS
SELECT
  TRIM(BOTH FROM h.numero_pessoa) AS matricula,
  TRIM(BOTH FROM h.ordem) AS ordem,
  EXTRACT(year FROM h.data_lancamento)::integer AS ano,
  EXTRACT(month FROM h.data_lancamento)::integer AS mes,
  to_char(date_trunc('month'::text, h.data_lancamento::timestamp with time zone), 'YYYY-MM'::text) AS ano_mes,
  COALESCE(
    sum(public.fn_horas_sap_normalizar_horas(h.trabalho_real, h.uni_trab_rea)),
    0::numeric
  )::double precision AS horas_apontadas
FROM public.horas_sap h
WHERE h.data_lancamento IS NOT NULL
  AND h.numero_pessoa IS NOT NULL
  AND TRIM(BOTH FROM h.numero_pessoa) <> ''::text
  AND h.ordem IS NOT NULL
  AND TRIM(BOTH FROM h.ordem) <> ''::text
GROUP BY
  (TRIM(BOTH FROM h.numero_pessoa)),
  (TRIM(BOTH FROM h.ordem)),
  (date_trunc('month'::text, h.data_lancamento::timestamp with time zone)),
  (EXTRACT(year FROM h.data_lancamento)),
  (EXTRACT(month FROM h.data_lancamento))
ORDER BY
  (TRIM(BOTH FROM h.numero_pessoa)),
  (EXTRACT(year FROM h.data_lancamento)::integer),
  (EXTRACT(month FROM h.data_lancamento)::integer),
  (TRIM(BOTH FROM h.ordem));

