-- ============================================
-- MIGRATION: GENERALIZAR INTEGRAÇÃO TELEGRAM
-- ============================================
-- Estrutura para suportar múltiplas tarefas e comunidades
-- Modelo: 1 Supergrupo por Comunidade + 1 Tópico por Tarefa

-- 1. Tabela para mapear Comunidades -> Supergrupos Telegram
CREATE TABLE IF NOT EXISTS telegram_communities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id UUID NOT NULL REFERENCES comunidades(id) ON DELETE CASCADE,
  telegram_chat_id BIGINT NOT NULL, -- ID do supergrupo no Telegram
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(community_id) -- Uma comunidade pode ter apenas um supergrupo, mas múltiplas comunidades podem compartilhar o mesmo supergrupo
);

CREATE INDEX IF NOT EXISTS idx_telegram_communities_community_id ON telegram_communities(community_id);
CREATE INDEX IF NOT EXISTS idx_telegram_communities_chat_id ON telegram_communities(telegram_chat_id);

-- 2. Tabela para mapear Tarefas -> Tópicos no Telegram
CREATE TABLE IF NOT EXISTS telegram_task_topics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL, -- ID da tarefa (tasks.id)
  grupo_chat_id UUID NOT NULL REFERENCES grupos_chat(id) ON DELETE CASCADE,
  community_id UUID NOT NULL REFERENCES comunidades(id) ON DELETE CASCADE,
  telegram_chat_id BIGINT NOT NULL, -- ID do supergrupo
  telegram_topic_id INT NOT NULL, -- message_thread_id do tópico
  topic_name VARCHAR(255) NOT NULL, -- Nome do tópico (geralmente nome da tarefa)
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(task_id), -- Uma tarefa = um tópico
  UNIQUE(telegram_chat_id, telegram_topic_id) -- Tópicos únicos por supergrupo
  -- Nota: Foreign key para telegram_communities via telegram_chat_id não é possível diretamente
  -- pois telegram_chat_id é BIGINT e não há PK composta. Validação via trigger ou aplicação.
);

CREATE INDEX IF NOT EXISTS idx_telegram_task_topics_task_id ON telegram_task_topics(task_id);
CREATE INDEX IF NOT EXISTS idx_telegram_task_topics_grupo_chat_id ON telegram_task_topics(grupo_chat_id);
CREATE INDEX IF NOT EXISTS idx_telegram_task_topics_community_id ON telegram_task_topics(community_id);
CREATE INDEX IF NOT EXISTS idx_telegram_task_topics_chat_topic ON telegram_task_topics(telegram_chat_id, telegram_topic_id);

-- 3. Tabela para logs de entrega (já existe, mas vamos garantir estrutura)
CREATE TABLE IF NOT EXISTS telegram_delivery_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mensagem_id UUID NOT NULL,
  task_id UUID,
  telegram_chat_id BIGINT,
  telegram_topic_id INT,
  telegram_message_id BIGINT,
  status VARCHAR(20) NOT NULL, -- 'pending', 'sent', 'failed', 'retry'
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_telegram_delivery_logs_mensagem_id ON telegram_delivery_logs(mensagem_id);
CREATE INDEX IF NOT EXISTS idx_telegram_delivery_logs_status ON telegram_delivery_logs(status);
CREATE INDEX IF NOT EXISTS idx_telegram_delivery_logs_created_at ON telegram_delivery_logs(created_at);

-- 4. Função para obter community_id de uma tarefa
CREATE OR REPLACE FUNCTION get_community_id_for_task(p_task_id UUID)
RETURNS UUID AS $$
DECLARE
  v_community_id UUID;
BEGIN
  -- Buscar comunidade através do grupo_chat da tarefa
  SELECT gc.comunidade_id INTO v_community_id
  FROM grupos_chat gc
  WHERE gc.tarefa_id = p_task_id
  LIMIT 1;
  
  RETURN v_community_id;
END;
$$ LANGUAGE plpgsql;

-- 5. Função para obter grupo_chat_id de uma tarefa
CREATE OR REPLACE FUNCTION get_grupo_chat_id_for_task(p_task_id UUID)
RETURNS UUID AS $$
DECLARE
  v_grupo_chat_id UUID;
BEGIN
  SELECT gc.id INTO v_grupo_chat_id
  FROM grupos_chat gc
  WHERE gc.tarefa_id = p_task_id
  LIMIT 1;
  
  RETURN v_grupo_chat_id;
END;
$$ LANGUAGE plpgsql;

-- 6. Trigger para NOTIFY quando nova mensagem é criada (para LISTEN/NOTIFY)
CREATE OR REPLACE FUNCTION notify_new_message()
RETURNS TRIGGER AS $$
BEGIN
  -- Notificar apenas mensagens do app (source IS NULL ou 'app')
  IF NEW.source IS NULL OR NEW.source = 'app' THEN
    PERFORM pg_notify('new_message', json_build_object(
      'id', NEW.id,
      'grupo_id', NEW.grupo_id,
      'usuario_id', NEW.usuario_id,
      'conteudo', NEW.conteudo,
      'created_at', NEW.created_at
    )::text);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Criar trigger se não existir
DROP TRIGGER IF EXISTS trigger_notify_new_message ON mensagens;
CREATE TRIGGER trigger_notify_new_message
  AFTER INSERT ON mensagens
  FOR EACH ROW
  EXECUTE FUNCTION notify_new_message();

-- 7. RLS Policies
ALTER TABLE telegram_communities ENABLE ROW LEVEL SECURITY;
ALTER TABLE telegram_task_topics ENABLE ROW LEVEL SECURITY;

-- Permitir leitura de communities e topics ativos
CREATE POLICY "Allow read telegram_communities"
ON telegram_communities FOR SELECT
USING (true);

CREATE POLICY "Allow read telegram_task_topics"
ON telegram_task_topics FOR SELECT
USING (true);

-- Permitir inserção/atualização apenas para service_role (via Node.js)
-- Nota: Em produção, usar service_role key no Node.js

COMMENT ON TABLE telegram_communities IS 'Mapeia comunidades (divisão+segmento) para supergrupos Telegram';
COMMENT ON TABLE telegram_task_topics IS 'Mapeia tarefas para tópicos dentro dos supergrupos Telegram';
COMMENT ON TABLE telegram_delivery_logs IS 'Logs de entrega de mensagens para Telegram';
