#!/bin/bash
# ============================================
# EXECUTAR ÍNDICES VIA SSH NO SERVIDOR
# ============================================

echo "🚀 Criando índices otimizados para horas_sap..."

# Conectar ao PostgreSQL do Supabase e executar os índices
docker exec -i supabase-db psql -U postgres -d postgres <<'EOF'

-- 1. ÍNDICES BÁSICOS
CREATE INDEX IF NOT EXISTS idx_horas_sap_data_lancamento ON horas_sap(data_lancamento DESC);
CREATE INDEX IF NOT EXISTS idx_horas_sap_numero_pessoa ON horas_sap(numero_pessoa);
CREATE INDEX IF NOT EXISTS idx_horas_sap_centro_trabalho ON horas_sap(centro_trabalho_real);
CREATE INDEX IF NOT EXISTS idx_horas_sap_nome_empregado ON horas_sap(nome_empregado);
CREATE INDEX IF NOT EXISTS idx_horas_sap_ordem ON horas_sap(ordem);
CREATE INDEX IF NOT EXISTS idx_horas_sap_status_sistema ON horas_sap(status_sistema);
CREATE INDEX IF NOT EXISTS idx_horas_sap_tipo_atividade_real ON horas_sap(tipo_atividade_real);

-- 2. ÍNDICES COMPOSTOS
CREATE INDEX IF NOT EXISTS idx_horas_sap_data_centro ON horas_sap(data_lancamento DESC, centro_trabalho_real);
CREATE INDEX IF NOT EXISTS idx_horas_sap_numero_data ON horas_sap(numero_pessoa, data_lancamento DESC);

-- 3. EXTENSÃO
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 4. ÍNDICES GIN
CREATE INDEX IF NOT EXISTS idx_horas_sap_centro_trgm ON horas_sap USING gin(centro_trabalho_real gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_horas_sap_nome_trgm ON horas_sap USING gin(nome_empregado gin_trgm_ops);

-- 5. ATUALIZAR ESTATÍSTICAS
ANALYZE horas_sap;

-- Verificar índices criados
SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'horas_sap' ORDER BY indexname;

EOF

echo "✅ Índices criados com sucesso!"
