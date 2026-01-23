-- ============================================
-- SCRIPT PARA VERIFICAR E CORRIGIR TABELA PEX NO SUPABASE
-- ============================================

-- 1. Verificar se a tabela existe e suas colunas
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'pex'
ORDER BY ordinal_position;

-- 2. Se a tabela não existir ou estiver faltando colunas, execute o CREATE TABLE abaixo
-- (Execute apenas se necessário)

-- ============================================
-- CRIAR TABELA PEX (se não existir)
-- ============================================
CREATE TABLE IF NOT EXISTS pex (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  
  -- Cabeçalho
  numero_pex VARCHAR(50),
  si VARCHAR(50),
  revisao_pex INTEGER DEFAULT 1,
  data_elaboracao DATE,
  
  -- 1. IDENTIFICAÇÃO DA INTERVENÇÃO
  responsavel_nome VARCHAR(255),
  responsavel_id_sap VARCHAR(50),
  responsavel_contato VARCHAR(50),
  substituto_nome VARCHAR(255),
  substituto_id_sap VARCHAR(50),
  substituto_contato VARCHAR(50),
  fiscal_tecnico_nome VARCHAR(255),
  fiscal_tecnico_id_sap VARCHAR(50),
  fiscal_tecnico_contato VARCHAR(50),
  coordenador_nome VARCHAR(255),
  coordenador_id_sap VARCHAR(50),
  coordenador_contato VARCHAR(50),
  tecnico_seg_nome VARCHAR(255),
  tecnico_seg_id_sap VARCHAR(50),
  tecnico_seg_contato VARCHAR(50),
  
  -- Período
  data_inicio DATE,
  hora_inicio TIME,
  data_fim DATE,
  hora_fim TIME,
  periodicidade BOOLEAN DEFAULT FALSE,
  continuo BOOLEAN DEFAULT FALSE,
  
  -- Instalação e Equipamentos
  instalacao VARCHAR(255),
  equipamentos TEXT,
  
  -- Resumo da Atividade
  resumo_atividade TEXT,
  
  -- Configuração
  configuracao_recebimento TEXT,
  configuracao_durante TEXT,
  configuracao_devolucao TEXT,
  
  -- Aterramento
  aterramento_descricao TEXT,
  aterramento_total_unidades INTEGER,
  
  -- Informações adicionais
  informacoes_adicionais TEXT,
  
  -- Distâncias de Segurança (JSON)
  distancias_seguranca TEXT,
  
  -- 2. DADOS PARA PLANEJAMENTO DA INTERVENÇÃO (JSON)
  dados_planejamento TEXT,
  
  -- 3. RECURSOS / FERRAMENTAS / MATERIAIS (JSON)
  recursos_epi TEXT,
  recursos_epc TEXT,
  recursos_transporte TEXT,
  recursos_material_consumo TEXT,
  recursos_ferramentas TEXT,
  recursos_comunicacao TEXT,
  recursos_documentacao TEXT,
  recursos_instrumentos TEXT,
  
  -- 4. DETALHAMENTO DA INTERVENÇÃO (JSON)
  detalhamento_intervencao TEXT,
  
  -- 5. RECURSOS HUMANOS E CIÊNCIA DOS RISCOS (JSON)
  recursos_humanos TEXT,
  
  -- Nível de risco
  nivel_risco VARCHAR(50),
  
  -- Aprovação
  aprovador VARCHAR(255),
  data_aprovacao DATE,
  
  -- Status
  status VARCHAR(50) DEFAULT 'rascunho',
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(task_id)
);

-- 3. Adicionar colunas faltantes (se a tabela já existir mas faltar colunas)
-- Execute apenas as ALTER TABLE necessárias

-- Verificar e adicionar aterramento_descricao se não existir
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pex' AND column_name = 'aterramento_descricao'
    ) THEN
        ALTER TABLE pex ADD COLUMN aterramento_descricao TEXT;
    END IF;
END $$;

-- Verificar e adicionar aterramento_total_unidades se não existir
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pex' AND column_name = 'aterramento_total_unidades'
    ) THEN
        ALTER TABLE pex ADD COLUMN aterramento_total_unidades INTEGER;
    END IF;
END $$;

-- Verificar e adicionar outras colunas que possam estar faltando
DO $$ 
BEGIN
    -- Verificar e adicionar instalacao se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pex' AND column_name = 'instalacao'
    ) THEN
        ALTER TABLE pex ADD COLUMN instalacao VARCHAR(255);
    END IF;
    
    -- Verificar e adicionar equipamentos se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pex' AND column_name = 'equipamentos'
    ) THEN
        ALTER TABLE pex ADD COLUMN equipamentos TEXT;
    END IF;
    
    -- Verificar e adicionar resumo_atividade se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pex' AND column_name = 'resumo_atividade'
    ) THEN
        ALTER TABLE pex ADD COLUMN resumo_atividade TEXT;
    END IF;
    
    -- Verificar e adicionar configuracao_recebimento se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pex' AND column_name = 'configuracao_recebimento'
    ) THEN
        ALTER TABLE pex ADD COLUMN configuracao_recebimento TEXT;
    END IF;
    
    -- Verificar e adicionar configuracao_durante se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pex' AND column_name = 'configuracao_durante'
    ) THEN
        ALTER TABLE pex ADD COLUMN configuracao_durante TEXT;
    END IF;
    
    -- Verificar e adicionar configuracao_devolucao se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pex' AND column_name = 'configuracao_devolucao'
    ) THEN
        ALTER TABLE pex ADD COLUMN configuracao_devolucao TEXT;
    END IF;
    
    -- Verificar e adicionar informacoes_adicionais se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pex' AND column_name = 'informacoes_adicionais'
    ) THEN
        ALTER TABLE pex ADD COLUMN informacoes_adicionais TEXT;
    END IF;
    
    -- Verificar e adicionar distancias_seguranca se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pex' AND column_name = 'distancias_seguranca'
    ) THEN
        ALTER TABLE pex ADD COLUMN distancias_seguranca TEXT;
    END IF;
    
    -- Verificar e adicionar dados_planejamento se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pex' AND column_name = 'dados_planejamento'
    ) THEN
        ALTER TABLE pex ADD COLUMN dados_planejamento TEXT;
    END IF;
    
    -- Verificar e adicionar recursos_epi se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pex' AND column_name = 'recursos_epi'
    ) THEN
        ALTER TABLE pex ADD COLUMN recursos_epi TEXT;
    END IF;
    
    -- Verificar e adicionar recursos_epc se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pex' AND column_name = 'recursos_epc'
    ) THEN
        ALTER TABLE pex ADD COLUMN recursos_epc TEXT;
    END IF;
    
    -- Verificar e adicionar recursos_transporte se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pex' AND column_name = 'recursos_transporte'
    ) THEN
        ALTER TABLE pex ADD COLUMN recursos_transporte TEXT;
    END IF;
    
    -- Verificar e adicionar recursos_material_consumo se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pex' AND column_name = 'recursos_material_consumo'
    ) THEN
        ALTER TABLE pex ADD COLUMN recursos_material_consumo TEXT;
    END IF;
    
    -- Verificar e adicionar recursos_ferramentas se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pex' AND column_name = 'recursos_ferramentas'
    ) THEN
        ALTER TABLE pex ADD COLUMN recursos_ferramentas TEXT;
    END IF;
    
    -- Verificar e adicionar recursos_comunicacao se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pex' AND column_name = 'recursos_comunicacao'
    ) THEN
        ALTER TABLE pex ADD COLUMN recursos_comunicacao TEXT;
    END IF;
    
    -- Verificar e adicionar recursos_documentacao se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pex' AND column_name = 'recursos_documentacao'
    ) THEN
        ALTER TABLE pex ADD COLUMN recursos_documentacao TEXT;
    END IF;
    
    -- Verificar e adicionar recursos_instrumentos se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pex' AND column_name = 'recursos_instrumentos'
    ) THEN
        ALTER TABLE pex ADD COLUMN recursos_instrumentos TEXT;
    END IF;
    
    -- Verificar e adicionar detalhamento_intervencao se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pex' AND column_name = 'detalhamento_intervencao'
    ) THEN
        ALTER TABLE pex ADD COLUMN detalhamento_intervencao TEXT;
    END IF;
    
    -- Verificar e adicionar recursos_humanos se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pex' AND column_name = 'recursos_humanos'
    ) THEN
        ALTER TABLE pex ADD COLUMN recursos_humanos TEXT;
    END IF;
    
    -- Verificar e adicionar nivel_risco se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pex' AND column_name = 'nivel_risco'
    ) THEN
        ALTER TABLE pex ADD COLUMN nivel_risco VARCHAR(50);
    END IF;
    
    -- Verificar e adicionar aprovador se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pex' AND column_name = 'aprovador'
    ) THEN
        ALTER TABLE pex ADD COLUMN aprovador VARCHAR(255);
    END IF;
    
    -- Verificar e adicionar data_aprovacao se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pex' AND column_name = 'data_aprovacao'
    ) THEN
        ALTER TABLE pex ADD COLUMN data_aprovacao DATE;
    END IF;
    
    -- Verificar e adicionar status se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pex' AND column_name = 'status'
    ) THEN
        ALTER TABLE pex ADD COLUMN status VARCHAR(50) DEFAULT 'rascunho';
    END IF;
END $$;

-- 4. Criar índices para melhorar performance
CREATE INDEX IF NOT EXISTS idx_pex_task_id ON pex(task_id);
CREATE INDEX IF NOT EXISTS idx_pex_status ON pex(status);

-- 5. Criar trigger para atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION update_pex_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_pex_updated_at ON pex;
CREATE TRIGGER trigger_update_pex_updated_at
    BEFORE UPDATE ON pex
    FOR EACH ROW
    EXECUTE FUNCTION update_pex_updated_at();

-- 6. Verificar novamente as colunas após as correções
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'pex'
ORDER BY ordinal_position;
