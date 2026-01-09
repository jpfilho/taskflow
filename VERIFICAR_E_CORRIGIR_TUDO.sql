-- ============================================
-- VERIFICAÇÃO E CORREÇÃO COMPLETA
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- Este script verifica e corrige todos os problemas conhecidos

-- ============================================
-- 1. VERIFICAR ESTRUTURA DA TABELA DIVISOES
-- ============================================
DO $$
BEGIN
    RAISE NOTICE '=== VERIFICANDO TABELA DIVISOES ===';
    
    -- Verificar se segmento_id existe (não deveria)
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'divisoes' 
        AND column_name = 'segmento_id'
    ) THEN
        RAISE NOTICE '⚠️ Coluna segmento_id ainda existe na tabela divisoes.';
        RAISE NOTICE '   Removendo coluna segmento_id...';
        ALTER TABLE divisoes DROP COLUMN IF EXISTS segmento_id;
        RAISE NOTICE '✅ Coluna segmento_id removida.';
    ELSE
        RAISE NOTICE '✅ Coluna segmento_id não existe (correto).';
    END IF;
END
$$;

-- ============================================
-- 2. VERIFICAR E ADICIONAR CONSTRAINT UNIQUE
-- ============================================
DO $$
BEGIN
    RAISE NOTICE '=== VERIFICANDO CONSTRAINT UNIQUE ===';
    
    -- Verificar se a constraint já existe
    IF EXISTS (
        SELECT 1 
        FROM pg_constraint 
        WHERE conname = 'divisoes_divisao_regional_id_key' 
        AND conrelid = 'divisoes'::regclass
    ) THEN
        RAISE NOTICE '✅ Constraint divisoes_divisao_regional_id_key já existe.';
    ELSE
        -- Verificar se há duplicatas
        IF EXISTS (
            SELECT 1 
            FROM (
                SELECT divisao, regional_id, COUNT(*) 
                FROM divisoes 
                GROUP BY divisao, regional_id 
                HAVING COUNT(*) > 1
            ) duplicatas
        ) THEN
            RAISE NOTICE '⚠️ Existem divisões duplicadas. Execute:';
            RAISE NOTICE '   SELECT divisao, regional_id, COUNT(*) FROM divisoes GROUP BY divisao, regional_id HAVING COUNT(*) > 1;';
        ELSE
            ALTER TABLE divisoes 
            ADD CONSTRAINT divisoes_divisao_regional_id_key UNIQUE (divisao, regional_id);
            RAISE NOTICE '✅ Constraint UNIQUE composta adicionada.';
        END IF;
    END IF;
END
$$;

-- ============================================
-- 3. GARANTIR TABELA DIVISOES_SEGMENTOS
-- ============================================
DO $$
BEGIN
    RAISE NOTICE '=== VERIFICANDO TABELA DIVISOES_SEGMENTOS ===';
    
    IF EXISTS (
        SELECT 1 
        FROM information_schema.tables 
        WHERE table_name = 'divisoes_segmentos'
    ) THEN
        RAISE NOTICE '✅ Tabela divisoes_segmentos existe.';
    ELSE
        RAISE NOTICE '⚠️ Tabela divisoes_segmentos não existe. Criando...';
        CREATE TABLE divisoes_segmentos (
            divisao_id UUID NOT NULL REFERENCES divisoes(id) ON DELETE CASCADE,
            segmento_id UUID NOT NULL REFERENCES segmentos(id) ON DELETE CASCADE,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            PRIMARY KEY (divisao_id, segmento_id)
        );
        
        CREATE INDEX IF NOT EXISTS idx_divisoes_segmentos_divisao_id ON divisoes_segmentos(divisao_id);
        CREATE INDEX IF NOT EXISTS idx_divisoes_segmentos_segmento_id ON divisoes_segmentos(segmento_id);
        
        ALTER TABLE divisoes_segmentos ENABLE ROW LEVEL SECURITY;
        
        DROP POLICY IF EXISTS "Permitir todas as operações em divisoes_segmentos" ON divisoes_segmentos;
        CREATE POLICY "Permitir todas as operações em divisoes_segmentos" ON divisoes_segmentos
          FOR ALL USING (true) WITH CHECK (true);
        
        RAISE NOTICE '✅ Tabela divisoes_segmentos criada.';
    END IF;
END
$$;

-- ============================================
-- 4. CORRIGIR TIPOS DE ANEXOS
-- ============================================
DO $$
BEGIN
    RAISE NOTICE '=== VERIFICANDO TIPOS DE ANEXOS ===';
    
    -- Verificar constraint atual
    IF EXISTS (
        SELECT 1 
        FROM pg_constraint 
        WHERE conname = 'anexos_tipo_arquivo_check'
    ) THEN
        -- Verificar se inclui 'audio' e 'outro'
        IF EXISTS (
            SELECT 1 
            FROM pg_constraint c
            JOIN pg_get_constraintdef(c.oid) AS def ON true
            WHERE c.conname = 'anexos_tipo_arquivo_check'
            AND def LIKE '%audio%'
            AND def LIKE '%outro%'
        ) THEN
            RAISE NOTICE '✅ Constraint de tipos de anexos já inclui audio e outro.';
        ELSE
            RAISE NOTICE '⚠️ Atualizando constraint de tipos de anexos...';
            ALTER TABLE anexos DROP CONSTRAINT IF EXISTS anexos_tipo_arquivo_check;
            ALTER TABLE anexos ADD CONSTRAINT anexos_tipo_arquivo_check
                CHECK (tipo_arquivo IN ('imagem', 'video', 'documento', 'audio', 'outro'));
            RAISE NOTICE '✅ Constraint atualizada.';
        END IF;
    ELSE
        RAISE NOTICE '⚠️ Constraint não existe. Criando...';
        ALTER TABLE anexos ADD CONSTRAINT anexos_tipo_arquivo_check
            CHECK (tipo_arquivo IN ('imagem', 'video', 'documento', 'audio', 'outro'));
        RAISE NOTICE '✅ Constraint criada.';
    END IF;
END
$$;

-- ============================================
-- 5. VERIFICAR RLS POLICIES
-- ============================================
DO $$
BEGIN
    RAISE NOTICE '=== VERIFICANDO RLS POLICIES ===';
    
    -- Verificar RLS em divisoes
    IF EXISTS (
        SELECT 1 
        FROM pg_policies 
        WHERE tablename = 'divisoes'
    ) THEN
        RAISE NOTICE '✅ RLS policies existem para divisoes.';
    ELSE
        RAISE NOTICE '⚠️ Criando RLS policies para divisoes...';
        ALTER TABLE divisoes ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS "Permitir todas as operações em divisoes" ON divisoes;
        CREATE POLICY "Permitir todas as operações em divisoes" ON divisoes
          FOR ALL USING (true) WITH CHECK (true);
        RAISE NOTICE '✅ RLS policies criadas.';
    END IF;
END
$$;

-- ============================================
-- 6. RESUMO FINAL
-- ============================================
SELECT 
    'divisoes' as tabela,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'divisoes'
ORDER BY ordinal_position;

SELECT 
    conname as constraint_name,
    contype as constraint_type
FROM pg_constraint
WHERE conrelid = 'divisoes'::regclass
AND conname LIKE '%divisao%'
ORDER BY conname;
