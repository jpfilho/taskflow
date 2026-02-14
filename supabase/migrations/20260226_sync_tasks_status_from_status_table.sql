-- ============================================
-- Sincronizar tasks.status com a tabela status
-- ============================================
-- Corrige linhas em que status_id aponta para um status (ex.: RPGR) mas a coluna
-- tasks.status está desatualizada (ex.: PROG). Assim a view W5 e o app passam a
-- enxergar o status correto.
-- ============================================

UPDATE public.tasks t
SET status = UPPER(TRIM(st.codigo))
FROM public.status st
WHERE st.id = t.status_id
  AND (t.status IS DISTINCT FROM UPPER(TRIM(st.codigo)));
