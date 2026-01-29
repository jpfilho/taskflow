-- ============================================
-- MIGRATION: ADICIONAR REGIONAL_ID A COMUNIDADES
-- ============================================
-- Adicionar regional_id à tabela comunidades e atualizar constraint UNIQUE
-- para garantir que cada combinação regional+divisão+segmento seja única
-- Data: 2026-01-25

-- 1. Adicionar coluna regional_id se não existir
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'comunidades' 
    AND column_name = 'regional_id'
  ) THEN
    ALTER TABLE comunidades ADD COLUMN regional_id UUID;
    ALTER TABLE comunidades ADD COLUMN regional_nome VARCHAR(255);
    
    -- Atualizar registros existentes com regional_id baseado na divisão
    UPDATE comunidades c
    SET regional_id = d.regional_id,
        regional_nome = r.regional
    FROM divisoes d
    LEFT JOIN regionais r ON r.id = d.regional_id
    WHERE c.divisao_id = d.id
    AND c.regional_id IS NULL;
    
    RAISE NOTICE 'Coluna regional_id adicionada e preenchida';
  END IF;
END $$;

-- 2. Tornar regional_id NOT NULL após preencher dados existentes
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'comunidades' 
    AND column_name = 'regional_id'
    AND is_nullable = 'YES'
  ) THEN
    -- Verificar se todos os registros têm regional_id
    IF NOT EXISTS (SELECT 1 FROM comunidades WHERE regional_id IS NULL) THEN
      ALTER TABLE comunidades ALTER COLUMN regional_id SET NOT NULL;
      RAISE NOTICE 'Coluna regional_id definida como NOT NULL';
    ELSE
      RAISE WARNING 'Existem registros sem regional_id. Corrija antes de definir NOT NULL.';
    END IF;
  END IF;
END $$;

-- 3. Adicionar referência à tabela regionais
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'comunidades_regional_id_fkey'
  ) THEN
    ALTER TABLE comunidades 
    ADD CONSTRAINT comunidades_regional_id_fkey 
    FOREIGN KEY (regional_id) REFERENCES regionais(id) ON DELETE CASCADE;
    
    RAISE NOTICE 'Foreign key para regionais adicionada';
  END IF;
END $$;

-- 4. Remover constraint UNIQUE antiga (divisao_id, segmento_id)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'comunidades_divisao_id_segmento_id_key'
  ) THEN
    ALTER TABLE comunidades
    DROP CONSTRAINT comunidades_divisao_id_segmento_id_key;
    RAISE NOTICE 'Constraint UNIQUE antiga removida';
  END IF;
END $$;

-- 5. Criar nova constraint UNIQUE incluindo regional_id
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'comunidades_regional_divisao_segmento_key'
  ) THEN
    ALTER TABLE comunidades
    ADD CONSTRAINT comunidades_regional_divisao_segmento_key 
    UNIQUE(regional_id, divisao_id, segmento_id);
    
    RAISE NOTICE 'Nova constraint UNIQUE criada (regional_id, divisao_id, segmento_id)';
  END IF;
END $$;

-- 6. Criar índice composto para busca rápida
CREATE INDEX IF NOT EXISTS idx_comunidades_regional_divisao_segmento 
ON comunidades(regional_id, divisao_id, segmento_id);

-- 7. Atualizar índice existente se necessário
CREATE INDEX IF NOT EXISTS idx_comunidades_regional_id 
ON comunidades(regional_id);

-- 8. Comentários
COMMENT ON COLUMN comunidades.regional_id IS 'ID da regional - parte da chave única (regional + divisão + segmento)';
COMMENT ON COLUMN comunidades.regional_nome IS 'Nome da regional (para exibição)';
