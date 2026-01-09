-- ============================================
-- SQL PARA CRIAR TABELA DE EXECUTORES
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new

-- Criar tabela de executores
CREATE TABLE IF NOT EXISTS executores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome VARCHAR(255) NOT NULL,
    divisao_id UUID REFERENCES divisoes(id) ON DELETE SET NULL,
    segmento_id UUID REFERENCES segmentos(id) ON DELETE SET NULL,
    ativo BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Criar índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_executores_divisao_id ON executores(divisao_id);
CREATE INDEX IF NOT EXISTS idx_executores_segmento_id ON executores(segmento_id);
CREATE INDEX IF NOT EXISTS idx_executores_ativo ON executores(ativo);

-- Habilitar RLS (Row Level Security)
ALTER TABLE executores ENABLE ROW LEVEL SECURITY;

-- Política para permitir leitura para todos os usuários autenticados
CREATE POLICY "Permitir leitura de executores para usuários autenticados"
    ON executores FOR SELECT
    USING (auth.role() = 'authenticated');

-- Política para permitir inserção para usuários autenticados
CREATE POLICY "Permitir inserção de executores para usuários autenticados"
    ON executores FOR INSERT
    WITH CHECK (auth.role() = 'authenticated');

-- Política para permitir atualização para usuários autenticados
CREATE POLICY "Permitir atualização de executores para usuários autenticados"
    ON executores FOR UPDATE
    USING (auth.role() = 'authenticated');

-- Política para permitir exclusão para usuários autenticados
CREATE POLICY "Permitir exclusão de executores para usuários autenticados"
    ON executores FOR DELETE
    USING (auth.role() = 'authenticated');

-- Função para atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION update_executores_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para atualizar updated_at
CREATE TRIGGER update_executores_updated_at
    BEFORE UPDATE ON executores
    FOR EACH ROW
    EXECUTE FUNCTION update_executores_updated_at();

-- Comentários nas colunas
COMMENT ON TABLE executores IS 'Tabela de cadastro de executores';
COMMENT ON COLUMN executores.id IS 'ID único do executor';
COMMENT ON COLUMN executores.nome IS 'Nome do executor';
COMMENT ON COLUMN executores.divisao_id IS 'ID da divisão associada (opcional)';
COMMENT ON COLUMN executores.segmento_id IS 'ID do segmento associado (opcional)';
COMMENT ON COLUMN executores.ativo IS 'Indica se o executor está ativo';
COMMENT ON COLUMN executores.created_at IS 'Data de criação do registro';
COMMENT ON COLUMN executores.updated_at IS 'Data da última atualização do registro';

