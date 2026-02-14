-- ============================================
-- VIEW dinâmica: horas_programadas_por_empregado_mes (substitui uso de MV)
-- Horas programadas = dias distintos com atividade × 8h, sem exceder 8h por dia.
-- Exclui FÉRIAS (FER). Dados sempre atualizados (VIEW, não MV).
-- ============================================

DROP VIEW IF EXISTS public.horas_programadas_por_empregado_mes;

CREATE VIEW public.horas_programadas_por_empregado_mes AS
WITH periodos_expandidos AS (
  SELECT
    ep.executor_id,
    COALESCE(e.matricula, '') AS matricula,
    ep.task_id,
    t.regional_id,
    t.divisao_id,
    t.segmento_id,
    DATE_TRUNC('month', mes_intersecao)::date AS mes_referencia,
    ep.data_inicio,
    ep.data_fim,
    ep.tipo
  FROM public.executor_periods ep
  INNER JOIN public.tasks t ON t.id = ep.task_id
  LEFT JOIN public.executores e ON e.id = ep.executor_id
  CROSS JOIN LATERAL generate_series(
    DATE_TRUNC('month', GREATEST(ep.data_inicio, DATE_TRUNC('year', ep.data_inicio)::date))::date,
    DATE_TRUNC('month', ep.data_fim)::date,
    '1 month'::interval
  ) AS mes_intersecao
  WHERE (ep.tipo IS NULL OR ep.tipo != 'FER')
    AND COALESCE(e.matricula, '') != ''
),
dias_uteis_por_periodo AS (
  SELECT
    pe.matricula,
    pe.mes_referencia,
    pe.regional_id,
    pe.divisao_id,
    pe.segmento_id,
    GREATEST(pe.data_inicio, DATE_TRUNC('month', pe.mes_referencia)::date) AS inicio_intersecao,
    LEAST(pe.data_fim, (DATE_TRUNC('month', pe.mes_referencia) + INTERVAL '1 month - 1 day')::date) AS fim_intersecao
  FROM periodos_expandidos pe
),
dias_individuais AS (
  SELECT
    dup.matricula,
    dup.mes_referencia,
    dup.regional_id,
    dup.divisao_id,
    dup.segmento_id,
    (d.dia)::date AS dia
  FROM dias_uteis_por_periodo dup
  CROSS JOIN LATERAL generate_series(
    dup.inicio_intersecao,
    dup.fim_intersecao,
    '1 day'::interval
  ) AS d(dia)
  WHERE dup.inicio_intersecao <= dup.fim_intersecao
)
-- Um registro por (matrícula, mês): total_trabalho_planejado = dias distintos × 8h
SELECT
  matricula,
  EXTRACT(YEAR FROM mes_referencia)::int AS ano,
  EXTRACT(MONTH FROM mes_referencia)::int AS mes,
  mes_referencia AS mes_ref,
  TO_CHAR(mes_referencia, 'YYYY-MM') AS ano_mes,
  COUNT(DISTINCT dia) * 8.0 AS horas_programadas,
  COUNT(DISTINCT dia) * 8.0 AS total_trabalho_planejado
FROM dias_individuais
GROUP BY matricula, mes_referencia
ORDER BY matricula, mes_referencia;

COMMENT ON VIEW public.horas_programadas_por_empregado_mes IS
'Horas programadas por empregado e mês (VIEW dinâmica): dias distintos com atividade × 8h, máx. 8h/dia. Exclui FÉRIAS (FER). Substitui uso de MV estática.';

GRANT SELECT ON public.horas_programadas_por_empregado_mes TO authenticated;
GRANT SELECT ON public.horas_programadas_por_empregado_mes TO anon;

NOTIFY pgrst, 'reload schema';
