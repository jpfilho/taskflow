-- ============================================
-- MIGRATION: CORRIGIR GRUPOS_CHAT E COMUNIDADES
-- ============================================
-- Corrige grupos_chat que estão vinculados a comunidades incorretas
-- (não correspondem à regional+divisão+segmento da tarefa)
-- Data: 2026-01-25

-- 1. Primeiro, garantir que todas as comunidades têm regional_id
-- (Se a migration anterior não foi executada, isso vai falhar - execute primeiro)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM comunidades WHERE regional_id IS NULL
  ) THEN
    RAISE EXCEPTION 'Existem comunidades sem regional_id. Execute primeiro a migration 20260125_adicionar_regional_comunidades.sql';
  END IF;
END $$;

-- 2. Criar comunidades corretas para tarefas que não têm
-- (baseado na regional+divisão+segmento da tarefa)
INSERT INTO comunidades (regional_id, regional_nome, divisao_id, divisao_nome, segmento_id, segmento_nome)
SELECT DISTINCT
    t.regional_id,
    COALESCE(r.regional, 'Regional Desconhecida'),
    t.divisao_id,
    COALESCE(d.divisao, 'Divisão Desconhecida'),
    t.segmento_id,
    COALESCE(s.segmento, 'Segmento Desconhecido')
FROM tasks t
LEFT JOIN regionais r ON r.id = t.regional_id
LEFT JOIN divisoes d ON d.id = t.divisao_id
LEFT JOIN segmentos s ON s.id = t.segmento_id
WHERE t.regional_id IS NOT NULL
    AND t.divisao_id IS NOT NULL
    AND t.segmento_id IS NOT NULL
    AND NOT EXISTS (
        SELECT 1 FROM comunidades c
        WHERE c.regional_id = t.regional_id
            AND c.divisao_id = t.divisao_id
            AND c.segmento_id = t.segmento_id
    )
ON CONFLICT (regional_id, divisao_id, segmento_id) DO NOTHING;

-- 3. Corrigir grupos_chat vinculados a comunidades incorretas
UPDATE grupos_chat gc
SET comunidade_id = c_correta.id,
    updated_at = NOW()
FROM tasks t
JOIN comunidades c_correta ON
    c_correta.regional_id = t.regional_id
    AND c_correta.divisao_id = t.divisao_id
    AND c_correta.segmento_id = t.segmento_id
WHERE gc.tarefa_id = t.id
    AND t.regional_id IS NOT NULL
    AND t.divisao_id IS NOT NULL
    AND t.segmento_id IS NOT NULL
    AND gc.comunidade_id != c_correta.id;

-- 4. Log de correções
DO $$
DECLARE
    total_corrigidos INTEGER;
BEGIN
    SELECT COUNT(*) INTO total_corrigidos
    FROM grupos_chat gc
    JOIN tasks t ON t.id = gc.tarefa_id
    JOIN comunidades c ON c.id = gc.comunidade_id
    WHERE t.regional_id IS NOT NULL
        AND t.divisao_id IS NOT NULL
        AND t.segmento_id IS NOT NULL
        AND c.regional_id = t.regional_id
        AND c.divisao_id = t.divisao_id
        AND c.segmento_id = t.segmento_id;
    
    RAISE NOTICE 'Total de grupos_chat corrigidos: %', total_corrigidos;
END $$;

-- 5. Comentário
COMMENT ON FUNCTION update_updated_at_column() IS 'Atualiza updated_at automaticamente';
