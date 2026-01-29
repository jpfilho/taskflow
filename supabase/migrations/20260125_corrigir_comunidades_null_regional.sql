-- ============================================
-- MIGRATION: CORRIGIR COMUNIDADES COM REGIONAL_ID NULL
-- ============================================
-- Preenche regional_id NULL nas comunidades e corrige grupos_chat
-- Data: 2026-01-25

-- 1. Preencher regional_id NULL nas comunidades baseado na divisão
UPDATE comunidades c
SET regional_id = d.regional_id,
    regional_nome = r.regional
FROM divisoes d
LEFT JOIN regionais r ON r.id = d.regional_id
WHERE c.divisao_id = d.id
    AND c.regional_id IS NULL
    AND d.regional_id IS NOT NULL;

-- 2. Se ainda houver comunidades sem regional_id, tentar buscar da tarefa
-- (para comunidades que foram criadas mas não têm divisão associada)
UPDATE comunidades c
SET regional_id = t.regional_id,
    regional_nome = r.regional
FROM grupos_chat gc
JOIN tasks t ON t.id = gc.tarefa_id
LEFT JOIN regionais r ON r.id = t.regional_id
WHERE gc.comunidade_id = c.id
    AND c.regional_id IS NULL
    AND t.regional_id IS NOT NULL;

-- 3. Criar comunidades corretas para tarefas que não têm
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

-- 4. Corrigir grupos_chat vinculados a comunidades incorretas
-- (atualizar para usar a comunidade correta baseada na regional+divisão+segmento da tarefa)
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

-- 5. Log de correções
DO $$
DECLARE
    comunidades_corrigidas INTEGER;
    grupos_corrigidos INTEGER;
BEGIN
    SELECT COUNT(*) INTO comunidades_corrigidas
    FROM comunidades
    WHERE regional_id IS NOT NULL;
    
    SELECT COUNT(*) INTO grupos_corrigidos
    FROM grupos_chat gc
    JOIN tasks t ON t.id = gc.tarefa_id
    JOIN comunidades c ON c.id = gc.comunidade_id
    WHERE t.regional_id IS NOT NULL
        AND t.divisao_id IS NOT NULL
        AND t.segmento_id IS NOT NULL
        AND c.regional_id = t.regional_id
        AND c.divisao_id = t.divisao_id
        AND c.segmento_id = t.segmento_id;
    
    RAISE NOTICE 'Total de comunidades com regional_id preenchido: %', comunidades_corrigidas;
    RAISE NOTICE 'Total de grupos_chat corrigidos: %', grupos_corrigidos;
END $$;
