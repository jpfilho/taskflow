-- Criar tabela 'sis' (Solicitações)
CREATE TABLE IF NOT EXISTS sis (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  solicitacao TEXT NOT NULL UNIQUE, -- Número da solicitação (ex: 00001299/25H)
  tipo TEXT, -- Tp (T5, T1, T7, etc.)
  texto_breve TEXT, -- Texto breve
  data_criacao DATE, -- DtCriação
  local_instalacao TEXT, -- Local de instalação
  criado_por TEXT, -- Criado por
  data_inicio DATE, -- Dt Início
  data_fim DATE, -- Data Fim
  status_usuario TEXT, -- St.usuário (CRSI, CONC, CANC, etc.)
  status_sistema TEXT, -- Status do sistema (CRI., PREP, etc.)
  cntr_trab TEXT, -- CntrTrab (MNSE.TSA, etc.)
  cen TEXT, -- Cen. (HF5C, etc.)
  valido TEXT, -- Válido
  hora_inicio TEXT, -- Hora iníc.
  hora_fim TEXT, -- Hora fim
  atrib_at TEXT, -- Atrib. AT
  data_importacao TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Criar índices para melhorar performance
CREATE INDEX IF NOT EXISTS idx_sis_solicitacao ON sis(solicitacao);
CREATE INDEX IF NOT EXISTS idx_sis_status_sistema ON sis(status_sistema);
CREATE INDEX IF NOT EXISTS idx_sis_status_usuario ON sis(status_usuario);
CREATE INDEX IF NOT EXISTS idx_sis_local_instalacao ON sis(local_instalacao);
CREATE INDEX IF NOT EXISTS idx_sis_cntr_trab ON sis(cntr_trab);
CREATE INDEX IF NOT EXISTS idx_sis_data_inicio ON sis(data_inicio);
CREATE INDEX IF NOT EXISTS idx_sis_data_fim ON sis(data_fim);

-- Comentários nas colunas
COMMENT ON TABLE sis IS 'Tabela de Solicitações (SIs)';
COMMENT ON COLUMN sis.solicitacao IS 'Número da solicitação (chave única)';
COMMENT ON COLUMN sis.tipo IS 'Tipo da solicitação (T5, T1, T7, etc.)';
COMMENT ON COLUMN sis.cntr_trab IS 'Centro de trabalho responsável';
