-- Criar tabela de comunidades (baseadas em divisão + segmento)
-- Se a tabela já existe, use o script migrar_comunidades_para_divisao_segmento.sql
CREATE TABLE IF NOT EXISTS comunidades (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  divisao_id UUID NOT NULL,
  divisao_nome VARCHAR(255) NOT NULL,
  segmento_id UUID NOT NULL,
  segmento_nome VARCHAR(255) NOT NULL,
  descricao TEXT,
  foto_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT comunidades_divisao_id_segmento_id_key UNIQUE(divisao_id, segmento_id) -- Uma comunidade por combinação de divisão + segmento
);

-- Criar índices para busca rápida
CREATE INDEX IF NOT EXISTS idx_comunidades_divisao_id ON comunidades(divisao_id);
CREATE INDEX IF NOT EXISTS idx_comunidades_segmento_id ON comunidades(segmento_id);
CREATE INDEX IF NOT EXISTS idx_comunidades_divisao_segmento ON comunidades(divisao_id, segmento_id);

-- Criar tabela de grupos de chat (baseados em tarefas)
CREATE TABLE IF NOT EXISTS grupos_chat (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tarefa_id UUID NOT NULL UNIQUE, -- Um grupo por tarefa
  tarefa_nome VARCHAR(255) NOT NULL,
  comunidade_id UUID NOT NULL REFERENCES comunidades(id) ON DELETE CASCADE,
  descricao TEXT,
  foto_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Criar índices para grupos
CREATE INDEX IF NOT EXISTS idx_grupos_chat_tarefa_id ON grupos_chat(tarefa_id);
CREATE INDEX IF NOT EXISTS idx_grupos_chat_comunidade_id ON grupos_chat(comunidade_id);

-- Criar tabela de mensagens
CREATE TABLE IF NOT EXISTS mensagens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  grupo_id UUID NOT NULL REFERENCES grupos_chat(id) ON DELETE CASCADE,
  usuario_id UUID NOT NULL, -- ID do usuário autenticado
  usuario_nome VARCHAR(255), -- Nome do usuário (para exibição)
  conteudo TEXT NOT NULL,
  tipo VARCHAR(20) DEFAULT 'texto' CHECK (tipo IN ('texto', 'imagem', 'video', 'documento', 'audio')),
  arquivo_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  lida BOOLEAN DEFAULT false,
  usuarios_lidos JSONB -- Array de IDs de usuários que leram a mensagem
);

-- Criar índices para mensagens
CREATE INDEX IF NOT EXISTS idx_mensagens_grupo_id ON mensagens(grupo_id);
CREATE INDEX IF NOT EXISTS idx_mensagens_usuario_id ON mensagens(usuario_id);
CREATE INDEX IF NOT EXISTS idx_mensagens_created_at ON mensagens(created_at DESC);

-- Criar tabela de leitura de mensagens (para rastrear quem leu o quê)
CREATE TABLE IF NOT EXISTS mensagens_lidas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mensagem_id UUID NOT NULL REFERENCES mensagens(id) ON DELETE CASCADE,
  usuario_id UUID NOT NULL,
  lida_em TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(mensagem_id, usuario_id)
);

-- Criar índices para mensagens lidas
CREATE INDEX IF NOT EXISTS idx_mensagens_lidas_mensagem_id ON mensagens_lidas(mensagem_id);
CREATE INDEX IF NOT EXISTS idx_mensagens_lidas_usuario_id ON mensagens_lidas(usuario_id);

-- Função para atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers para atualizar updated_at
CREATE TRIGGER trigger_update_comunidades_updated_at
  BEFORE UPDATE ON comunidades
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_update_grupos_chat_updated_at
  BEFORE UPDATE ON grupos_chat
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_update_mensagens_updated_at
  BEFORE UPDATE ON mensagens
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Habilitar RLS (Row Level Security)
ALTER TABLE comunidades ENABLE ROW LEVEL SECURITY;
ALTER TABLE grupos_chat ENABLE ROW LEVEL SECURITY;
ALTER TABLE mensagens ENABLE ROW LEVEL SECURITY;
ALTER TABLE mensagens_lidas ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para comunidades (permitir todas as operações para usuários autenticados)
DROP POLICY IF EXISTS "Permitir todas as operações em comunidades" ON comunidades;
CREATE POLICY "Permitir todas as operações em comunidades" ON comunidades
  FOR ALL USING (true) WITH CHECK (true);

-- Políticas RLS para grupos_chat
DROP POLICY IF EXISTS "Permitir todas as operações em grupos_chat" ON grupos_chat;
CREATE POLICY "Permitir todas as operações em grupos_chat" ON grupos_chat
  FOR ALL USING (true) WITH CHECK (true);

-- Políticas RLS para mensagens
DROP POLICY IF EXISTS "Permitir todas as operações em mensagens" ON mensagens;
CREATE POLICY "Permitir todas as operações em mensagens" ON mensagens
  FOR ALL USING (true) WITH CHECK (true);

-- Políticas RLS para mensagens_lidas
DROP POLICY IF EXISTS "Permitir todas as operações em mensagens_lidas" ON mensagens_lidas;
CREATE POLICY "Permitir todas as operações em mensagens_lidas" ON mensagens_lidas
  FOR ALL USING (true) WITH CHECK (true);

-- Função para criar comunidade automaticamente quando uma divisão é criada
-- (Isso pode ser feito via trigger ou manualmente)

-- Função para criar grupo automaticamente quando uma tarefa é criada
-- (Isso pode ser feito via trigger ou manualmente)

