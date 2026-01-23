-- ============================================
-- SQL PARA CRIAR TRIGGERS DE VINCULAÇÃO AUTOMÁTICA
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- Este script cria triggers que sincronizam automaticamente as vinculações

-- ============================================
-- 1. FUNÇÃO: Vincular ordem quando nota é vinculada
-- ============================================
CREATE OR REPLACE FUNCTION vincular_ordem_automaticamente()
RETURNS TRIGGER AS $$
DECLARE
  ordem_numero TEXT;
  ordem_id_var UUID;
BEGIN
  -- Buscar o número da ordem da nota vinculada
  SELECT ordem INTO ordem_numero
  FROM notas_sap
  WHERE id = NEW.nota_sap_id;
  
  -- Se a nota tem um número de ordem
  IF ordem_numero IS NOT NULL AND ordem_numero != '' THEN
    -- Buscar a ordem correspondente
    SELECT id INTO ordem_id_var
    FROM ordens
    WHERE ordem = ordem_numero
    LIMIT 1;
    
    -- Se encontrou a ordem e ainda não está vinculada
    IF ordem_id_var IS NOT NULL THEN
      -- Verificar se já está vinculada
      IF NOT EXISTS (
        SELECT 1 FROM tasks_ordens
        WHERE task_id = NEW.task_id
          AND ordem_id = ordem_id_var
      ) THEN
        -- Vincular a ordem automaticamente
        INSERT INTO tasks_ordens (task_id, ordem_id)
        VALUES (NEW.task_id, ordem_id_var)
        ON CONFLICT (task_id, ordem_id) DO NOTHING;
        
        RAISE NOTICE '✅ Ordem % vinculada automaticamente à tarefa %', ordem_numero, NEW.task_id;
      END IF;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 2. TRIGGER: Executar quando nota é vinculada
-- ============================================
DROP TRIGGER IF EXISTS trigger_vincular_ordem_ao_vincular_nota ON tasks_notas_sap;
CREATE TRIGGER trigger_vincular_ordem_ao_vincular_nota
  AFTER INSERT ON tasks_notas_sap
  FOR EACH ROW
  EXECUTE FUNCTION vincular_ordem_automaticamente();

-- ============================================
-- 3. FUNÇÃO: Vincular notas quando ordem é vinculada
-- ============================================
CREATE OR REPLACE FUNCTION vincular_notas_automaticamente()
RETURNS TRIGGER AS $$
DECLARE
  ordem_numero TEXT;
  nota_record RECORD;
BEGIN
  -- Buscar o número da ordem vinculada
  SELECT ordem INTO ordem_numero
  FROM ordens
  WHERE id = NEW.ordem_id;
  
  -- Se a ordem tem um número
  IF ordem_numero IS NOT NULL AND ordem_numero != '' THEN
    -- Para cada nota SAP com o mesmo número de ordem
    FOR nota_record IN
      SELECT id FROM notas_sap
      WHERE ordem = ordem_numero
    LOOP
      -- Verificar se já está vinculada
      IF NOT EXISTS (
        SELECT 1 FROM tasks_notas_sap
        WHERE task_id = NEW.task_id
          AND nota_sap_id = nota_record.id
      ) THEN
        -- Vincular a nota automaticamente
        INSERT INTO tasks_notas_sap (task_id, nota_sap_id)
        VALUES (NEW.task_id, nota_record.id)
        ON CONFLICT (task_id, nota_sap_id) DO NOTHING;
        
        RAISE NOTICE '✅ Nota % vinculada automaticamente à tarefa %', nota_record.id, NEW.task_id;
      END IF;
    END LOOP;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 4. TRIGGER: Executar quando ordem é vinculada
-- ============================================
DROP TRIGGER IF EXISTS trigger_vincular_notas_ao_vincular_ordem ON tasks_ordens;
CREATE TRIGGER trigger_vincular_notas_ao_vincular_ordem
  AFTER INSERT ON tasks_ordens
  FOR EACH ROW
  EXECUTE FUNCTION vincular_notas_automaticamente();

-- ============================================
-- 5. FUNÇÃO: Desvincular ordem quando nota é desvinculada
-- ============================================
CREATE OR REPLACE FUNCTION desvincular_ordem_automaticamente()
RETURNS TRIGGER AS $$
DECLARE
  ordem_numero TEXT;
  ordem_id_var UUID;
  outras_notas_count INTEGER;
BEGIN
  -- Buscar o número da ordem da nota desvinculada
  SELECT ordem INTO ordem_numero
  FROM notas_sap
  WHERE id = OLD.nota_sap_id;
  
  -- Se a nota tem um número de ordem
  IF ordem_numero IS NOT NULL AND ordem_numero != '' THEN
    -- Buscar a ordem correspondente
    SELECT id INTO ordem_id_var
    FROM ordens
    WHERE ordem = ordem_numero
    LIMIT 1;
    
    -- Se encontrou a ordem
    IF ordem_id_var IS NOT NULL THEN
      -- Verificar se há outras notas com o mesmo número de ordem vinculadas a esta tarefa
      SELECT COUNT(*) INTO outras_notas_count
      FROM tasks_notas_sap tns
      INNER JOIN notas_sap n ON tns.nota_sap_id = n.id
      WHERE tns.task_id = OLD.task_id
        AND n.ordem = ordem_numero
        AND tns.nota_sap_id != OLD.nota_sap_id;
      
      -- Se não há mais notas com este número de ordem vinculadas, desvincular a ordem
      IF outras_notas_count = 0 THEN
        DELETE FROM tasks_ordens
        WHERE task_id = OLD.task_id
          AND ordem_id = ordem_id_var;
        
        RAISE NOTICE '✅ Ordem % desvinculada automaticamente (nenhuma nota restante)', ordem_numero;
      END IF;
    END IF;
  END IF;
  
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 6. TRIGGER: Executar quando nota é desvinculada
-- ============================================
DROP TRIGGER IF EXISTS trigger_desvincular_ordem_ao_desvincular_nota ON tasks_notas_sap;
CREATE TRIGGER trigger_desvincular_ordem_ao_desvincular_nota
  AFTER DELETE ON tasks_notas_sap
  FOR EACH ROW
  EXECUTE FUNCTION desvincular_ordem_automaticamente();

-- ============================================
-- 7. FUNÇÃO: Desvincular notas quando ordem é desvinculada
-- ============================================
CREATE OR REPLACE FUNCTION desvincular_notas_automaticamente()
RETURNS TRIGGER AS $$
DECLARE
  ordem_numero TEXT;
  nota_record RECORD;
BEGIN
  -- Buscar o número da ordem desvinculada
  SELECT ordem INTO ordem_numero
  FROM ordens
  WHERE id = OLD.ordem_id;
  
  -- Se a ordem tem um número
  IF ordem_numero IS NOT NULL AND ordem_numero != '' THEN
    -- Para cada nota SAP com o mesmo número de ordem
    FOR nota_record IN
      SELECT id FROM notas_sap
      WHERE ordem = ordem_numero
    LOOP
      -- Desvincular a nota
      DELETE FROM tasks_notas_sap
      WHERE task_id = OLD.task_id
        AND nota_sap_id = nota_record.id;
      
      RAISE NOTICE '✅ Nota % desvinculada automaticamente', nota_record.id;
    END LOOP;
  END IF;
  
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 8. TRIGGER: Executar quando ordem é desvinculada
-- ============================================
DROP TRIGGER IF EXISTS trigger_desvincular_notas_ao_desvincular_ordem ON tasks_ordens;
CREATE TRIGGER trigger_desvincular_notas_ao_desvincular_ordem
  AFTER DELETE ON tasks_ordens
  FOR EACH ROW
  EXECUTE FUNCTION desvincular_notas_automaticamente();

-- ============================================
-- 9. VERIFICAR SE OS TRIGGERS FORAM CRIADOS
-- ============================================
SELECT 
  trigger_name,
  event_manipulation,
  event_object_table,
  action_statement
FROM information_schema.triggers
WHERE trigger_name IN (
  'trigger_vincular_ordem_ao_vincular_nota',
  'trigger_vincular_notas_ao_vincular_ordem',
  'trigger_desvincular_ordem_ao_desvincular_nota',
  'trigger_desvincular_notas_ao_desvincular_ordem'
)
ORDER BY trigger_name;

-- ============================================
-- 10. TESTAR OS TRIGGERS (OPCIONAL - COMENTE APÓS TESTAR)
-- ============================================
-- Descomente as linhas abaixo para testar os triggers
-- (substitua os IDs pelos IDs reais do seu banco)

/*
-- Teste 1: Vincular uma nota e verificar se a ordem foi vinculada
INSERT INTO tasks_notas_sap (task_id, nota_sap_id)
VALUES ('ID_DA_TAREFA', 'ID_DA_NOTA')
ON CONFLICT DO NOTHING;

-- Verificar se a ordem foi vinculada
SELECT * FROM tasks_ordens WHERE task_id = 'ID_DA_TAREFA';

-- Teste 2: Vincular uma ordem e verificar se as notas foram vinculadas
INSERT INTO tasks_ordens (task_id, ordem_id)
VALUES ('ID_DA_TAREFA', 'ID_DA_ORDEM')
ON CONFLICT DO NOTHING;

-- Verificar se as notas foram vinculadas
SELECT * FROM tasks_notas_sap WHERE task_id = 'ID_DA_TAREFA';
*/
