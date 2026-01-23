-- ============================================
-- SQL PARA CRIAR TABELAS DE PEX, APR E CRC
-- ============================================

-- Tabela para PEX (Planejamento Executivo)
CREATE TABLE IF NOT EXISTS pex (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  
  -- Cabeçalho
  numero_pex VARCHAR(50),
  si VARCHAR(50), -- SI relacionada
  revisao_pex INTEGER DEFAULT 1,
  data_elaboracao DATE,
  
  -- 1. IDENTIFICAÇÃO DA INTERVENÇÃO
  responsavel_nome VARCHAR(255),
  responsavel_id_sap VARCHAR(50),
  responsavel_contato VARCHAR(50),
  substituto_nome VARCHAR(255),
  substituto_id_sap VARCHAR(50),
  substituto_contato VARCHAR(50),
  fiscal_tecnico_nome VARCHAR(255),
  fiscal_tecnico_id_sap VARCHAR(50),
  fiscal_tecnico_contato VARCHAR(50),
  coordenador_nome VARCHAR(255),
  coordenador_id_sap VARCHAR(50),
  coordenador_contato VARCHAR(50),
  tecnico_seg_nome VARCHAR(255),
  tecnico_seg_id_sap VARCHAR(50),
  tecnico_seg_contato VARCHAR(50),
  
  -- Período
  data_inicio DATE,
  hora_inicio TIME,
  data_fim DATE,
  hora_fim TIME,
  periodicidade BOOLEAN DEFAULT FALSE,
  continuo BOOLEAN DEFAULT FALSE,
  
  -- Instalação e Equipamentos
  instalacao VARCHAR(255),
  equipamentos TEXT,
  
  -- Resumo da Atividade
  resumo_atividade TEXT,
  
  -- Configuração
  configuracao_recebimento TEXT,
  configuracao_durante TEXT,
  configuracao_devolucao TEXT,
  
  -- Aterramento
  aterramento_descricao TEXT,
  aterramento_total_unidades INTEGER,
  
  -- Informações adicionais
  informacoes_adicionais TEXT,
  
  -- Distâncias de Segurança (JSON)
  distancias_seguranca TEXT, -- JSON com tabela de distâncias
  
  -- 2. DADOS PARA PLANEJAMENTO DA INTERVENÇÃO (JSON)
  dados_planejamento TEXT, -- JSON com categorias e instruções
  
  -- 3. RECURSOS / FERRAMENTAS / MATERIAIS (JSON)
  recursos_epi TEXT, -- JSON com lista de EPIs
  recursos_epc TEXT, -- JSON com lista de EPCs
  recursos_transporte TEXT, -- JSON com lista de transporte/máquinas
  recursos_material_consumo TEXT, -- JSON com lista de materiais
  recursos_ferramentas TEXT, -- JSON com lista de ferramentas
  recursos_comunicacao TEXT, -- JSON com lista de comunicação
  recursos_documentacao TEXT, -- JSON com lista de documentação
  recursos_instrumentos TEXT, -- JSON com lista de instrumentos
  
  -- 4. DETALHAMENTO DA INTERVENÇÃO (JSON)
  detalhamento_intervencao TEXT, -- JSON com lista de atividades
  
  -- 5. RECURSOS HUMANOS E CIÊNCIA DOS RISCOS (JSON)
  recursos_humanos TEXT, -- JSON com lista de pessoas
  
  -- Nível de risco
  nivel_risco VARCHAR(50), -- Baixo, Moderado (Médio), Alto, etc.
  
  -- Aprovação
  aprovador VARCHAR(255),
  data_aprovacao DATE,
  
  -- Status
  status VARCHAR(50) DEFAULT 'rascunho', -- rascunho, aprovado, em_execucao, concluido
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(task_id) -- Uma tarefa pode ter apenas um PEX
);

-- Tabela para APR (Análise Preliminar de Risco)
CREATE TABLE IF NOT EXISTS apr (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  
  -- Informações Gerais
  numero_apr VARCHAR(50),
  data_elaboracao DATE,
  responsavel_elaboracao VARCHAR(255),
  aprovador VARCHAR(255),
  data_aprovacao DATE,
  
  -- Dados da Atividade
  atividade TEXT,
  local_execucao TEXT,
  data_execucao DATE,
  equipe_executora TEXT,
  coordenador_atividade VARCHAR(255),
  
  -- Análise de Riscos (pode ser uma lista de riscos)
  riscos_identificados TEXT, -- JSON ou texto estruturado
  
  -- Medidas de Controle
  medidas_controle TEXT, -- JSON ou texto estruturado
  
  -- EPIs Necessários
  epis_necessarios TEXT,
  
  -- Permissões e Autorizações
  permissoes_necessarias TEXT,
  autorizacoes_necessarias TEXT,
  
  -- Procedimentos de Emergência
  procedimentos_emergencia TEXT,
  
  -- Observações
  observacoes TEXT,
  
  -- Status
  status VARCHAR(50) DEFAULT 'rascunho', -- rascunho, aprovado, em_execucao, concluido
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(task_id) -- Uma tarefa pode ter apenas uma APR
);

-- Tabela para CRC (Controle de Pontos Críticos)
CREATE TABLE IF NOT EXISTS crc (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  
  -- Informações Gerais
  numero_crc VARCHAR(50),
  data_elaboracao DATE,
  responsavel_elaboracao VARCHAR(255),
  aprovador VARCHAR(255),
  data_aprovacao DATE,
  
  -- Dados da Atividade
  atividade TEXT,
  local_execucao TEXT,
  data_execucao DATE,
  equipe_executora TEXT,
  coordenador_atividade VARCHAR(255),
  
  -- Pontos Críticos (pode ser uma lista de pontos)
  pontos_criticos TEXT, -- JSON ou texto estruturado
  
  -- Controles
  controles TEXT, -- JSON ou texto estruturado
  
  -- Verificações
  verificacoes TEXT, -- JSON ou texto estruturado
  
  -- Responsáveis
  responsaveis_verificacao TEXT,
  
  -- Observações
  observacoes TEXT,
  
  -- Status
  status VARCHAR(50) DEFAULT 'rascunho', -- rascunho, aprovado, em_execucao, concluido
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(task_id) -- Uma tarefa pode ter apenas um CRC
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_pex_task_id ON pex(task_id);
CREATE INDEX IF NOT EXISTS idx_apr_task_id ON apr(task_id);
CREATE INDEX IF NOT EXISTS idx_crc_task_id ON crc(task_id);

-- Funções para atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION update_pex_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_apr_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_crc_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers para atualizar updated_at
CREATE TRIGGER trigger_update_pex_updated_at
  BEFORE UPDATE ON pex
  FOR EACH ROW
  EXECUTE FUNCTION update_pex_updated_at();

CREATE TRIGGER trigger_update_apr_updated_at
  BEFORE UPDATE ON apr
  FOR EACH ROW
  EXECUTE FUNCTION update_apr_updated_at();

CREATE TRIGGER trigger_update_crc_updated_at
  BEFORE UPDATE ON crc
  FOR EACH ROW
  EXECUTE FUNCTION update_crc_updated_at();

-- Habilitar RLS (Row Level Security)
ALTER TABLE pex ENABLE ROW LEVEL SECURITY;
ALTER TABLE apr ENABLE ROW LEVEL SECURITY;
ALTER TABLE crc ENABLE ROW LEVEL SECURITY;

-- Políticas para permitir todas as operações (ajuste conforme necessário)
CREATE POLICY "Permitir todas as operações em pex" ON pex
  FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Permitir todas as operações em apr" ON apr
  FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Permitir todas as operações em crc" ON crc
  FOR ALL USING (true) WITH CHECK (true);

-- Comentários
COMMENT ON TABLE pex IS 'Planejamento Executivo (PEX) para tarefas';
COMMENT ON TABLE apr IS 'Análise Preliminar de Risco (APR) para tarefas';
COMMENT ON TABLE crc IS 'Controle de Pontos Críticos (CRC) para tarefas';
