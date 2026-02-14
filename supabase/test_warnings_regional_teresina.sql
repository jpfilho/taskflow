-- ============================================
-- Teste: warnings da regional TERESINA
-- Executar no SQL Editor do Supabase (não exige auth para a view base).
-- ============================================

-- 1) Warnings da view base filtrados pela regional Teresina
-- (join com regionais pelo nome; case-insensitive)
SELECT
  w.task_id,
  w.warning_code,
  w.severity,
  w.message,
  w.fix_hint,
  w.details_json,
  r.regional AS regional_nome
FROM public.v_task_warnings_base w
INNER JOIN public.regionais r ON r.id = w.regional_id
WHERE TRIM(UPPER(r.regional)) = 'TERESINA'
ORDER BY w.severity DESC, w.task_id
LIMIT 100;

-- 2) Apenas contar quantos warnings existem para Teresina
-- SELECT COUNT(*) AS total_warnings_teresina
-- FROM public.v_task_warnings_base w
-- INNER JOIN public.regionais r ON r.id = w.regional_id
-- WHERE TRIM(UPPER(r.regional)) = 'TERESINA';

-- 3) Apenas W5 (programado já deveria ter iniciado) em Teresina
-- SELECT w.task_id, w.warning_code, w.severity, w.message, w.details_json, r.regional AS regional_nome
-- FROM public.v_task_warnings_base w
-- INNER JOIN public.regionais r ON r.id = w.regional_id
-- WHERE TRIM(UPPER(r.regional)) = 'TERESINA' AND w.warning_code = 'W5'
-- ORDER BY w.task_id LIMIT 50;
