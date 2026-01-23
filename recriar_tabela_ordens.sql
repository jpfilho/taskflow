-- ============================================
-- SQL PARA RECRIAR TABELA DE ORDENS DO ZERO
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- ATENÇÃO: Isso vai deletar todos os dados existentes!

-- Desabilitar RLS temporariamente
ALTER TABLE IF EXISTS ordens DISABLE ROW LEVEL SECURITY;

-- Remover todas as políticas existentes
DROP POLICY IF EXISTS "Usuários autenticados podem ler ordens" ON ordens;
DROP POLICY IF EXISTS "Usuários autenticados podem inserir ordens" ON ordens;
DROP POLICY IF EXISTS "Usuários autenticados podem atualizar ordens" ON ordens;
DROP POLICY IF EXISTS "Usuários autenticados podem deletar ordens" ON ordens;
DROP POLICY IF EXISTS "Permitir todas as operações em ordens" ON ordens;

-- Deletar índices
DROP INDEX IF EXISTS idx_ordens_ordem;
DROP INDEX IF EXISTS idx_ordens_status_sistema;
DROP INDEX IF EXISTS idx_ordens_local_instalacao;
DROP INDEX IF EXISTS idx_ordens_tipo;
DROP INDEX IF EXISTS idx_ordens_inicio_base;
DROP INDEX IF EXISTS idx_ordens_fim_base;

-- Deletar tabela (CUIDADO: isso apaga todos os dados!)
DROP TABLE IF EXISTS ordens CASCADE;

-- Criar tabela de ordens
CREATE TABLE ordens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ordem TEXT NOT NULL UNIQUE,
  inicio_base DATE,
  fim_base DATE,
  tipo TEXT,
  status_sistema TEXT,
  denominacao_local_instalacao TEXT,
  denominacao_objeto TEXT,
  texto_breve TEXT,
  local_instalacao TEXT,
  status_usuario TEXT,
  codigo_si TEXT,
  gpm TEXT,
  data_importacao TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Criar índices para melhorar performance
CREATE INDEX idx_ordens_ordem ON ordens(ordem);
CREATE INDEX idx_ordens_status_sistema ON ordens(status_sistema);
CREATE INDEX idx_ordens_local_instalacao ON ordens(local_instalacao);
CREATE INDEX idx_ordens_tipo ON ordens(tipo);
CREATE INDEX idx_ordens_inicio_base ON ordens(inicio_base);
CREATE INDEX idx_ordens_fim_base ON ordens(fim_base);

-- Habilitar RLS (Row Level Security)
ALTER TABLE ordens ENABLE ROW LEVEL SECURITY;

-- Política: Permitir todas as operações (ajuste conforme necessário)
CREATE POLICY "Permitir todas as operações em ordens" ON ordens
  FOR ALL USING (true) WITH CHECK (true);

-- Verificar se a tabela foi criada corretamente
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'ordens'
ORDER BY ordinal_position;

-- Verificar políticas RLS
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'ordens'
ORDER BY policyname;
