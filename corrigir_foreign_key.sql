-- ============================================
-- CORRIGIR FOREIGN KEY DA TELEGRAM_IDENTITIES
-- ============================================

-- 1. Remover foreign key antiga
ALTER TABLE telegram_identities 
DROP CONSTRAINT IF EXISTS telegram_identities_user_id_fkey;

-- 2. Adicionar foreign key para executores
ALTER TABLE telegram_identities 
ADD CONSTRAINT telegram_identities_user_id_fkey 
FOREIGN KEY (user_id) REFERENCES executores(id) ON DELETE CASCADE;

-- 3. Verificar estrutura
\d telegram_identities

-- 4. Inserir vinculação novamente
INSERT INTO telegram_identities (
    user_id,
    telegram_user_id,
    telegram_username,
    telegram_first_name,
    linked_at
)
SELECT 
    id as user_id,
    7807721517 as telegram_user_id,
    'jose_user' as telegram_username,
    'JOSE' as telegram_first_name,
    NOW() as linked_at
FROM executores 
WHERE matricula = '264259'
ON CONFLICT (telegram_user_id) DO UPDATE SET
    user_id = EXCLUDED.user_id,
    linked_at = NOW();

-- 5. Verificar vinculação
SELECT 
    ti.telegram_user_id,
    ti.telegram_first_name,
    e.matricula,
    e.nome,
    e.telefone
FROM telegram_identities ti
JOIN executores e ON e.id = ti.user_id
WHERE ti.telegram_user_id = 7807721517;
