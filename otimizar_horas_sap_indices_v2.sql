-- ============================================
-- SQL PARA OTIMIZAR PERFORMANCE DA TABELA HORAS_SAP
-- ============================================
-- Versão simplificada e segura
-- ============================================

-- Verificar se a tabela existe primeiro
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'horas_sap') THEN
        RAISE EXCEPTION 'Tabela horas_sap não existe! Crie a tabela primeiro.';
    END IF;
END $$;

-- ============================================
-- 1. CRIAR ÍNDICES BÁSICOS
-- ============================================

CREATE INDEX IF NOT EXISTS idx_horas_sap_data_lancamento 
ON horas_sap(data_lancamento DESC);

CREATE INDEX IF NOT EXISTS idx_horas_sap_numero_pessoa 
ON horas_sap(numero_pessoa);

CREATE INDEX IF NOT EXISTS idx_horas_sap_centro_trabalho 
ON horas_sap(centro_trabalho_real);

CREATE INDEX IF NOT EXISTS idx_horas_sap_nome_empregado 
ON horas_sap(nome_empregado);

CREATE INDEX IF NOT EXISTS idx_horas_sap_ordem 
ON horas_sap(ordem);

CREATE INDEX IF NOT EXISTS idx_horas_sap_status_sistema 
ON horas_sap(status_sistema);

CREATE INDEX IF NOT EXISTS idx_horas_sap_tipo_atividade_real 
ON horas_sap(tipo_atividade_real);

-- ============================================
-- 2. CRIAR ÍNDICES COMPOSTOS (MAIS EFICIENTES)
-- ============================================

CREATE INDEX IF NOT EXISTS idx_horas_sap_data_centro 
ON horas_sap(data_lancamento DESC, centro_trabalho_real);

CREATE INDEX IF NOT EXISTS idx_horas_sap_numero_data 
ON horas_sap(numero_pessoa, data_lancamento DESC);

-- ============================================
-- 3. HABILITAR EXTENSÃO PARA BUSCAS ILIKE
-- ============================================

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_horas_sap_centro_trgm 
ON horas_sap USING gin(centro_trabalho_real gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_horas_sap_nome_trgm 
ON horas_sap USING gin(nome_empregado gin_trgm_ops);

-- ============================================
-- 4. ATUALIZAR ESTATÍSTICAS
-- ============================================

ANALYZE horas_sap;
