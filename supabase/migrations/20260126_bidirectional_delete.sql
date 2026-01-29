-- ============================================
-- MIGRATION: DELETE BIDIRECIONAL FLUTTER <-> TELEGRAM
-- ============================================
-- Adiciona suporte completo para exclusão bidirecional de mensagens
-- com rastreamento de origem e remoção de arquivos do Storage

-- 1. ADICIONAR CAMPOS NA TABELA MENSAGENS
-- ============================================

-- Adicionar deleted_at (soft delete)
ALTER TABLE public.mensagens 
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS deleted_by TEXT NULL CHECK (deleted_by IN ('flutter', 'telegram') OR deleted_by ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'),
  ADD COLUMN IF NOT EXISTS storage_path TEXT NULL;

COMMENT ON COLUMN public.mensagens.deleted_at IS 'Timestamp de quando a mensagem foi deletada (soft delete)';
COMMENT ON COLUMN public.mensagens.deleted_by IS 'Origem da deleção: flutter, telegram, ou UUID do usuário que deletou';
COMMENT ON COLUMN public.mensagens.storage_path IS 'Caminho do arquivo no Supabase Storage (ex: task_id/timestamp-file.jpg)';

-- Índices para queries otimizadas
CREATE INDEX IF NOT EXISTS idx_mensagens_deleted_at ON public.mensagens(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_mensagens_storage_path ON public.mensagens(storage_path) WHERE storage_path IS NOT NULL;

-- 2. MELHORAR TABELA TELEGRAM_DELIVERY_LOGS
-- ============================================

-- Adicionar status 'deleted' se não existir
-- (assumindo que o CHECK já permite, mas vamos garantir)
DO $$
BEGIN
  -- Verificar se o constraint existe e permite 'deleted'
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'telegram_delivery_logs_status_check'
  ) THEN
    -- Remover constraint antigo se existir
    ALTER TABLE public.telegram_delivery_logs 
    DROP CONSTRAINT IF EXISTS telegram_delivery_logs_status_check;
  END IF;
END $$;

-- Recriar constraint permitindo 'deleted'
ALTER TABLE public.telegram_delivery_logs 
  DROP CONSTRAINT IF EXISTS telegram_delivery_logs_status_check,
  ADD CONSTRAINT telegram_delivery_logs_status_check 
  CHECK (status IN ('pending', 'sent', 'failed', 'retry', 'deleted'));

-- Adicionar índices otimizados para lookup rápido
CREATE INDEX IF NOT EXISTS idx_telegram_delivery_logs_platform_chat_message 
  ON public.telegram_delivery_logs(telegram_chat_id, telegram_message_id) 
  WHERE telegram_chat_id IS NOT NULL AND telegram_message_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_telegram_delivery_logs_message_platform 
  ON public.telegram_delivery_logs(mensagem_id, status) 
  WHERE status = 'sent';

-- Remover duplicatas antes de criar índice único
-- Manter apenas o registro mais recente para cada (telegram_chat_id, telegram_message_id) com status='sent'
DO $$
DECLARE
  duplicate_count INTEGER;
BEGIN
  -- Contar duplicatas
  SELECT COUNT(*) INTO duplicate_count
  FROM (
    SELECT telegram_chat_id, telegram_message_id
    FROM public.telegram_delivery_logs
    WHERE telegram_chat_id IS NOT NULL 
      AND telegram_message_id IS NOT NULL 
      AND status = 'sent'
    GROUP BY telegram_chat_id, telegram_message_id
    HAVING COUNT(*) > 1
  ) duplicates;
  
  IF duplicate_count > 0 THEN
    RAISE NOTICE 'Encontradas % duplicatas. Removendo duplicatas antigas...', duplicate_count;
    
    -- Deletar duplicatas, mantendo apenas o mais recente (maior id ou created_at)
    DELETE FROM public.telegram_delivery_logs
    WHERE id IN (
      SELECT id
      FROM (
        SELECT id,
               ROW_NUMBER() OVER (
                 PARTITION BY telegram_chat_id, telegram_message_id 
                 ORDER BY created_at DESC, id DESC
               ) as rn
        FROM public.telegram_delivery_logs
        WHERE telegram_chat_id IS NOT NULL 
          AND telegram_message_id IS NOT NULL 
          AND status = 'sent'
      ) ranked
      WHERE rn > 1
    );
    
    RAISE NOTICE 'Duplicatas removidas.';
  END IF;
END $$;

-- Agora criar índice único (após remover duplicatas)
CREATE UNIQUE INDEX IF NOT EXISTS idx_telegram_delivery_logs_unique_lookup
  ON public.telegram_delivery_logs(telegram_chat_id, telegram_message_id)
  WHERE telegram_chat_id IS NOT NULL AND telegram_message_id IS NOT NULL AND status = 'sent';

-- 3. FUNÇÃO PARA EXTRAIR STORAGE_PATH DE ARQUIVO_URL
-- ============================================

CREATE OR REPLACE FUNCTION extract_storage_path_from_url(p_url TEXT)
RETURNS TEXT AS $$
DECLARE
  v_path TEXT;
BEGIN
  IF p_url IS NULL OR p_url = '' THEN
    RETURN NULL;
  END IF;
  
  -- Extrair caminho do storage de URLs do Supabase
  -- Formato esperado: .../storage/v1/object/sign/anexos-tarefas/task_id/file.jpg?...
  -- ou: .../anexos-tarefas/task_id/file.jpg
  v_path := regexp_replace(p_url, '^.*/anexos-tarefas/([^?]+).*$', '\1', 'g');
  
  -- Se não encontrou, tentar outro padrão
  IF v_path = p_url THEN
    v_path := regexp_replace(p_url, '^.*storage/v1/object/sign/anexos-tarefas/([^?]+).*$', '\1', 'g');
  END IF;
  
  -- Se ainda não encontrou, retornar NULL
  IF v_path = p_url THEN
    RETURN NULL;
  END IF;
  
  RETURN v_path;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION extract_storage_path_from_url IS 'Extrai o caminho do storage (bucket/path) de uma URL do Supabase';

-- 4. TRIGGER PARA PREENCHER STORAGE_PATH AUTOMATICAMENTE
-- ============================================

CREATE OR REPLACE FUNCTION auto_fill_storage_path()
RETURNS TRIGGER AS $$
BEGIN
  -- Se storage_path não está preenchido mas arquivo_url está, tentar extrair
  IF NEW.storage_path IS NULL AND NEW.arquivo_url IS NOT NULL THEN
    NEW.storage_path := extract_storage_path_from_url(NEW.arquivo_url);
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Criar trigger se não existir
DROP TRIGGER IF EXISTS trigger_auto_fill_storage_path ON public.mensagens;
CREATE TRIGGER trigger_auto_fill_storage_path
  BEFORE INSERT OR UPDATE ON public.mensagens
  FOR EACH ROW
  EXECUTE FUNCTION auto_fill_storage_path();

-- 5. ATUALIZAR MENSAGENS EXISTENTES COM STORAGE_PATH
-- ============================================

-- Preencher storage_path para mensagens existentes que têm arquivo_url
UPDATE public.mensagens
SET storage_path = extract_storage_path_from_url(arquivo_url)
WHERE storage_path IS NULL 
  AND arquivo_url IS NOT NULL 
  AND arquivo_url LIKE '%anexos-tarefas%';

-- 6. COMENTÁRIOS E DOCUMENTAÇÃO
-- ============================================

COMMENT ON TABLE public.telegram_delivery_logs IS 
'Logs de entrega de mensagens para Telegram. Permite mapear mensagens entre Flutter e Telegram para sincronização bidirecional de exclusões.';

COMMENT ON INDEX idx_telegram_delivery_logs_platform_chat_message IS 
'Índice otimizado para lookup rápido: encontrar mensagem_id canônico a partir de telegram_chat_id + telegram_message_id';

COMMENT ON INDEX idx_telegram_delivery_logs_message_platform IS 
'Índice otimizado para encontrar deliveries Telegram de uma mensagem canônica';

-- Comentar índice apenas se foi criado
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE indexname = 'idx_telegram_delivery_logs_unique_lookup'
  ) THEN
    COMMENT ON INDEX idx_telegram_delivery_logs_unique_lookup IS 
    'Índice único para garantir que cada mensagem Telegram mapeia para apenas uma mensagem canônica (quando status=sent)';
  END IF;
END $$;
