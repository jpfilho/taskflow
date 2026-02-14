-- ============================================
-- VIEW: ordens_programadas_por_empregado_mes
-- Ordens em que cada empregado está programado, por mês.
--
-- Fluxo: (1) Tasks em que o empregado/executor faz parte (tasks_executores)
--        (2) Depois verificar a tabela task e ordem (tasks_ordens + ordens)
--
--   - tasks_executores: em quais tasks o executor está (task_id, executor_id)
--   - tasks: dados da tarefa (data_inicio, data_fim, regional_id, divisao_id, segmento_id)
--   - tasks_ordens: vínculo task_id -> ordem_id (ordens atribuídas à tarefa)
--   - ordens: número da ordem (ordem) a partir do ordem_id
-- Os meses são obtidos pela interseção do executor na task (data_inicio a data_fim da task).
-- Usado na tela de Metas para comparar com horas apontadas (horas_sap).
-- ============================================

DROP VIEW IF EXISTS public.ordens_programadas_por_empregado_mes;

CREATE VIEW public.ordens_programadas_por_empregado_mes AS
WITH tasks_do_executor_por_mes AS (
  -- (1) Tasks em que o executor faz parte (tasks_executores) e expansão por mês (data_inicio/data_fim da task)
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
-- (2) Ordens vinculadas às tarefas via tasks_ordens -> tabela ordens (colunas: ordem, tipo, sala, texto_breve)
ordens_da_tarefa AS (
  SELECT
    ppm.matricula,
    ppm.ano,
    ppm.mes,
    ppm.mes_referencia,
    ppm.regional_id,
    ppm.divisao_id,
    ppm.segmento_id,
    TRIM(o.ordem) AS ordem,
    TRIM(o.tipo) AS tipo,
    TRIM(o.sala) AS sala,
    TRIM(o.texto_breve) AS texto_breve
  FROM tasks_do_executor_por_mes ppm
  INNER JOIN public.tasks_ordens to_rel ON to_rel.task_id = ppm.task_id
  INNER JOIN public.ordens o ON o.id = to_rel.ordem_id
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
  regional_id,
  divisao_id,
  segmento_id
FROM ordens_da_tarefa
GROUP BY matricula, ano, mes, mes_referencia, ordem, tipo, sala, texto_breve, regional_id, divisao_id, segmento_id
ORDER BY matricula, ano, mes, ordem;

COMMENT ON VIEW public.ordens_programadas_por_empregado_mes IS
'Ordens em que cada empregado está programado por mês: (1) tasks em que o executor faz parte (tasks_executores), (2) ordens da tarefa (tasks_ordens + ordens). Meses pela data_inicio/data_fim da task.';

-- ============================================
-- VIEW: horas_apontadas_por_empregado_ordem_mes
-- Horas apontadas (horas_sap) agrupadas por matrícula, ordem e mês.
-- ============================================

DROP VIEW IF EXISTS public.horas_apontadas_por_empregado_ordem_mes;

CREATE VIEW public.horas_apontadas_por_empregado_ordem_mes AS
SELECT
  TRIM(h.numero_pessoa) AS matricula,
  TRIM(h.ordem) AS ordem,
  EXTRACT(YEAR FROM h.data_lancamento)::int AS ano,
  EXTRACT(MONTH FROM h.data_lancamento)::int AS mes,
  TO_CHAR(DATE_TRUNC('month', h.data_lancamento), 'YYYY-MM') AS ano_mes,
  COALESCE(SUM(h.trabalho_real), 0)::double precision AS horas_apontadas
FROM public.horas_sap h
WHERE h.data_lancamento IS NOT NULL
  AND h.numero_pessoa IS NOT NULL
  AND TRIM(h.numero_pessoa) != ''
  AND h.ordem IS NOT NULL
  AND TRIM(h.ordem) != ''
GROUP BY
  TRIM(h.numero_pessoa),
  TRIM(h.ordem),
  DATE_TRUNC('month', h.data_lancamento),
  EXTRACT(YEAR FROM h.data_lancamento),
  EXTRACT(MONTH FROM h.data_lancamento)
ORDER BY matricula, ano, mes, ordem;

COMMENT ON VIEW public.horas_apontadas_por_empregado_ordem_mes IS
'Horas apontadas (trabalho_real) por empregado (matrícula), ordem e mês. Fonte: horas_sap. Usado na tela de Metas para mostrar horas por ordem e detectar apontamentos em ordens não programadas.';

-- Permissões
GRANT SELECT ON public.ordens_programadas_por_empregado_mes TO authenticated;
GRANT SELECT ON public.ordens_programadas_por_empregado_mes TO anon;
GRANT SELECT ON public.horas_apontadas_por_empregado_ordem_mes TO authenticated;
GRANT SELECT ON public.horas_apontadas_por_empregado_ordem_mes TO anon;

NOTIFY pgrst, 'reload schema';
