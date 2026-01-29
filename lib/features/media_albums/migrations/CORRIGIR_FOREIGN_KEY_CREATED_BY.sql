-- ============================================
-- CORRIGIR FOREIGN KEY created_by
-- ============================================
-- Execute este script se a coluna created_by referencia auth.users
-- mas a aplicação usa a tabela usuarios
-- ============================================

-- 1. Remover a foreign key antiga (se existir)
ALTER TABLE media_images 
DROP CONSTRAINT IF EXISTS media_images_created_by_fkey;

-- 2. Verificar se a tabela usuarios existe e tem a coluna id como UUID
-- Se não existir, você precisará ajustar conforme sua estrutura
-- Exemplo de verificação:
-- SELECT column_name, data_type FROM information_schema.columns 
-- WHERE table_schema = 'public' AND table_name = 'usuarios' AND column_name = 'id';

-- 3. Adicionar nova foreign key para a tabela usuarios
-- NOTA: Ajuste o tipo de dados se a coluna id da tabela usuarios não for UUID
-- Se for TEXT ou VARCHAR, use: created_by::text = usuarios.id::text na constraint
ALTER TABLE media_images
ADD CONSTRAINT media_images_created_by_fkey
FOREIGN KEY (created_by) 
REFERENCES usuarios(id) 
ON DELETE CASCADE;

-- ============================================
-- VERIFICAR FOREIGN KEY
-- ============================================
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
  AND kcu.column_name = 'created_by';

-- Deve mostrar que created_by referencia usuarios(id)
