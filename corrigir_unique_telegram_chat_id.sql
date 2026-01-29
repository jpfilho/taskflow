-- ============================================
-- CORRIGIR: REMOVER UNIQUE DE telegram_chat_id
-- ============================================
-- Permite que múltiplas comunidades compartilhem o mesmo supergrupo

-- Remover constraint UNIQUE de telegram_chat_id
ALTER TABLE telegram_communities
DROP CONSTRAINT IF EXISTS telegram_communities_telegram_chat_id_key;

-- Adicionar índice (sem UNIQUE) para performance
CREATE INDEX IF NOT EXISTS idx_telegram_communities_chat_id ON telegram_communities(telegram_chat_id);

-- Verificar resultado
SELECT 
    constraint_name,
    constraint_type
FROM information_schema.table_constraints
WHERE table_name = 'telegram_communities'
  AND constraint_type = 'UNIQUE';
