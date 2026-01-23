-- ============================================
-- SCRIPT COMPLETO PARA CORRIGIR TABELA PEX NO SUPABASE
-- Execute este script no SQL Editor do Supabase
-- ============================================

-- 1. Primeiro, vamos verificar a estrutura atual
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'pex'
ORDER BY ordinal_position;

-- 2. Se a tabela não existir, criar do zero
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

-- 3. Adicionar todas as colunas que possam estar faltando
DO $$ 
DECLARE
    col_exists BOOLEAN;
BEGIN
    -- Lista de todas as colunas que devem existir
    DECLARE
        cols TEXT[] := ARRAY[
            'aterramento_descricao', 'TEXT',
            'aterramento_total_unidades', 'INTEGER',
            'instalacao', 'VARCHAR(255)',
            'equipamentos', 'TEXT',
            'resumo_atividade', 'TEXT',
            'configuracao_recebimento', 'TEXT',
            'configuracao_durante', 'TEXT',
            'configuracao_devolucao', 'TEXT',
            'informacoes_adicionais', 'TEXT',
            'distancias_seguranca', 'TEXT',
            'dados_planejamento', 'TEXT',
            'recursos_epi', 'TEXT',
            'recursos_epc', 'TEXT',
            'recursos_transporte', 'TEXT',
            'recursos_material_consumo', 'TEXT',
            'recursos_ferramentas', 'TEXT',
            'recursos_comunicacao', 'TEXT',
            'recursos_documentacao', 'TEXT',
            'recursos_instrumentos', 'TEXT',
            'detalhamento_intervencao', 'TEXT',
            'recursos_humanos', 'TEXT',
            'nivel_risco', 'VARCHAR(50)',
            'aprovador', 'VARCHAR(255)',
            'data_aprovacao', 'DATE',
            'status', 'VARCHAR(50)',
            'numero_pex', 'VARCHAR(50)',
            'si', 'VARCHAR(50)',
            'revisao_pex', 'INTEGER',
            'data_elaboracao', 'DATE',
            'responsavel_nome', 'VARCHAR(255)',
            'responsavel_id_sap', 'VARCHAR(50)',
            'responsavel_contato', 'VARCHAR(50)',
            'substituto_nome', 'VARCHAR(255)',
            'substituto_id_sap', 'VARCHAR(50)',
            'substituto_contato', 'VARCHAR(50)',
            'fiscal_tecnico_nome', 'VARCHAR(255)',
            'fiscal_tecnico_id_sap', 'VARCHAR(50)',
            'fiscal_tecnico_contato', 'VARCHAR(50)',
            'coordenador_nome', 'VARCHAR(255)',
            'coordenador_id_sap', 'VARCHAR(50)',
            'coordenador_contato', 'VARCHAR(50)',
            'tecnico_seg_nome', 'VARCHAR(255)',
            'tecnico_seg_id_sap', 'VARCHAR(50)',
            'tecnico_seg_contato', 'VARCHAR(50)',
            'data_inicio', 'DATE',
            'hora_inicio', 'TIME',
            'data_fim', 'DATE',
            'hora_fim', 'TIME',
            'periodicidade', 'BOOLEAN',
            'continuo', 'BOOLEAN'
        ];
    BEGIN
        FOR i IN 1..array_length(cols, 1) BY 2 LOOP
            SELECT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_name = 'pex' AND column_name = cols[i]
            ) INTO col_exists;
            
            IF NOT col_exists THEN
                EXECUTE format('ALTER TABLE pex ADD COLUMN %I %s', cols[i], cols[i+1]);
                RAISE NOTICE 'Coluna % adicionada', cols[i];
            END IF;
        END LOOP;
    END;
END $$;

-- 4. Criar índices
CREATE INDEX IF NOT EXISTS idx_pex_task_id ON pex(task_id);
CREATE INDEX IF NOT EXISTS idx_pex_status ON pex(status);

-- 5. Criar/atualizar trigger para updated_at
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

-- 6. Habilitar RLS se ainda não estiver habilitado
ALTER TABLE pex ENABLE ROW LEVEL SECURITY;

-- 7. Criar política se não existir
DROP POLICY IF EXISTS "Permitir todas as operações em pex" ON pex;
CREATE POLICY "Permitir todas as operações em pex" ON pex
  FOR ALL USING (true) WITH CHECK (true);

-- 8. Forçar atualização do schema cache do PostgREST
-- Nota: Isso pode não funcionar diretamente, mas ajuda a garantir que o schema está correto
NOTIFY pgrst, 'reload schema';

-- 9. Verificar estrutura final
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'pex'
ORDER BY ordinal_position;

-- 10. Verificar se há dados na tabela
SELECT COUNT(*) as total_pex FROM pex;
