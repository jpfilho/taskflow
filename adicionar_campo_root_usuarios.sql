-- Adicionar campo is_root na tabela usuarios
-- Usuários root têm acesso a todas as tarefas, independentemente do perfil

-- 1. Adicionar coluna is_root (se não existir)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'usuarios' AND column_name = 'is_root') THEN
        ALTER TABLE usuarios ADD COLUMN is_root BOOLEAN DEFAULT false;
        RAISE NOTICE 'Coluna is_root adicionada à tabela usuarios.';
    ELSE
        RAISE NOTICE 'Coluna is_root já existe na tabela usuarios.';
    END IF;
END
$$;

-- 2. Criar índice para busca rápida de usuários root
CREATE INDEX IF NOT EXISTS idx_usuarios_is_root ON usuarios(is_root) WHERE is_root = true;

-- 3. Criar usuário root padrão (senha: "root123")
-- IMPORTANTE: Altere a senha após o primeiro login!
-- O sistema atual armazena senhas em texto plano (será atualizado para hash depois)
INSERT INTO usuarios (email, senha_hash, nome, is_root, ativo)
VALUES (
  'root@taskflow.com',
  'root123', -- Senha em texto plano
  'Administrador Root',
  true,
  true
)
ON CONFLICT (email) DO UPDATE SET
  is_root = true,
  ativo = true,
  nome = 'Administrador Root';

-- 4. Verificar usuários root criados
SELECT id, email, nome, is_root, ativo, created_at 
FROM usuarios 
WHERE is_root = true;

