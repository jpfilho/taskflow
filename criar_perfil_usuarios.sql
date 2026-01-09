-- Adicionar campos de perfil à tabela usuarios
-- Regional, Divisão e Segmentos serão relacionados via tabelas de junção

-- Tabela de relacionamento: usuarios_regionais (many-to-many)
CREATE TABLE IF NOT EXISTS usuarios_regionais (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  regional_id UUID NOT NULL REFERENCES regionais(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(usuario_id, regional_id)
);

-- Tabela de relacionamento: usuarios_divisoes (many-to-many)
CREATE TABLE IF NOT EXISTS usuarios_divisoes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  divisao_id UUID NOT NULL REFERENCES divisoes(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(usuario_id, divisao_id)
);

-- Tabela de relacionamento: usuarios_segmentos (many-to-many)
CREATE TABLE IF NOT EXISTS usuarios_segmentos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  segmento_id UUID NOT NULL REFERENCES segmentos(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(usuario_id, segmento_id)
);

-- Criar índices para busca rápida
CREATE INDEX IF NOT EXISTS idx_usuarios_regionais_usuario_id ON usuarios_regionais(usuario_id);
CREATE INDEX IF NOT EXISTS idx_usuarios_regionais_regional_id ON usuarios_regionais(regional_id);
CREATE INDEX IF NOT EXISTS idx_usuarios_divisoes_usuario_id ON usuarios_divisoes(usuario_id);
CREATE INDEX IF NOT EXISTS idx_usuarios_divisoes_divisao_id ON usuarios_divisoes(divisao_id);
CREATE INDEX IF NOT EXISTS idx_usuarios_segmentos_usuario_id ON usuarios_segmentos(usuario_id);
CREATE INDEX IF NOT EXISTS idx_usuarios_segmentos_segmento_id ON usuarios_segmentos(segmento_id);

-- Habilitar RLS (Row Level Security)
ALTER TABLE usuarios_regionais ENABLE ROW LEVEL SECURITY;
ALTER TABLE usuarios_divisoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE usuarios_segmentos ENABLE ROW LEVEL SECURITY;

-- Remover políticas antigas se existirem
DROP POLICY IF EXISTS "Permitir todas as operações em usuarios_regionais" ON usuarios_regionais;
DROP POLICY IF EXISTS "Permitir todas as operações em usuarios_divisoes" ON usuarios_divisoes;
DROP POLICY IF EXISTS "Permitir todas as operações em usuarios_segmentos" ON usuarios_segmentos;

-- Políticas para permitir todas as operações (ajustar para produção)
CREATE POLICY "Permitir todas as operações em usuarios_regionais" ON usuarios_regionais
  FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Permitir todas as operações em usuarios_divisoes" ON usuarios_divisoes
  FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Permitir todas as operações em usuarios_segmentos" ON usuarios_segmentos
  FOR ALL USING (true) WITH CHECK (true);

