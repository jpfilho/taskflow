-- ============================================
-- SQL PARA SINCRONIZAR VINCULAÇÕES AUTOMÁTICAS
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- Este script sincroniza as vinculações entre notas SAP e ordens baseado no campo "ordem"

-- 1. Verificar correspondências entre notas e ordens
SELECT 
  'Verificando correspondências' as etapa,
  COUNT(DISTINCT n.id) as total_notas_com_ordem,
  COUNT(DISTINCT o.id) as total_ordens_correspondentes
FROM notas_sap n
INNER JOIN ordens o ON n.ordem = o.ordem
WHERE n.ordem IS NOT NULL AND n.ordem != '';

-- 2. Vincular ordens automaticamente para notas já vinculadas a tarefas
-- (mas que não têm a ordem correspondente vinculada)
INSERT INTO tasks_ordens (task_id, ordem_id)
SELECT DISTINCT
  tns.task_id,
  o.id as ordem_id
FROM tasks_notas_sap tns
INNER JOIN notas_sap n ON tns.nota_sap_id = n.id
INNER JOIN ordens o ON n.ordem = o.ordem
WHERE n.ordem IS NOT NULL 
  AND n.ordem != ''
  AND NOT EXISTS (
    SELECT 1 
    FROM tasks_ordens to2 
    WHERE to2.task_id = tns.task_id 
      AND to2.ordem_id = o.id
  )
ON CONFLICT (task_id, ordem_id) DO NOTHING;

-- 3. Vincular notas automaticamente para ordens já vinculadas a tarefas
-- (mas que não têm as notas correspondentes vinculadas)
INSERT INTO tasks_notas_sap (task_id, nota_sap_id)
SELECT DISTINCT
  to2.task_id,
  n.id as nota_sap_id
FROM tasks_ordens to2
INNER JOIN ordens o ON to2.ordem_id = o.id
INNER JOIN notas_sap n ON o.ordem = n.ordem
WHERE n.ordem IS NOT NULL 
  AND n.ordem != ''
  AND NOT EXISTS (
    SELECT 1 
    FROM tasks_notas_sap tns2 
    WHERE tns2.task_id = to2.task_id 
      AND tns2.nota_sap_id = n.id
  )
ON CONFLICT (task_id, nota_sap_id) DO NOTHING;

-- 4. Verificar resultado da sincronização
SELECT 
  'Após sincronização' as etapa,
  (SELECT COUNT(*) FROM tasks_notas_sap) as total_notas_vinculadas,
  (SELECT COUNT(*) FROM tasks_ordens) as total_ordens_vinculadas,
  (
    SELECT COUNT(DISTINCT tns.task_id)
    FROM tasks_notas_sap tns
    INNER JOIN notas_sap n ON tns.nota_sap_id = n.id
    INNER JOIN ordens o ON n.ordem = o.ordem
    INNER JOIN tasks_ordens to2 ON to2.task_id = tns.task_id AND to2.ordem_id = o.id
  ) as tarefas_com_sincronizacao_completa;

-- 5. Mostrar exemplos de vinculações sincronizadas
SELECT 
  tns.task_id,
  t.tarefa,
  n.nota as nota_sap,
  n.ordem as numero_ordem,
  o.ordem as ordem_numero,
  CASE 
    WHEN to2.id IS NOT NULL THEN '✅ Sincronizado'
    ELSE '❌ Falta vincular ordem'
  END as status_ordem
FROM tasks_notas_sap tns
INNER JOIN tasks t ON tns.task_id = t.id
INNER JOIN notas_sap n ON tns.nota_sap_id = n.id
LEFT JOIN ordens o ON n.ordem = o.ordem
LEFT JOIN tasks_ordens to2 ON to2.task_id = tns.task_id AND to2.ordem_id = o.id
WHERE n.ordem IS NOT NULL AND n.ordem != ''
LIMIT 20;
