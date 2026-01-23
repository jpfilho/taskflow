-- ============================================
-- SQL PARA CRIAR TABELA DE JUNÇÃO ENTRE TASKS E FROTAS
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
--
-- IMPORTANTE: As tabelas 'tasks' e 'frota' devem existir ANTES desta

-- Tabela de junção para relacionamento N:N entre tasks e frotas
CREATE TABLE IF NOT EXISTS tasks_frotas (
  task_id UUID REFERENCES tasks(id) ON DELETE CASCADE,
  frota_id UUID REFERENCES frota(id) ON DELETE CASCADE,
  PRIMARY KEY (task_id, frota_id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_tasks_frotas_task_id ON tasks_frotas(task_id);
CREATE INDEX IF NOT EXISTS idx_tasks_frotas_frota_id ON tasks_frotas(frota_id);

-- Políticas RLS (Row Level Security)
ALTER TABLE tasks_frotas ENABLE ROW LEVEL SECURITY;

-- Remover políticas existentes se houver (para evitar duplicatas)
DROP POLICY IF EXISTS "Permitir todas as operações em tasks_frotas" ON tasks_frotas;

-- Política para permitir todas as operações
CREATE POLICY "Permitir todas as operações em tasks_frotas" ON tasks_frotas
  FOR ALL USING (true) WITH CHECK (true);

-- Migrar dados existentes do campo frota (texto) para a tabela de junção
-- Isso tenta encontrar a frota pelo nome/placa e criar o vínculo
DO $$
DECLARE
  task_record RECORD;
  frota_record RECORD;
  frota_parts TEXT[];
BEGIN
  RAISE NOTICE 'Migrando dados do campo frota para tasks_frotas...';
  
  FOR task_record IN 
    SELECT id, frota 
    FROM tasks 
    WHERE frota IS NOT NULL 
      AND frota != '' 
      AND frota != '-N/A-'
  LOOP
    -- Tentar encontrar por nome completo (formato: "Nome - Placa")
    IF task_record.frota LIKE '% - %' THEN
      frota_parts := string_to_array(task_record.frota, ' - ');
      IF array_length(frota_parts, 1) >= 2 THEN
        SELECT * INTO frota_record
        FROM frota
        WHERE nome = frota_parts[1]
          AND placa = frota_parts[2]
        LIMIT 1;
      END IF;
    END IF;
    
    -- Se não encontrou, tentar apenas pelo nome
    IF NOT FOUND THEN
      SELECT * INTO frota_record
      FROM frota
      WHERE nome = task_record.frota
      LIMIT 1;
    END IF;
    
    -- Se encontrou a frota, criar o vínculo
    IF FOUND THEN
      INSERT INTO tasks_frotas (task_id, frota_id)
      VALUES (task_record.id, frota_record.id)
      ON CONFLICT (task_id, frota_id) DO NOTHING;
    END IF;
  END LOOP;
  
  RAISE NOTICE 'Migração de frotas concluída.';
END $$;

-- Comentários na tabela
COMMENT ON TABLE tasks_frotas IS 'Tabela de junção para associar múltiplas frotas a uma tarefa';

-- Verificar se a tabela foi criada corretamente
SELECT
  table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'tasks_frotas'
ORDER BY ordinal_position;
