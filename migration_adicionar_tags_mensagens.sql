-- ============================================
-- MIGRATION: ADICIONAR TAGS NOTA/ORDEM EM MENSAGENS
-- ============================================
-- Data: 2026-01-27
-- Descrição: Adiciona campos para vincular mensagens a Notas ou Ordens
-- Compatibilidade: 100% com dados existentes (mensagens antigas = GERAL)
-- ============================================

-- ============================================
-- 1. ADICIONAR COLUNAS
-- ============================================

-- 1.1. Coluna ref_type (tipo de referência)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'mensagens' 
        AND column_name = 'ref_type'
    ) THEN
        ALTER TABLE public.mensagens
        ADD COLUMN ref_type TEXT DEFAULT 'GERAL'
        CHECK (ref_type IN ('GERAL', 'NOTA', 'ORDEM'));
        
        RAISE NOTICE 'Coluna ref_type adicionada com sucesso';
    ELSE
        RAISE NOTICE 'Coluna ref_type já existe';
    END IF;
END $$;

-- 1.2. Coluna ref_id (ID da nota ou ordem)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'mensagens' 
        AND column_name = 'ref_id'
    ) THEN
        ALTER TABLE public.mensagens
        ADD COLUMN ref_id UUID NULL;
        
        RAISE NOTICE 'Coluna ref_id adicionada com sucesso';
    ELSE
        RAISE NOTICE 'Coluna ref_id já existe';
    END IF;
END $$;

-- 1.3. Coluna ref_label (label para exibição)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'mensagens' 
        AND column_name = 'ref_label'
    ) THEN
        ALTER TABLE public.mensagens
        ADD COLUMN ref_label TEXT NULL;
        
        RAISE NOTICE 'Coluna ref_label adicionada com sucesso';
    ELSE
        RAISE NOTICE 'Coluna ref_label já existe';
    END IF;
END $$;

-- ============================================
-- 2. GARANTIR CONSISTÊNCIA DE DADOS EXISTENTES
-- ============================================

-- 2.1. Atualizar mensagens existentes sem ref_type para 'GERAL'
UPDATE public.mensagens
SET ref_type = 'GERAL'
WHERE ref_type IS NULL;

-- 2.2. Garantir que mensagens com ref_type = 'GERAL' tenham ref_id = NULL
UPDATE public.mensagens
SET ref_id = NULL, ref_label = NULL
WHERE ref_type = 'GERAL' AND (ref_id IS NOT NULL OR ref_label IS NOT NULL);

-- 2.3. Garantir que mensagens com ref_type != 'GERAL' tenham ref_id preenchido
-- (Aviso: isso pode deixar algumas mensagens inconsistentes, mas é melhor do que quebrar)
UPDATE public.mensagens
SET ref_type = 'GERAL', ref_id = NULL, ref_label = NULL
WHERE ref_type IN ('NOTA', 'ORDEM') AND ref_id IS NULL;

-- ============================================
-- 3. CRIAR ÍNDICES PARA PERFORMANCE
-- ============================================

-- 3.1. Índice para filtros por tipo de referência
CREATE INDEX IF NOT EXISTS idx_mensagens_ref_type 
  ON public.mensagens(ref_type) 
  WHERE ref_type != 'GERAL';

-- 3.2. Índice composto para filtros por tipo + id
CREATE INDEX IF NOT EXISTS idx_mensagens_ref_type_id 
  ON public.mensagens(ref_type, ref_id) 
  WHERE ref_type != 'GERAL' AND ref_id IS NOT NULL;

-- 3.3. Índice para buscar mensagens de uma nota específica
CREATE INDEX IF NOT EXISTS idx_mensagens_ref_id_nota 
  ON public.mensagens(ref_id) 
  WHERE ref_type = 'NOTA' AND ref_id IS NOT NULL;

-- 3.4. Índice para buscar mensagens de uma ordem específica
CREATE INDEX IF NOT EXISTS idx_mensagens_ref_id_ordem 
  ON public.mensagens(ref_id) 
  WHERE ref_type = 'ORDEM' AND ref_id IS NOT NULL;

-- 3.5. Índice composto para buscar mensagens de uma tarefa por tag
CREATE INDEX IF NOT EXISTS idx_mensagens_grupo_ref_type 
  ON public.mensagens(grupo_id, ref_type, ref_id) 
  WHERE ref_type != 'GERAL' AND ref_id IS NOT NULL;

-- ============================================
-- 4. ADICIONAR COMENTÁRIOS (DOCUMENTAÇÃO)
-- ============================================

COMMENT ON COLUMN public.mensagens.ref_type IS 
  'Tipo de referência: GERAL (padrão, mensagem geral), NOTA (vinculada a nota_sap), ORDEM (vinculada a ordem). Default: GERAL';

COMMENT ON COLUMN public.mensagens.ref_id IS 
  'ID da nota_sap (se ref_type=NOTA) ou ordem (se ref_type=ORDEM). NULL se ref_type=GERAL. UUID.';

COMMENT ON COLUMN public.mensagens.ref_label IS 
  'Label para exibição (ex: "NOTA 12345", "ORDEM 67890"). Opcional, pode ser preenchido automaticamente. TEXT.';

-- ============================================
-- 5. VERIFICAÇÃO PÓS-MIGRAÇÃO
-- ============================================

-- 5.1. Verificar se colunas foram criadas
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'mensagens'
    AND column_name IN ('ref_type', 'ref_id', 'ref_label')
ORDER BY column_name;

-- 5.2. Verificar contagem de mensagens por tipo
SELECT 
    COALESCE(ref_type, 'NULL') AS ref_type,
    COUNT(*) AS quantidade,
    COUNT(CASE WHEN ref_id IS NOT NULL THEN 1 END) AS com_ref_id,
    COUNT(CASE WHEN ref_label IS NOT NULL THEN 1 END) AS com_ref_label
FROM public.mensagens
GROUP BY ref_type
ORDER BY ref_type;

-- 5.3. Verificar índices criados
SELECT 
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
    AND tablename = 'mensagens'
    AND indexname LIKE '%ref%'
ORDER BY indexname;

-- ============================================
-- 6. ROLLBACK (se necessário)
-- ============================================
-- Execute apenas se precisar reverter a migração:

/*
-- Remover índices
DROP INDEX IF EXISTS public.idx_mensagens_ref_type;
DROP INDEX IF EXISTS public.idx_mensagens_ref_type_id;
DROP INDEX IF EXISTS public.idx_mensagens_ref_id_nota;
DROP INDEX IF EXISTS public.idx_mensagens_ref_id_ordem;
DROP INDEX IF EXISTS public.idx_mensagens_grupo_ref_type;

-- Remover colunas
ALTER TABLE public.mensagens DROP COLUMN IF EXISTS ref_type;
ALTER TABLE public.mensagens DROP COLUMN IF EXISTS ref_id;
ALTER TABLE public.mensagens DROP COLUMN IF EXISTS ref_label;
*/
