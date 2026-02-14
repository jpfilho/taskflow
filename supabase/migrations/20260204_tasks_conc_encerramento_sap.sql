-- ============================================
-- VIEW: tasks_conc_encerramento_sap
-- Para tarefas CONC (concluídas), indica se há notas, ordens ou ATs
-- vinculados cujo status do sistema NÃO está encerrado.
-- Encerrado = status_sistema contém ENTE, ENCE ou MSEN (case insensitive).
-- ============================================

-- Função auxiliar: verifica se status_sistema indica encerramento
CREATE OR REPLACE FUNCTION public.status_sistema_encerrado(p_status_sistema TEXT)
RETURNS BOOLEAN
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT COALESCE(
    UPPER(TRIM(p_status_sistema)) LIKE '%ENTE%'
    OR UPPER(TRIM(p_status_sistema)) LIKE '%ENCE%'
    OR UPPER(TRIM(p_status_sistema)) LIKE '%MSEN%',
    FALSE
  );
$$;

COMMENT ON FUNCTION public.status_sistema_encerrado(TEXT) IS
'Retorna true se o status do sistema indica encerramento (contém ENTE, ENCE ou MSEN).';

-- Contagem de notas NÃO encerradas por task_id (apenas para tasks que tenham vínculo)
DROP VIEW IF EXISTS public.tasks_conc_encerramento_sap;

CREATE VIEW public.tasks_conc_encerramento_sap AS
WITH conc_tasks AS (
  SELECT id AS task_id, tarefa, status, regional, divisao, tipo, ordem AS ordem_txt, data_inicio, data_fim
  FROM public.tasks
  WHERE UPPER(TRIM(status)) = 'CONC'
),
-- Notas vinculadas que NÃO estão encerradas (status_sistema sem ENTE/ENCE/MSEN)
notas_nao_encerradas AS (
  SELECT
    tns.task_id,
    COUNT(*) AS qtd
  FROM public.tasks_notas_sap tns
  INNER JOIN public.notas_sap ns ON ns.id = tns.nota_sap_id
  INNER JOIN conc_tasks ct ON ct.task_id = tns.task_id
  WHERE NOT public.status_sistema_encerrado(ns.status_sistema)
  GROUP BY tns.task_id
),
-- Ordens vinculadas que NÃO estão encerradas
ordens_nao_encerradas AS (
  SELECT
    to_rel.task_id,
    COUNT(*) AS qtd
  FROM public.tasks_ordens to_rel
  INNER JOIN public.ordens o ON o.id = to_rel.ordem_id
  INNER JOIN conc_tasks ct ON ct.task_id = to_rel.task_id
  WHERE NOT public.status_sistema_encerrado(o.status_sistema)
  GROUP BY to_rel.task_id
),
-- ATs vinculadas que NÃO estão encerradas
ats_nao_encerradas AS (
  SELECT
    ta.task_id,
    COUNT(*) AS qtd
  FROM public.tasks_ats ta
  INNER JOIN public.ats a ON a.id = ta.at_id
  INNER JOIN conc_tasks ct ON ct.task_id = ta.task_id
  WHERE NOT public.status_sistema_encerrado(a.status_sistema)
  GROUP BY ta.task_id
)
SELECT
  ct.task_id,
  ct.tarefa,
  ct.status,
  ct.regional,
  ct.divisao,
  ct.tipo,
  ct.ordem_txt,
  ct.data_inicio,
  ct.data_fim,
  COALESCE(nn.qtd, 0)::INTEGER AS qtd_notas_nao_encerradas,
  COALESCE(on_.qtd, 0)::INTEGER AS qtd_ordens_nao_encerradas,
  COALESCE(an.qtd, 0)::INTEGER AS qtd_ats_nao_encerradas,
  (COALESCE(nn.qtd, 0) + COALESCE(on_.qtd, 0) + COALESCE(an.qtd, 0)) > 0 AS tem_algum_nao_encerrado
FROM conc_tasks ct
LEFT JOIN notas_nao_encerradas nn ON nn.task_id = ct.task_id
LEFT JOIN ordens_nao_encerradas on_ ON on_.task_id = ct.task_id
LEFT JOIN ats_nao_encerradas an ON an.task_id = ct.task_id
ORDER BY (COALESCE(nn.qtd, 0) + COALESCE(on_.qtd, 0) + COALESCE(an.qtd, 0)) DESC, ct.data_fim DESC NULLS LAST;

COMMENT ON VIEW public.tasks_conc_encerramento_sap IS
'Para tarefas CONC (concluídas): indica quantas notas/ordens/ATs vinculados têm status do sistema sem ENTE, ENCE ou MSEN (não encerrados). tem_algum_nao_encerrado = true quando há ao menos um item não encerrado.';

-- Permissões
GRANT SELECT ON public.tasks_conc_encerramento_sap TO authenticated;
GRANT SELECT ON public.tasks_conc_encerramento_sap TO anon;

-- ============================================
-- VIEW: tasks_encerramento_sap (para TODAS as tarefas)
-- Retorna por task_id as quantidades de notas/ordens/ATs NÃO encerrados.
-- Usado na tabela de atividades para colorir ícones: vermelho se algum não encerrado, verde se todos encerrados.
-- ============================================
DROP VIEW IF EXISTS public.tasks_encerramento_sap;

CREATE VIEW public.tasks_encerramento_sap AS
WITH all_tasks AS (
  SELECT id AS task_id FROM public.tasks
),
notas_nao_encerradas AS (
  SELECT
    tns.task_id,
    COUNT(*) AS qtd
  FROM public.tasks_notas_sap tns
  INNER JOIN public.notas_sap ns ON ns.id = tns.nota_sap_id
  WHERE NOT public.status_sistema_encerrado(ns.status_sistema)
  GROUP BY tns.task_id
),
ordens_nao_encerradas AS (
  SELECT
    to_rel.task_id,
    COUNT(*) AS qtd
  FROM public.tasks_ordens to_rel
  INNER JOIN public.ordens o ON o.id = to_rel.ordem_id
  WHERE NOT public.status_sistema_encerrado(o.status_sistema)
  GROUP BY to_rel.task_id
),
ats_nao_encerradas AS (
  SELECT
    ta.task_id,
    COUNT(*) AS qtd
  FROM public.tasks_ats ta
  INNER JOIN public.ats a ON a.id = ta.at_id
  WHERE NOT public.status_sistema_encerrado(a.status_sistema)
  GROUP BY ta.task_id
)
SELECT
  at.task_id,
  COALESCE(nn.qtd, 0)::INTEGER AS qtd_notas_nao_encerradas,
  COALESCE(on_.qtd, 0)::INTEGER AS qtd_ordens_nao_encerradas,
  COALESCE(an.qtd, 0)::INTEGER AS qtd_ats_nao_encerradas
FROM all_tasks at
LEFT JOIN notas_nao_encerradas nn ON nn.task_id = at.task_id
LEFT JOIN ordens_nao_encerradas on_ ON on_.task_id = at.task_id
LEFT JOIN ats_nao_encerradas an ON an.task_id = at.task_id;

COMMENT ON VIEW public.tasks_encerramento_sap IS
'Por tarefa: quantidades de notas/ordens/ATs vinculados cujo status do sistema NÃO está encerrado (sem ENTE, ENCE ou MSEN). Usado para colorir ícones na tabela: vermelho se > 0, verde se 0.';

GRANT SELECT ON public.tasks_encerramento_sap TO authenticated;
GRANT SELECT ON public.tasks_encerramento_sap TO anon;

NOTIFY pgrst, 'reload schema';
