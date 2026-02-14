-- ============================================
-- VIEW: ordens_programadas_por_empregado_mes (atualizada)
-- Inclui task_id, tarefa, status (da tarefa) e local (ordem + locais) para
-- exibir no diálogo de Ordens da tela de Metas.
-- ============================================

DROP VIEW IF EXISTS public.ordens_programadas_por_empregado_mes;

CREATE VIEW public.ordens_programadas_por_empregado_mes AS
WITH tasks_do_executor_por_mes AS (
  SELECT
    te.executor_id,
    COALESCE(e.matricula, '') AS matricula,
    te.task_id,
    t.regional_id,
    t.divisao_id,
    t.segmento_id,
    DATE_TRUNC('month', mes_intersecao)::date AS mes_referencia,
    EXTRACT(YEAR FROM DATE_TRUNC('month', mes_intersecao))::int AS ano,
    EXTRACT(MONTH FROM DATE_TRUNC('month', mes_intersecao))::int AS mes
  FROM public.tasks_executores te
  INNER JOIN public.tasks t ON t.id = te.task_id
  LEFT JOIN public.executores e ON e.id = te.executor_id
  CROSS JOIN LATERAL generate_series(
    DATE_TRUNC('month', GREATEST(t.data_inicio, DATE_TRUNC('year', t.data_inicio)::date))::date,
    DATE_TRUNC('month', t.data_fim)::date,
    '1 month'::interval
  ) AS mes_intersecao
  WHERE COALESCE(e.matricula, '') != ''
),
ordens_da_tarefa AS (
  SELECT
    ppm.matricula,
    ppm.ano,
    ppm.mes,
    ppm.mes_referencia,
    ppm.task_id,
    ppm.regional_id,
    ppm.divisao_id,
    ppm.segmento_id,
    t.tarefa,
    t.status AS task_status,
    TRIM(o.ordem) AS ordem,
    TRIM(o.tipo) AS tipo,
    TRIM(o.sala) AS sala,
    TRIM(o.texto_breve) AS texto_breve,
    o.local_instalacao,
    o.denominacao_local_instalacao,
    TRIM(l.local) AS local_nome
  FROM tasks_do_executor_por_mes ppm
  INNER JOIN public.tasks t ON t.id = ppm.task_id
  INNER JOIN public.tasks_ordens to_rel ON to_rel.task_id = ppm.task_id
  INNER JOIN public.ordens o ON o.id = to_rel.ordem_id
  LEFT JOIN public.locais l ON l.local_instalacao_sap IS NOT NULL
    AND TRIM(BOTH FROM l.local_instalacao_sap) <> ''
    AND o.local_instalacao IS NOT NULL
    AND o.local_instalacao ~~ (('%' || l.local_instalacao_sap) || '%')
  WHERE o.ordem IS NOT NULL AND TRIM(o.ordem) != ''
)
SELECT
  matricula,
  ano,
  mes,
  TO_CHAR(mes_referencia, 'YYYY-MM') AS ano_mes,
  ordem,
  tipo,
  sala,
  texto_breve,
  task_id,
  tarefa AS task_tarefa,
  task_status,
  COALESCE(NULLIF(TRIM(local_nome), ''), denominacao_local_instalacao, local_instalacao) AS local_detalhe,
  regional_id,
  divisao_id,
  segmento_id
FROM ordens_da_tarefa
ORDER BY matricula, ano, mes, ordem, task_tarefa;

COMMENT ON VIEW public.ordens_programadas_por_empregado_mes IS
'Ordens em que cada empregado está programado por mês, com task_id, tarefa, status e local. Uma linha por (matricula, ano, mes, ordem, task).';

GRANT SELECT ON public.ordens_programadas_por_empregado_mes TO authenticated;
GRANT SELECT ON public.ordens_programadas_por_empregado_mes TO anon;

NOTIFY pgrst, 'reload schema';
