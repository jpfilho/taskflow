-- ============================================
-- REMOVER FOREIGN KEY DE segment_id
-- ============================================
-- Execute este script para remover a foreign key de segment_id
-- Isso permite usar IDs da tabela segmentos (sistema) ou segments (módulo)
-- ============================================

-- Remover a foreign key antiga
ALTER TABLE media_images 
DROP CONSTRAINT IF EXISTS media_images_segment_id_fkey;

-- Verificar se foi removida
SELECT
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_name = 'media_images'
  AND kcu.column_name = 'segment_id';

-- Não deve retornar nenhuma linha (foreign key removida)

-- ============================================
-- NOTA IMPORTANTE
-- ============================================
-- Após remover a foreign key, o campo segment_id pode conter:
-- 1. IDs da tabela segments (módulo de mídia)
-- 2. IDs da tabela segmentos (sistema)
-- 3. NULL (se nenhum segmento foi selecionado)
--
-- A aplicação deve validar a existência do segmento antes de usar,
-- mas não há mais restrição de integridade referencial no banco.
-- ============================================
