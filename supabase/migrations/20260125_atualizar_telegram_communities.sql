-- ============================================
-- MIGRATION: ATUALIZAR TELEGRAM_COMMUNITIES
-- ============================================
-- Garantir que a tabela está correta para cadastro via formulário Flutter
-- Data: 2026-01-25

-- 1. Garantir que a tabela telegram_communities existe com a estrutura correta
CREATE TABLE IF NOT EXISTS telegram_communities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id UUID NOT NULL REFERENCES comunidades(id) ON DELETE CASCADE,
  telegram_chat_id BIGINT NOT NULL, -- ID do supergrupo no Telegram
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(community_id) -- Uma comunidade = um supergrupo (mas um supergrupo pode ter várias comunidades)
);

-- 2. Garantir que os índices existem
CREATE INDEX IF NOT EXISTS idx_telegram_communities_community_id ON telegram_communities(community_id);
CREATE INDEX IF NOT EXISTS idx_telegram_communities_chat_id ON telegram_communities(telegram_chat_id);

-- 3. Remover constraint UNIQUE de telegram_chat_id se existir (para permitir múltiplas comunidades no mesmo grupo)
DO $$
BEGIN
  -- Verificar se a constraint existe e removê-la
  IF EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'telegram_communities_telegram_chat_id_key'
  ) THEN
    ALTER TABLE telegram_communities
    DROP CONSTRAINT telegram_communities_telegram_chat_id_key;
    RAISE NOTICE 'Constraint UNIQUE de telegram_chat_id removida';
  END IF;
END $$;

-- 4. Garantir que updated_at é atualizado automaticamente
CREATE OR REPLACE FUNCTION update_telegram_communities_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_telegram_communities_updated_at_trigger ON telegram_communities;
CREATE TRIGGER update_telegram_communities_updated_at_trigger
  BEFORE UPDATE ON telegram_communities
  FOR EACH ROW
  EXECUTE FUNCTION update_telegram_communities_updated_at();

-- 5. Habilitar RLS se ainda não estiver habilitado
ALTER TABLE telegram_communities ENABLE ROW LEVEL SECURITY;

-- 6. Garantir políticas RLS corretas
DROP POLICY IF EXISTS "Enable read access for all authenticated users" ON telegram_communities;
CREATE POLICY "Enable read access for all authenticated users"
ON telegram_communities FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Enable insert for authenticated users" ON telegram_communities;
CREATE POLICY "Enable insert for authenticated users"
ON telegram_communities FOR INSERT
TO authenticated
WITH CHECK (true); -- Permitir inserção para usuários autenticados (o Flutter valida permissões)

DROP POLICY IF EXISTS "Enable update for authenticated users" ON telegram_communities;
CREATE POLICY "Enable update for authenticated users"
ON telegram_communities FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

DROP POLICY IF EXISTS "Enable delete for authenticated users" ON telegram_communities;
CREATE POLICY "Enable delete for authenticated users"
ON telegram_communities FOR DELETE
TO authenticated
USING (true);

-- 7. Comentários
COMMENT ON TABLE telegram_communities IS 'Mapeia comunidades (divisão+segmento) para supergrupos Telegram. Cadastrado via formulário de divisões no Flutter.';
COMMENT ON COLUMN telegram_communities.community_id IS 'ID da comunidade (comunidades.id) - UNIQUE, uma comunidade tem apenas um supergrupo';
COMMENT ON COLUMN telegram_communities.telegram_chat_id IS 'ID do supergrupo no Telegram (BIGINT negativo, ex: -1001234567890). Múltiplas comunidades podem compartilhar o mesmo supergrupo.';
