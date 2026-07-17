-- Migration para adicionar a coluna de rastreamento de "executado" nas tags
-- Execute este script no SQL Editor do Supabase do seu projeto.

ALTER TABLE mensagens_chat ADD COLUMN IF NOT EXISTS ref_executado BOOLEAN;

-- Opcionalmente, pode ser útil adicionar um comentário para descrever a coluna:
COMMENT ON COLUMN mensagens_chat.ref_executado IS 'Indica se a mensagem marca a Nota ou Ordem vinculada como Executada (true/false). Null caso não se aplique.';
