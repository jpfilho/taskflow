-- ============================================
-- REMOVER CONSTRAINT UNIQUE DE telegram_chat_id
-- ============================================
-- Permite que múltiplas comunidades compartilhem o mesmo supergrupo Telegram

-- Remover constraint UNIQUE (com CASCADE para evitar erros de dependências)
ALTER TABLE telegram_communities
DROP CONSTRAINT IF EXISTS telegram_communities_telegram_chat_id_key CASCADE;

-- Adicionar índice (sem UNIQUE) para performance
CREATE INDEX IF NOT EXISTS idx_telegram_communities_chat_id ON telegram_communities(telegram_chat_id);

-- Verificar se foi removida
SELECT 
    constraint_name,
    constraint_type
FROM information_schema.table_constraints
WHERE table_name = 'telegram_communities'
  AND constraint_type = 'UNIQUE';

-- Deve mostrar apenas: telegram_communities_community_id_key
