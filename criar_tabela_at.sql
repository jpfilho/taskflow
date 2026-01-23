-- ============================================
-- SQL PARA CRIAR TABELA DE ATs (ATIVIDADES TÉCNICAS)
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard

-- Tabela de ATs
CREATE TABLE IF NOT EXISTS ats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  autorz_trab TEXT NOT NULL UNIQUE, -- Número da AT (chave única)
  edificacao TEXT,
  local_instalacao TEXT,
  texto_breve TEXT,
  data_criacao TIMESTAMPTZ,
  data_inicio TIMESTAMPTZ,
  valido_desde TEXT, -- Hora (HH:MM:SS)
  data_fim TIMESTAMPTZ,
  valido_ate TEXT, -- Hora (HH:MM:SS)
  valido TEXT,
  status_usuario TEXT, -- CONC, CRSI, CANC, etc.
  status_sistema TEXT, -- PREP ENCE, CRI., etc.
  lis_objs TEXT,
  atrib1 TEXT,
  atrib2 TEXT,
  cntr_trab TEXT, -- MNSE.FTZ, etc.
  cen TEXT, -- HL8C, etc.
  si TEXT,
  criado_por TEXT,
  modif_por TEXT,
  data_modifc TIMESTAMPTZ,
  tp_ret TEXT,
  data_importacao TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_ats_autorz_trab ON ats(autorz_trab);
CREATE INDEX IF NOT EXISTS idx_ats_local_instalacao ON ats(local_instalacao);
CREATE INDEX IF NOT EXISTS idx_ats_status_sistema ON ats(status_sistema);
CREATE INDEX IF NOT EXISTS idx_ats_status_usuario ON ats(status_usuario);
CREATE INDEX IF NOT EXISTS idx_ats_data_inicio ON ats(data_inicio);

-- RLS Policies
ALTER TABLE ats ENABLE ROW LEVEL SECURITY;

-- Política: Permitir todas as operações (ajuste conforme necessário)
CREATE POLICY "Permitir todas as operações em ats" ON ats
  FOR ALL USING (true) WITH CHECK (true);

-- Comentários
COMMENT ON TABLE ats IS 'Atividades Técnicas (ATs)';
COMMENT ON COLUMN ats.autorz_trab IS 'Número da AT (chave única)';
COMMENT ON COLUMN ats.edificacao IS 'Edificação (ex: H-S-SSBD)';
COMMENT ON COLUMN ats.local_instalacao IS 'Local de instalação';
COMMENT ON COLUMN ats.texto_breve IS 'Texto breve da atividade';
COMMENT ON COLUMN ats.status_usuario IS 'Status do usuário (CONC, CRSI, CANC, etc.)';
COMMENT ON COLUMN ats.status_sistema IS 'Status do sistema (PREP ENCE, CRI., etc.)';
