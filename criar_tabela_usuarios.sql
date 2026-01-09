-- Criar tabela de usuários (sem confirmação de email)
CREATE TABLE IF NOT EXISTS usuarios (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) NOT NULL UNIQUE,
  senha_hash TEXT NOT NULL, -- Hash da senha (usar bcrypt)
  nome VARCHAR(255),
  ativo BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Criar índice para busca rápida por email
CREATE INDEX IF NOT EXISTS idx_usuarios_email ON usuarios(email);

-- Criar índice para busca por usuários ativos
CREATE INDEX IF NOT EXISTS idx_usuarios_ativo ON usuarios(ativo);

-- Função para atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION update_usuarios_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para atualizar updated_at
CREATE TRIGGER trigger_update_usuarios_updated_at
  BEFORE UPDATE ON usuarios
  FOR EACH ROW
  EXECUTE FUNCTION update_usuarios_updated_at();

-- Habilitar RLS (Row Level Security)
ALTER TABLE usuarios ENABLE ROW LEVEL SECURITY;

-- Remover políticas antigas se existirem
DROP POLICY IF EXISTS "Permitir todas as operações em usuarios" ON usuarios;

-- Política para permitir todas as operações (ajustar para produção)
CREATE POLICY "Permitir todas as operações em usuarios" ON usuarios
  FOR ALL USING (true) WITH CHECK (true);

-- Criar usuário de exemplo (senha: "123456" - hash bcrypt)
-- Para gerar um hash bcrypt, você pode usar: https://bcrypt-generator.com/
-- Ou usar uma função do PostgreSQL se tiver a extensão pgcrypto
-- INSERT INTO usuarios (email, senha_hash, nome) VALUES 
--   ('admin@example.com', '$2a$10$rOzJqXKqXKqXKqXKqXKqXe', 'Administrador');

