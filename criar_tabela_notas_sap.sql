-- ============================================
-- SQL PARA CRIAR TABELA DE NOTAS SAP
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new

-- Tabela principal de notas SAP
CREATE TABLE IF NOT EXISTS notas_sap (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo VARCHAR(10), -- NM, NP, etc.
  criado_em DATE,
  text_prioridade VARCHAR(50), -- Por oportunidade, Alta, Média, Baixa, Monitoramento
  nota VARCHAR(50) UNIQUE NOT NULL, -- Número da nota (chave única)
  ordem VARCHAR(50),
  descricao TEXT,
  local_instalacao VARCHAR(200),
  sala VARCHAR(50),
  status_sistema VARCHAR(50), -- MSPN, MSPR, MSPR ORDA, etc.
  inicio_desejado DATE,
  conclusao_desejada DATE,
  hora_criacao TIME,
  status_usuario VARCHAR(50), -- REGI, ANLS, etc.
  equipamento VARCHAR(50),
  data DATE,
  notificacao VARCHAR(50),
  centro_trabalho_responsavel VARCHAR(50), -- CenTrabRes
  centro VARCHAR(10), -- Cen.
  fim_avaria DATE,
  de VARCHAR(50),
  encerramento DATE,
  denominacao_executor VARCHAR(200),
  data_referencia DATE,
  gpm VARCHAR(10),
  inicio_avaria DATE,
  modificado_em DATE,
  campo_ordenacao VARCHAR(50), -- Cpo.orden.
  data_importacao TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabela de junção para vincular notas SAP às tarefas
CREATE TABLE IF NOT EXISTS tasks_notas_sap (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  nota_sap_id UUID NOT NULL REFERENCES notas_sap(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(task_id, nota_sap_id) -- Evitar duplicatas
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_notas_sap_nota ON notas_sap(nota);
CREATE INDEX IF NOT EXISTS idx_notas_sap_criado_em ON notas_sap(criado_em);
CREATE INDEX IF NOT EXISTS idx_notas_sap_status_sistema ON notas_sap(status_sistema);
CREATE INDEX IF NOT EXISTS idx_notas_sap_local_instalacao ON notas_sap(local_instalacao);
CREATE INDEX IF NOT EXISTS idx_tasks_notas_sap_task_id ON tasks_notas_sap(task_id);
CREATE INDEX IF NOT EXISTS idx_tasks_notas_sap_nota_sap_id ON tasks_notas_sap(nota_sap_id);

-- RLS Policies
ALTER TABLE notas_sap ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks_notas_sap ENABLE ROW LEVEL SECURITY;

-- Política para notas_sap: todos podem ler, apenas autenticados podem escrever
CREATE POLICY "Notas SAP são visíveis para todos"
  ON notas_sap FOR SELECT
  USING (true);

CREATE POLICY "Apenas autenticados podem inserir notas SAP"
  ON notas_sap FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Apenas autenticados podem atualizar notas SAP"
  ON notas_sap FOR UPDATE
  USING (auth.role() = 'authenticated');

CREATE POLICY "Apenas autenticados podem deletar notas SAP"
  ON notas_sap FOR DELETE
  USING (auth.role() = 'authenticated');

-- Política para tasks_notas_sap: todos podem ler, apenas autenticados podem escrever
CREATE POLICY "Vínculos tasks_notas_sap são visíveis para todos"
  ON tasks_notas_sap FOR SELECT
  USING (true);

CREATE POLICY "Apenas autenticados podem inserir vínculos tasks_notas_sap"
  ON tasks_notas_sap FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Apenas autenticados podem deletar vínculos tasks_notas_sap"
  ON tasks_notas_sap FOR DELETE
  USING (auth.role() = 'authenticated');

-- Comentários nas colunas
COMMENT ON TABLE notas_sap IS 'Notas importadas do sistema SAP';
COMMENT ON COLUMN notas_sap.nota IS 'Número único da nota SAP (chave única)';
COMMENT ON COLUMN notas_sap.data_importacao IS 'Data/hora em que a nota foi importada do CSV';

