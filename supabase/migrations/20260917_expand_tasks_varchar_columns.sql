-- ==============================================================================
-- MIGRATION: Expandir colunas de texto da tabela public.tasks
-- ==============================================================================
-- 1. Dropar temporariamente a view dependente da coluna frota
-- 2. Alterar as colunas da tabela tasks para TEXT
-- 3. Recriar a view contagens_frotas_tarefas com sua definição exata
-- ==============================================================================

-- 1. Dropar view dependente
DROP VIEW IF EXISTS public.contagens_frotas_tarefas CASCADE;

-- 2. Alterar colunas da tabela tasks para TEXT (sem limites de caracteres)
ALTER TABLE public.tasks 
  ALTER COLUMN executor TYPE TEXT,
  ALTER COLUMN frota TYPE TEXT,
  ALTER COLUMN local TYPE TEXT,
  ALTER COLUMN coordenador TYPE TEXT,
  ALTER COLUMN regional TYPE TEXT,
  ALTER COLUMN divisao TYPE TEXT;

-- 3. Recriar a view contagens_frotas_tarefas exatamente como a original
CREATE VIEW public.contagens_frotas_tarefas AS
WITH
  fp AS (
    SELECT
      frota_periods.task_id,
      COUNT(*)::integer AS cnt
    FROM
      frota_periods
    GROUP BY
      frota_periods.task_id
  ),
  tf AS (
    SELECT
      tasks_frotas.task_id,
      COUNT(DISTINCT tasks_frotas.frota_id)::integer AS cnt
    FROM
      tasks_frotas
    GROUP BY
      tasks_frotas.task_id
  )
SELECT
  t.id AS task_id,
  GREATEST(
    COALESCE(fp.cnt, 0),
    COALESCE(tf.cnt, 0),
    CASE
      WHEN t.frota IS NOT NULL
      AND t.frota::text <> ''::text
      AND t.frota::text <> '-N/A-'::text THEN 1
      ELSE 0
    END
  ) AS quantidade,
  COALESCE(t.frota, ''::text) AS frota_nome
FROM
  tasks t
  LEFT JOIN fp ON fp.task_id = t.id
  LEFT JOIN tf ON tf.task_id = t.id;

COMMENT ON VIEW public.contagens_frotas_tarefas IS 'Contagem de frotas por tarefa (verifica se campo frota está preenchido)';

-- 4. Notificar PostgREST para recarregar o schema
NOTIFY pgrst, 'reload schema';
