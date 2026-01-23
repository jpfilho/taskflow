CREATE OR REPLACE VIEW public.contagens_frotas_tarefas AS
WITH fp AS (
  SELECT task_id, COUNT(*)::integer AS cnt
  FROM frota_periods
  GROUP BY task_id
),
tf AS (
  SELECT task_id, COUNT(DISTINCT frota_id)::integer AS cnt
  FROM tasks_frotas
  GROUP BY task_id
)
SELECT 
    t.id AS task_id,
    GREATEST(
        COALESCE(fp.cnt, 0),
        COALESCE(tf.cnt, 0),
        CASE 
            WHEN t.frota IS NOT NULL 
              AND t.frota != '' 
              AND t.frota != '-N/A-' 
            THEN 1 
            ELSE 0 
        END
    ) AS quantidade,
    COALESCE(t.frota, '') AS frota_nome
FROM tasks t
LEFT JOIN fp ON fp.task_id = t.id
LEFT JOIN tf ON tf.task_id = t.id;

COMMENT ON VIEW public.contagens_frotas_tarefas IS 'Contagem de frotas por tarefa (verifica se campo frota está preenchido)';

-- IMPORTANTE: Esta VIEW herda as políticas RLS da tabela tasks
-- Se a tabela tasks tem RLS habilitado, a VIEW também terá.

-- Recarregar o schema do PostgREST para que a nova VIEW seja reconhecida
NOTIFY pgrst, 'reload schema';
