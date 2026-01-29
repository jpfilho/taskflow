-- ============================================
-- SQL PARA OTIMIZAR PERFORMANCE DA TABELA HORAS_SAP
-- ============================================
-- Este script cria índices otimizados para evitar timeouts
-- nas queries da tela de Horas
--
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new
--

-- ============================================
-- 1. CRIAR ÍNDICES BÁSICOS
-- ============================================

-- Índice para data_lancamento (usado em filtros de data e ordenação)
CREATE INDEX IF NOT EXISTS idx_horas_sap_data_lancamento 
ON horas_sap(data_lancamento DESC);

-- Índice para numero_pessoa (usado em filtros e joins)
CREATE INDEX IF NOT EXISTS idx_horas_sap_numero_pessoa 
ON horas_sap(numero_pessoa);

-- Índice para centro_trabalho_real (usado em filtros de perfil)
CREATE INDEX IF NOT EXISTS idx_horas_sap_centro_trabalho 
ON horas_sap(centro_trabalho_real);

-- Índice para nome_empregado (usado em buscas)
CREATE INDEX IF NOT EXISTS idx_horas_sap_nome_empregado 
ON horas_sap(nome_empregado);

-- Índice para ordem (usado em filtros)
CREATE INDEX IF NOT EXISTS idx_horas_sap_ordem 
ON horas_sap(ordem);

-- Índice para status_sistema (usado em filtros)
CREATE INDEX IF NOT EXISTS idx_horas_sap_status_sistema 
ON horas_sap(status_sistema);

-- Índice para tipo_atividade_real (usado em filtros)
CREATE INDEX IF NOT EXISTS idx_horas_sap_tipo_atividade_real 
ON horas_sap(tipo_atividade_real);

-- ============================================
-- 2. CRIAR ÍNDICES COMPOSTOS (MAIS EFICIENTES)
-- ============================================

-- Índice composto para a query principal (data + centro de trabalho)
-- Este é o mais importante para resolver o timeout!
CREATE INDEX IF NOT EXISTS idx_horas_sap_data_centro 
ON horas_sap(data_lancamento DESC, centro_trabalho_real);

-- Índice composto para agregações por empregado
CREATE INDEX IF NOT EXISTS idx_horas_sap_numero_data 
ON horas_sap(numero_pessoa, data_lancamento DESC);

-- ============================================
-- 3. HABILITAR EXTENSÃO PARA BUSCAS ILIKE
-- ============================================

-- Habilita pg_trgm para buscas com ILIKE mais rápidas
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Índice GIN para buscas ILIKE em centro_trabalho_real
CREATE INDEX IF NOT EXISTS idx_horas_sap_centro_trgm 
ON horas_sap USING gin(centro_trabalho_real gin_trgm_ops);

-- Índice GIN para buscas ILIKE em nome_empregado
CREATE INDEX IF NOT EXISTS idx_horas_sap_nome_trgm 
ON horas_sap USING gin(nome_empregado gin_trgm_ops);

-- ============================================
-- 4. CRIAR VIEW MATERIALIZADA PARA CONTAGENS
-- ============================================

-- View materializada para contagens rápidas (evita contar toda hora)
DROP MATERIALIZED VIEW IF EXISTS horas_sap_contagem_rapida;

CREATE MATERIALIZED VIEW horas_sap_contagem_rapida AS
SELECT 
  DATE_TRUNC('month', data_lancamento) as mes_ref,
  centro_trabalho_real,
  COUNT(*) as total_horas
FROM horas_sap
WHERE data_lancamento IS NOT NULL
GROUP BY DATE_TRUNC('month', data_lancamento), centro_trabalho_real;

-- Índice na view materializada
CREATE INDEX idx_horas_contagem_mes_centro 
ON horas_sap_contagem_rapida(mes_ref DESC, centro_trabalho_real);

-- ============================================
-- 5. FUNÇÃO PARA ATUALIZAR VIEW MATERIALIZADA
-- ============================================

-- Função para refresh da view (executar após importar novos dados)
CREATE OR REPLACE FUNCTION refresh_horas_sap_contagem()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY horas_sap_contagem_rapida;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 6. CRIAR VIEW OTIMIZADA PARA AGREGAÇÕES
-- ============================================

-- View para agregações por empregado e mês (substitui lógica complexa do service)
DROP VIEW IF EXISTS horas_sap_por_empregado_mes CASCADE;

CREATE OR REPLACE VIEW horas_sap_por_empregado_mes AS
SELECT 
  numero_pessoa as matricula,
  nome_empregado,
  centro_trabalho_real,
  EXTRACT(YEAR FROM data_lancamento)::int as ano,
  EXTRACT(MONTH FROM data_lancamento)::int as mes,
  TO_CHAR(data_lancamento, 'YYYY-MM') as ano_mes,
  tipo_atividade_real,
  SUM(trabalho_real) as horas_apontadas,
  COUNT(*) as total_apontamentos
FROM horas_sap
WHERE 
  data_lancamento IS NOT NULL 
  AND numero_pessoa IS NOT NULL
  AND trabalho_real IS NOT NULL
GROUP BY 
  numero_pessoa,
  nome_empregado,
  centro_trabalho_real,
  EXTRACT(YEAR FROM data_lancamento),
  EXTRACT(MONTH FROM data_lancamento),
  TO_CHAR(data_lancamento, 'YYYY-MM'),
  tipo_atividade_real;

-- Comentários
COMMENT ON VIEW horas_sap_por_empregado_mes IS 'View otimizada com horas apontadas agregadas por empregado e mês';

-- ============================================
-- 7. VACUUM E ANALYZE
-- ============================================

-- Atualiza estatísticas para o otimizador usar os índices
ANALYZE horas_sap;

-- ============================================
-- INSTRUÇÕES DE USO
-- ============================================

-- Para atualizar a view materializada após importar dados:
-- SELECT refresh_horas_sap_contagem();

-- Para verificar tamanho dos índices:
-- SELECT schemaname, tablename, indexname, pg_size_pretty(pg_relation_size(indexrelid::regclass))
-- FROM pg_stat_user_indexes 
-- WHERE tablename = 'horas_sap'
-- ORDER BY pg_relation_size(indexrelid::regclass) DESC;

-- Para verificar uso dos índices:
-- SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
-- FROM pg_stat_user_indexes 
-- WHERE tablename = 'horas_sap'
-- ORDER BY idx_scan DESC;

COMMENT ON TABLE horas_sap IS 'Tabela de horas apontadas SAP - Otimizada com índices para performance';
