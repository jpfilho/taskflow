-- Criar tabela de Frota
CREATE TABLE IF NOT EXISTS frota (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nome VARCHAR(200) NOT NULL,
  marca VARCHAR(100),
  tipo_veiculo VARCHAR(50) NOT NULL CHECK (tipo_veiculo IN (
    'CARRO_LEVE',
    'MUNCK',
    'TRATOR',
    'CAMINHAO',
    'PICKUP',
    'VAN',
    'MOTO',
    'ONIBUS',
    'OUTRO'
  )),
  placa VARCHAR(10) NOT NULL,
  regional_id UUID REFERENCES regionais(id) ON DELETE SET NULL,
  divisao_id UUID REFERENCES divisoes(id) ON DELETE SET NULL,
  segmento_id UUID REFERENCES segmentos(id) ON DELETE SET NULL,
  em_manutencao BOOLEAN DEFAULT FALSE,
  observacoes TEXT,
  ativo BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT unique_placa UNIQUE(placa)
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_frota_regional_id ON frota(regional_id);
CREATE INDEX IF NOT EXISTS idx_frota_divisao_id ON frota(divisao_id);
CREATE INDEX IF NOT EXISTS idx_frota_segmento_id ON frota(segmento_id);
CREATE INDEX IF NOT EXISTS idx_frota_tipo_veiculo ON frota(tipo_veiculo);
CREATE INDEX IF NOT EXISTS idx_frota_placa ON frota(placa);
CREATE INDEX IF NOT EXISTS idx_frota_ativo ON frota(ativo);

-- Trigger para atualizar updated_at
CREATE OR REPLACE FUNCTION update_frota_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_frota_updated_at
  BEFORE UPDATE ON frota
  FOR EACH ROW
  EXECUTE FUNCTION update_frota_updated_at();

-- RLS Policies
ALTER TABLE frota ENABLE ROW LEVEL SECURITY;

-- Políticas que funcionam com autenticação customizada
CREATE POLICY "Usuários autenticados podem ver frota"
  ON frota
  FOR SELECT
  USING (true);

CREATE POLICY "Usuários autenticados podem criar frota"
  ON frota
  FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Usuários autenticados podem atualizar frota"
  ON frota
  FOR UPDATE
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Usuários autenticados podem deletar frota"
  ON frota
  FOR DELETE
  USING (true);
