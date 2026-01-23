-- Criar tabela de ordens
CREATE TABLE IF NOT EXISTS ordens (
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
CREATE INDEX IF NOT EXISTS idx_ordens_ordem ON ordens(ordem);
CREATE INDEX IF NOT EXISTS idx_ordens_status_sistema ON ordens(status_sistema);
CREATE INDEX IF NOT EXISTS idx_ordens_local_instalacao ON ordens(local_instalacao);
CREATE INDEX IF NOT EXISTS idx_ordens_tipo ON ordens(tipo);
CREATE INDEX IF NOT EXISTS idx_ordens_inicio_base ON ordens(inicio_base);
CREATE INDEX IF NOT EXISTS idx_ordens_fim_base ON ordens(fim_base);

-- Habilitar RLS (Row Level Security)
ALTER TABLE ordens ENABLE ROW LEVEL SECURITY;

-- Política: Permitir todas as operações (ajuste conforme necessário)
CREATE POLICY "Permitir todas as operações em ordens" ON ordens
  FOR ALL USING (true) WITH CHECK (true);
