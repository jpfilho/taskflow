-- ============================================
-- OTIMIZAÇÕES PARA MELHORAR PERFORMANCE DA VIEW
-- ============================================

-- 1. Adicionar índices adicionais para melhorar performance
CREATE INDEX IF NOT EXISTS idx_executor_periods_dates_tipo 
ON public.executor_periods(data_inicio, data_fim, tipo_periodo) 
WHERE UPPER(tipo_periodo::text) IN ('EXECUCAO', 'PLANEJAMENTO', 'DESLOCAMENTO');

CREATE INDEX IF NOT EXISTS idx_gantt_segments_dates_tipo 
ON public.gantt_segments(data_inicio, data_fim, tipo_periodo) 
WHERE UPPER(tipo_periodo::text) IN ('EXECUCAO', 'PLANEJAMENTO', 'DESLOCAMENTO');

CREATE INDEX IF NOT EXISTS idx_tasks_status_dates 
ON public.tasks(status, data_inicio, data_fim) 
WHERE UPPER(status::text) <> 'CANC';

-- 2. Índice adicional para melhorar joins com tasks
-- NOTA: Não podemos usar subquery em índice parcial, então criamos índice simples
CREATE INDEX IF NOT EXISTS idx_executor_periods_task_dates 
ON public.executor_periods(task_id, executor_id, data_inicio, data_fim);

-- 3. Estatísticas atualizadas para o planner
ANALYZE public.executor_periods;
ANALYZE public.gantt_segments;
ANALYZE public.tasks;
ANALYZE public.tasks_executores;
ANALYZE public.tasks_locais;

-- ============================================
-- COMENTÁRIOS
-- ============================================
-- Esses índices ajudam o PostgreSQL a:
-- 1. Filtrar tarefas canceladas mais cedo
-- 2. Usar índices para ranges de datas
-- 3. Otimizar joins e filtros por tipo_periodo
-- 4. Melhorar performance do generate_series
