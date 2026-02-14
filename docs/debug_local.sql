-- =============================================================================
-- DEBUG: LOCAL na tela de Atividades (tasks vs tasks_locais vs locais)
-- Execute no Supabase SQL Editor para verificar dados e estrutura.
-- =============================================================================

-- 1) Estrutura: a tabela tasks tem coluna "local" (varchar)?
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'tasks'
  AND column_name IN ('local', 'local_id', 'tipo', 'id')
ORDER BY ordinal_position;

-- 2) Contagem: quantas tasks têm pelo menos um vínculo em tasks_locais?
SELECT
  (SELECT count(*) FROM tasks) AS total_tasks,
  (SELECT count(DISTINCT task_id) FROM tasks_locais) AS tasks_com_tasks_locais,
  (SELECT count(*) FROM tasks WHERE id NOT IN (SELECT task_id FROM tasks_locais)) AS tasks_sem_tasks_locais;

-- 3) Contagem: quantas tasks têm a coluna tasks.local preenchida (se existir)?
-- (Descomente se a coluna 'local' existir em tasks)
/*
SELECT
  count(*) FILTER (WHERE (local IS NOT NULL AND trim(local) <> '')) AS tasks_com_coluna_local,
  count(*) FILTER (WHERE (local IS NULL OR trim(local) = '')) AS tasks_sem_coluna_local
FROM tasks;
*/

-- 4) Amostra: primeiras 5 tasks com seus locais (via tasks_locais + locais)
SELECT
  t.id AS task_id,
  t.tarefa,
  t.tipo,
  t.local AS tasks_coluna_local,  -- pode ser null se coluna não existir
  tl.local_id,
  l.local AS nome_local_tabela_locais
FROM tasks t
LEFT JOIN tasks_locais tl ON tl.task_id = t.id
LEFT JOIN locais l ON l.id = tl.local_id
ORDER BY t.id, tl.local_id
LIMIT 20;

-- 5) Tasks que têm tipo mas não têm nenhum local (nem tasks_locais nem coluna local)
-- (Ajuste: use apenas se tasks tiver coluna local)
SELECT t.id, t.tarefa, t.tipo, t.local AS tasks_local
FROM tasks t
LEFT JOIN tasks_locais tl ON tl.task_id = t.id
WHERE tl.task_id IS NULL
-- AND (t.local IS NULL OR trim(t.local) = '')  -- descomente se coluna existir
ORDER BY t.id
LIMIT 15;

-- 6) Simular filtro por LOCAL (M:N): ids de locais pelo nome e task_ids
-- Troque 'NOME_DO_LOCAL' pelo valor que você usa no filtro da tela
WITH locais_filtro AS (
  SELECT id FROM locais WHERE local IN ('NOME_DO_LOCAL')  -- altere aqui
),
task_ids_filtro AS (
  SELECT DISTINCT task_id FROM tasks_locais WHERE local_id IN (SELECT id FROM locais_filtro)
)
SELECT * FROM task_ids_filtro;

-- 7) Lista de nomes em locais (para usar no filtro do passo 6)
SELECT id, local FROM locais ORDER BY local LIMIT 50;

-- 8) Vínculos órfãos: tasks_locais com local_id que não existe em locais (join não acha nome)
SELECT tl.task_id, tl.local_id
FROM tasks_locais tl
LEFT JOIN locais l ON l.id = tl.local_id
WHERE l.id IS NULL
LIMIT 20;

-- 9) Uma task específica: todos os locais (tasks_locais + locais) e coluna tasks.local
-- Troque 'TASK_ID_AQUI' pelo id de uma task que aparece sem LOCAL na tela
/*
SELECT
  t.id,
  t.tarefa,
  t.tipo,
  t.local AS tasks_coluna_local,
  json_agg(json_build_object('local_id', tl.local_id, 'nome', l.local)) AS locais_via_join
FROM tasks t
LEFT JOIN tasks_locais tl ON tl.task_id = t.id
LEFT JOIN locais l ON l.id = tl.local_id
WHERE t.id = 'TASK_ID_AQUI'
GROUP BY t.id, t.tarefa, t.tipo, t.local;
*/

-- 10) Resumo: por task, quantos locais (via M:N) e valor da coluna local
SELECT
  t.id,
  t.tarefa,
  t.tipo,
  t.local AS coluna_local,
  count(tl.local_id) AS qtd_tasks_locais,
  string_agg(l.local, ', ' ORDER BY l.local) AS nomes_via_join
FROM tasks t
LEFT JOIN tasks_locais tl ON tl.task_id = t.id
LEFT JOIN locais l ON l.id = tl.local_id
GROUP BY t.id, t.tarefa, t.tipo, t.local
ORDER BY t.id
LIMIT 30;
