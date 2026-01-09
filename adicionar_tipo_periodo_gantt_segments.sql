-- ============================================
-- SQL PARA ADICIONAR TIPO DE PERÍODO AOS SEGMENTOS DO GANTT
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new

-- Adicionar coluna tipo_periodo na tabela gantt_segments
DO $$
BEGIN
  -- Verificar se a coluna já existe
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'gantt_segments' 
    AND column_name = 'tipo_periodo'
  ) THEN
    -- Adicionar coluna tipo_periodo
    ALTER TABLE gantt_segments 
    ADD COLUMN tipo_periodo VARCHAR(20) NOT NULL DEFAULT 'EXECUCAO' 
    CHECK (tipo_periodo IN ('EXECUCAO', 'PLANEJAMENTO', 'DESLOCAMENTO'));
    
    -- Adicionar comentário
    COMMENT ON COLUMN gantt_segments.tipo_periodo IS 'Tipo de período: EXECUCAO (padrão), PLANEJAMENTO (laranja), DESLOCAMENTO (azul escuro)';
    
    RAISE NOTICE 'Coluna tipo_periodo adicionada com sucesso!';
  ELSE
    RAISE NOTICE 'Coluna tipo_periodo já existe.';
  END IF;
END $$;

-- Verificar se a coluna foi criada corretamente
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'gantt_segments'
  AND column_name = 'tipo_periodo';

