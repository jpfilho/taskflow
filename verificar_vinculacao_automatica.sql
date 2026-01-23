-- ============================================
-- SQL PARA VERIFICAR E TESTAR VINCULAÇÃO AUTOMÁTICA
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard

-- 1. Verificar se a tabela tasks_ordens existe
SELECT 
  CASE 
    WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'tasks_ordens')
    THEN '✅ Tabela tasks_ordens existe'
    ELSE '❌ Tabela tasks_ordens NÃO existe - Execute criar_tabela_tasks_ordens.sql primeiro!'
  END AS status_tabela;

-- 2. Verificar se há notas SAP com número de ordem
SELECT 
  COUNT(*) as total_notas,
  COUNT(ordem) as notas_com_ordem,
  COUNT(*) - COUNT(ordem) as notas_sem_ordem
FROM notas_sap;

-- 3. Verificar se há ordens correspondentes às notas
SELECT 
  n.ordem,
  COUNT(DISTINCT n.id) as total_notas,
  COUNT(DISTINCT o.id) as total_ordens
FROM notas_sap n
LEFT JOIN ordens o ON n.ordem = o.ordem
WHERE n.ordem IS NOT NULL
GROUP BY n.ordem
ORDER BY total_notas DESC
LIMIT 10;

-- 4. Verificar vínculos existentes
SELECT 
  'tasks_notas_sap' as tabela,
  COUNT(*) as total_vinculos
FROM tasks_notas_sap
UNION ALL
SELECT 
  'tasks_ordens' as tabela,
  COUNT(*) as total_vinculos
FROM tasks_ordens;

-- 5. Verificar se há notas vinculadas sem ordem correspondente vinculada
SELECT 
  tns.task_id,
  tns.nota_sap_id,
  n.ordem,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM tasks_ordens to2
      INNER JOIN ordens o ON to2.ordem_id = o.id
      WHERE to2.task_id = tns.task_id AND o.ordem = n.ordem
    )
    THEN '✅ Ordem vinculada'
    ELSE '❌ Ordem NÃO vinculada'
  END as status_ordem
FROM tasks_notas_sap tns
INNER JOIN notas_sap n ON tns.nota_sap_id = n.id
WHERE n.ordem IS NOT NULL
LIMIT 20;

-- 6. Verificar se há ordens vinculadas sem notas correspondentes vinculadas
SELECT 
  to2.task_id,
  to2.ordem_id,
  o.ordem,
  (
    SELECT COUNT(*)
    FROM notas_sap n
    WHERE n.ordem = o.ordem
  ) as total_notas_com_ordem,
  (
    SELECT COUNT(*)
    FROM tasks_notas_sap tns
    INNER JOIN notas_sap n2 ON tns.nota_sap_id = n2.id
    WHERE tns.task_id = to2.task_id AND n2.ordem = o.ordem
  ) as notas_vinculadas
FROM tasks_ordens to2
INNER JOIN ordens o ON to2.ordem_id = o.id
LIMIT 20;
