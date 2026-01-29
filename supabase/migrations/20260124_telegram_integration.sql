-- =========================================
-- INTEGRAÇÃO TELEGRAM - TASKFLOW
-- =========================================
-- Criado em: 2026-01-24
-- Autor: Sistema TaskFlow
-- Descrição: Estrutura para integração bidirecional com Telegram

-- =========================================
-- 1. TABELA DE IDENTIDADES TELEGRAM
-- =========================================
-- Mapeia usuários Supabase com contas Telegram
CREATE TABLE IF NOT EXISTS public.telegram_identities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  telegram_user_id BIGINT NOT NULL UNIQUE, -- ID do usuário no Telegram
  telegram_username TEXT, -- @username no Telegram (opcional)
  telegram_first_name TEXT,
  telegram_last_name TEXT,
  last_chat_id BIGINT, -- Último chat_id usado em DM (para roteamento)
  linked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_active_at TIMESTAMPTZ DEFAULT now(),
  metadata JSONB DEFAULT '{}', -- Dados extras do Telegram
  
  CONSTRAINT telegram_identities_user_id_unique UNIQUE(user_id),
  CONSTRAINT telegram_identities_telegram_user_id_check CHECK (telegram_user_id > 0)
);

-- Índices para performance
CREATE INDEX idx_telegram_identities_user_id ON public.telegram_identities(user_id);
CREATE INDEX idx_telegram_identities_telegram_user_id ON public.telegram_identities(telegram_user_id);
CREATE INDEX idx_telegram_identities_last_active ON public.telegram_identities(last_active_at DESC);

COMMENT ON TABLE public.telegram_identities IS 'Mapeamento entre usuários Supabase e contas Telegram';
COMMENT ON COLUMN public.telegram_identities.telegram_user_id IS 'ID numérico do usuário no Telegram (único)';
COMMENT ON COLUMN public.telegram_identities.last_chat_id IS 'Último chat_id para DM (usado para envio de mensagens privadas)';

-- =========================================
-- 2. TABELA DE ASSINATURAS TELEGRAM
-- =========================================
-- Define quais threads (comunidades/tarefas) estão conectados ao Telegram
CREATE TABLE IF NOT EXISTS public.telegram_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_type TEXT NOT NULL CHECK (thread_type IN ('COMMUNITY', 'TASK')),
  thread_id UUID NOT NULL, -- ID da comunidade ou grupo (tarefa)
  
  -- Configuração do destino no Telegram
  mode TEXT NOT NULL CHECK (mode IN ('dm', 'group_topic', 'group_plain')),
  telegram_chat_id BIGINT NOT NULL, -- ID do chat/grupo no Telegram
  telegram_topic_id INTEGER, -- ID do tópico (se mode = group_topic)
  
  -- Metadados
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  active BOOLEAN NOT NULL DEFAULT true,
  
  -- Configurações adicionais
  settings JSONB DEFAULT '{
    "send_notifications": true,
    "send_attachments": true,
    "send_locations": true,
    "bi_directional": true
  }',
  
  CONSTRAINT telegram_subscriptions_unique_thread UNIQUE(thread_type, thread_id, telegram_chat_id, telegram_topic_id)
);

-- Índices
CREATE INDEX idx_telegram_subscriptions_thread ON public.telegram_subscriptions(thread_type, thread_id);
CREATE INDEX idx_telegram_subscriptions_telegram_chat ON public.telegram_subscriptions(telegram_chat_id);
CREATE INDEX idx_telegram_subscriptions_active ON public.telegram_subscriptions(active) WHERE active = true;

COMMENT ON TABLE public.telegram_subscriptions IS 'Assinaturas de threads (comunidades/tarefas) para espelhamento no Telegram';
COMMENT ON COLUMN public.telegram_subscriptions.thread_type IS 'Tipo: COMMUNITY (comunidade) ou TASK (tarefa/grupo)';
COMMENT ON COLUMN public.telegram_subscriptions.thread_id IS 'ID da comunidade ou do grupo_chat';
COMMENT ON COLUMN public.telegram_subscriptions.mode IS 'Modo: dm (mensagens diretas), group_topic (tópico em grupo), group_plain (grupo simples)';
COMMENT ON COLUMN public.telegram_subscriptions.telegram_chat_id IS 'ID do chat/grupo no Telegram (negativo para grupos)';
COMMENT ON COLUMN public.telegram_subscriptions.telegram_topic_id IS 'ID do tópico no Telegram (apenas para group_topic)';

-- =========================================
-- 3. ADICIONAR CAMPOS NA TABELA MENSAGENS
-- =========================================
-- Adicionar campos para metadados do Telegram
ALTER TABLE public.mensagens 
  ADD COLUMN IF NOT EXISTS source TEXT DEFAULT 'app' CHECK (source IN ('app', 'telegram')),
  ADD COLUMN IF NOT EXISTS telegram_metadata JSONB DEFAULT NULL;

COMMENT ON COLUMN public.mensagens.source IS 'Origem da mensagem: app (Flutter) ou telegram';
COMMENT ON COLUMN public.mensagens.telegram_metadata IS 'Metadados do Telegram: {chat_id, message_id, from_id, username, etc}';

-- Índice para filtrar mensagens por origem
CREATE INDEX IF NOT EXISTS idx_mensagens_source ON public.mensagens(source);

-- =========================================
-- 4. TABELA DE LOG DE ENTREGAS TELEGRAM
-- =========================================
-- Registra tentativas de envio para o Telegram (para debug e retry)
CREATE TABLE IF NOT EXISTS public.telegram_delivery_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mensagem_id UUID REFERENCES public.mensagens(id) ON DELETE CASCADE,
  subscription_id UUID REFERENCES public.telegram_subscriptions(id) ON DELETE CASCADE,
  
  -- Status da entrega
  status TEXT NOT NULL CHECK (status IN ('pending', 'sent', 'failed', 'retry')),
  attempt_count INTEGER NOT NULL DEFAULT 1,
  
  -- Dados do Telegram
  telegram_chat_id BIGINT,
  telegram_message_id INTEGER, -- ID da mensagem enviada no Telegram
  telegram_topic_id INTEGER,
  
  -- Detalhes de erro (se houver)
  error_code TEXT,
  error_message TEXT,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  sent_at TIMESTAMPTZ,
  failed_at TIMESTAMPTZ,
  
  -- Payload completo (para retry)
  request_payload JSONB,
  response_payload JSONB
);

CREATE INDEX idx_telegram_delivery_logs_mensagem ON public.telegram_delivery_logs(mensagem_id);
CREATE INDEX idx_telegram_delivery_logs_status ON public.telegram_delivery_logs(status);
CREATE INDEX idx_telegram_delivery_logs_created ON public.telegram_delivery_logs(created_at DESC);

COMMENT ON TABLE public.telegram_delivery_logs IS 'Log de entregas de mensagens para o Telegram (para debug e retry)';

-- =========================================
-- 5. FUNÇÃO PARA OBTER SUBSCRIPTION DE UM GRUPO
-- =========================================
-- Função helper para buscar subscriptions ativas de um grupo/comunidade
CREATE OR REPLACE FUNCTION public.get_telegram_subscriptions_for_thread(
  p_thread_type TEXT,
  p_thread_id UUID
)
RETURNS TABLE (
  subscription_id UUID,
  mode TEXT,
  telegram_chat_id BIGINT,
  telegram_topic_id INTEGER,
  settings JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ts.id,
    ts.mode,
    ts.telegram_chat_id,
    ts.telegram_topic_id,
    ts.settings
  FROM public.telegram_subscriptions ts
  WHERE ts.thread_type = p_thread_type
    AND ts.thread_id = p_thread_id
    AND ts.active = true;
END;
$$;

COMMENT ON FUNCTION public.get_telegram_subscriptions_for_thread IS 'Retorna subscriptions ativas para um thread (comunidade ou tarefa)';

-- =========================================
-- 6. FUNÇÃO PARA VINCULAR USUÁRIO AO TELEGRAM
-- =========================================
CREATE OR REPLACE FUNCTION public.link_telegram_identity(
  p_user_id UUID,
  p_telegram_user_id BIGINT,
  p_telegram_username TEXT DEFAULT NULL,
  p_telegram_first_name TEXT DEFAULT NULL,
  p_telegram_last_name TEXT DEFAULT NULL,
  p_last_chat_id BIGINT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_identity_id UUID;
BEGIN
  -- Inserir ou atualizar
  INSERT INTO public.telegram_identities (
    user_id,
    telegram_user_id,
    telegram_username,
    telegram_first_name,
    telegram_last_name,
    last_chat_id,
    linked_at,
    last_active_at
  )
  VALUES (
    p_user_id,
    p_telegram_user_id,
    p_telegram_username,
    p_telegram_first_name,
    p_telegram_last_name,
    p_last_chat_id,
    now(),
    now()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    telegram_user_id = EXCLUDED.telegram_user_id,
    telegram_username = EXCLUDED.telegram_username,
    telegram_first_name = EXCLUDED.telegram_first_name,
    telegram_last_name = EXCLUDED.telegram_last_name,
    last_chat_id = COALESCE(EXCLUDED.last_chat_id, telegram_identities.last_chat_id),
    last_active_at = now()
  RETURNING id INTO v_identity_id;
  
  RETURN v_identity_id;
END;
$$;

COMMENT ON FUNCTION public.link_telegram_identity IS 'Vincula (ou atualiza) identidade Telegram de um usuário';

-- =========================================
-- 7. RLS (ROW LEVEL SECURITY)
-- =========================================

-- Habilitar RLS
ALTER TABLE public.telegram_identities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.telegram_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.telegram_delivery_logs ENABLE ROW LEVEL SECURITY;

-- Políticas para telegram_identities
-- Usuários só podem ver/editar sua própria identidade
CREATE POLICY "Users can view own telegram identity"
  ON public.telegram_identities FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own telegram identity"
  ON public.telegram_identities FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own telegram identity"
  ON public.telegram_identities FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Políticas para telegram_subscriptions
-- Usuários autenticados podem ver subscriptions (filtradas por acesso às comunidades/grupos)
CREATE POLICY "Authenticated users can view subscriptions"
  ON public.telegram_subscriptions FOR SELECT
  USING (auth.role() = 'authenticated');

-- Apenas criadores ou admins podem inserir/atualizar subscriptions
CREATE POLICY "Users can manage own subscriptions"
  ON public.telegram_subscriptions FOR ALL
  USING (
    auth.uid() = created_by OR
    EXISTS (
      SELECT 1 FROM public.usuarios u
      WHERE u.id = auth.uid() AND u.is_root = true
    )
  );

-- Políticas para telegram_delivery_logs
-- Apenas serviço pode escrever, usuários podem ler seus logs
CREATE POLICY "Service can write delivery logs"
  ON public.telegram_delivery_logs FOR INSERT
  WITH CHECK (true); -- Edge Function usa service_role

CREATE POLICY "Users can view delivery logs"
  ON public.telegram_delivery_logs FOR SELECT
  USING (auth.role() = 'authenticated');

-- =========================================
-- 8. GRANTS
-- =========================================
GRANT SELECT, INSERT, UPDATE ON public.telegram_identities TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.telegram_subscriptions TO authenticated;
GRANT SELECT ON public.telegram_delivery_logs TO authenticated;
GRANT ALL ON public.telegram_delivery_logs TO service_role;

-- =========================================
-- FIM DA MIGRAÇÃO
-- =========================================
