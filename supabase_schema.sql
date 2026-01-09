-- ============================================
-- SCHEMA DO SUPABASE PARA O PROJETO TASK2026
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new

-- Tabela principal de tarefas
CREATE TABLE IF NOT EXISTS tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  status VARCHAR(10) NOT NULL CHECK (status IN ('ANDA', 'CONC', 'PROG')),
  regional VARCHAR(100) NOT NULL,
  divisao VARCHAR(100) NOT NULL,
  local VARCHAR(200) NOT NULL,
  tipo VARCHAR(50) NOT NULL,
  ordem VARCHAR(50) NOT NULL,
  tarefa TEXT NOT NULL,
  executor VARCHAR(200) NOT NULL,
  frota VARCHAR(100),
  coordenador VARCHAR(200) NOT NULL,
  si VARCHAR(100),
  data_inicio TIMESTAMPTZ NOT NULL,
  data_fim TIMESTAMPTZ NOT NULL,
  observacoes TEXT,
  horas_previstas DECIMAL(10, 2),
  horas_executadas DECIMAL(10, 2),
  prioridade VARCHAR(10) CHECK (prioridade IN ('ALTA', 'MEDIA', 'BAIXA')),
  parent_id UUID REFERENCES tasks(id) ON DELETE CASCADE,
  data_criacao TIMESTAMPTZ DEFAULT NOW(),
  data_atualizacao TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabela de segmentos do Gantt
CREATE TABLE IF NOT EXISTS gantt_segments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  data_inicio TIMESTAMPTZ NOT NULL,
  data_fim TIMESTAMPTZ NOT NULL,
  label VARCHAR(200),
  tipo VARCHAR(10) NOT NULL CHECK (tipo IN ('BEA', 'FER', 'COMP', 'TRN', 'BSL', 'APO', 'OUT', 'ADM')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT valid_date_range CHECK (data_fim >= data_inicio)
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_tasks_parent_id ON tasks(parent_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_regional ON tasks(regional);
CREATE INDEX IF NOT EXISTS idx_tasks_data_inicio ON tasks(data_inicio);
CREATE INDEX IF NOT EXISTS idx_tasks_data_fim ON tasks(data_fim);
CREATE INDEX IF NOT EXISTS idx_gantt_segments_task_id ON gantt_segments(task_id);
CREATE INDEX IF NOT EXISTS idx_gantt_segments_data_inicio ON gantt_segments(data_inicio);

-- Função para atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  NEW.data_atualizacao = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers para atualizar updated_at automaticamente
CREATE TRIGGER update_tasks_updated_at BEFORE UPDATE ON tasks
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_gantt_segments_updated_at BEFORE UPDATE ON gantt_segments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Políticas RLS (Row Level Security)
-- Habilitar RLS
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE gantt_segments ENABLE ROW LEVEL SECURITY;

-- Política para permitir todas as operações (ajuste conforme necessário)
-- Para produção, você deve criar políticas mais restritivas
CREATE POLICY "Permitir todas as operações em tasks" ON tasks
  FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Permitir todas as operações em gantt_segments" ON gantt_segments
  FOR ALL USING (true) WITH CHECK (true);

-- Comentários nas tabelas
COMMENT ON TABLE tasks IS 'Tabela principal de tarefas do sistema';
COMMENT ON TABLE gantt_segments IS 'Segmentos do gráfico Gantt associados às tarefas';

COMMENT ON COLUMN tasks.parent_id IS 'ID da tarefa pai (null para tarefas principais)';
COMMENT ON COLUMN tasks.status IS 'Status da tarefa: ANDA (Em Andamento), CONC (Concluída), PROG (Programada)';
COMMENT ON COLUMN tasks.prioridade IS 'Prioridade: ALTA, MEDIA, BAIXA';
COMMENT ON COLUMN gantt_segments.tipo IS 'Tipo do segmento: BEA, FER, COMP, TRN, BSL, APO, OUT, ADM';

-- Tabela de regionais
CREATE TABLE IF NOT EXISTS regionais (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  regional VARCHAR(100) NOT NULL UNIQUE,
  divisao VARCHAR(100) NOT NULL,
  empresa VARCHAR(200) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_regionais_regional ON regionais(regional);
CREATE INDEX IF NOT EXISTS idx_regionais_divisao ON regionais(divisao);
CREATE INDEX IF NOT EXISTS idx_regionais_empresa ON regionais(empresa);

-- Trigger para atualizar updated_at automaticamente
CREATE TRIGGER update_regionais_updated_at BEFORE UPDATE ON regionais
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Políticas RLS (Row Level Security)
ALTER TABLE regionais ENABLE ROW LEVEL SECURITY;

-- Política para permitir todas as operações
CREATE POLICY "Permitir todas as operações em regionais" ON regionais
  FOR ALL USING (true) WITH CHECK (true);

-- Comentários na tabela
COMMENT ON TABLE regionais IS 'Tabela de cadastro de regionais com divisão e empresa';

-- Tabela de status
CREATE TABLE IF NOT EXISTS status (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo VARCHAR(4) NOT NULL UNIQUE,
  status VARCHAR(100) NOT NULL,
  cor VARCHAR(7) DEFAULT '#2196F3',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_status_codigo ON status(codigo);
CREATE INDEX IF NOT EXISTS idx_status_status ON status(status);

-- Trigger para atualizar updated_at automaticamente
CREATE TRIGGER update_status_updated_at BEFORE UPDATE ON status
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Políticas RLS (Row Level Security)
ALTER TABLE status ENABLE ROW LEVEL SECURITY;

-- Política para permitir todas as operações
CREATE POLICY "Permitir todas as operações em status" ON status
  FOR ALL USING (true) WITH CHECK (true);

-- Comentários na tabela
COMMENT ON TABLE status IS 'Tabela de cadastro de status com código e descrição';
COMMENT ON COLUMN status.codigo IS 'Código do status (4 caracteres, único)';
COMMENT ON COLUMN status.status IS 'Nome/descrição do status';
COMMENT ON COLUMN status.cor IS 'Cor do status em formato hexadecimal (ex: #FF5733)';

-- Tabela de divisões
-- IMPORTANTE: A tabela segmentos deve ser criada ANTES desta
-- Uma regional pode ter várias divisões
-- Uma divisão pode ter vários segmentos (relacionamento many-to-many via divisoes_segmentos)
-- O nome da divisão deve ser único APENAS dentro da mesma regional
CREATE TABLE IF NOT EXISTS divisoes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  divisao VARCHAR(100) NOT NULL,
  regional_id UUID NOT NULL REFERENCES regionais(id) ON DELETE CASCADE,
  -- NOTA: segmento_id foi removido. Use a tabela divisoes_segmentos para relacionamentos many-to-many
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  -- Constraint UNIQUE composta: divisão única por regional
  UNIQUE(divisao, regional_id)
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_divisoes_divisao ON divisoes(divisao);
CREATE INDEX IF NOT EXISTS idx_divisoes_regional_id ON divisoes(regional_id);

-- Trigger para atualizar updated_at automaticamente
CREATE TRIGGER update_divisoes_updated_at BEFORE UPDATE ON divisoes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Políticas RLS (Row Level Security)
ALTER TABLE divisoes ENABLE ROW LEVEL SECURITY;

-- Política para permitir todas as operações
CREATE POLICY "Permitir todas as operações em divisoes" ON divisoes
  FOR ALL USING (true) WITH CHECK (true);

-- Comentários na tabela
COMMENT ON TABLE divisoes IS 'Tabela de cadastro de divisões com regional e segmento';
COMMENT ON COLUMN divisoes.divisao IS 'Nome da divisão';
COMMENT ON COLUMN divisoes.regional_id IS 'ID da regional associada';
COMMENT ON COLUMN divisoes.segmento_id IS 'ID do segmento associado';

-- Tabela de segmentos
CREATE TABLE IF NOT EXISTS segmentos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  segmento VARCHAR(200) NOT NULL,
  descricao TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_segmentos_segmento ON segmentos(segmento);

-- Trigger para atualizar updated_at automaticamente
CREATE TRIGGER update_segmentos_updated_at BEFORE UPDATE ON segmentos
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Políticas RLS (Row Level Security)
ALTER TABLE segmentos ENABLE ROW LEVEL SECURITY;

-- Política para permitir todas as operações
CREATE POLICY "Permitir todas as operações em segmentos" ON segmentos
  FOR ALL USING (true) WITH CHECK (true);

-- Comentários na tabela
COMMENT ON TABLE segmentos IS 'Tabela de cadastro de segmentos';
COMMENT ON COLUMN segmentos.segmento IS 'Nome do segmento';
COMMENT ON COLUMN segmentos.descricao IS 'Descrição do segmento';

-- Tabela de locais
-- IMPORTANTE: As tabelas regionais, divisoes e segmentos devem existir antes
CREATE TABLE IF NOT EXISTS locais (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  local VARCHAR(200) NOT NULL,
  descricao TEXT,
  -- Flags para associação ampla
  para_toda_regional BOOLEAN DEFAULT FALSE,
  para_toda_divisao BOOLEAN DEFAULT FALSE,
  -- Associações específicas (nullable - pode ser NULL se for para toda regional/divisão)
  regional_id UUID REFERENCES regionais(id) ON DELETE CASCADE,
  divisao_id UUID REFERENCES divisoes(id) ON DELETE CASCADE,
  segmento_id UUID REFERENCES segmentos(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  -- Constraint: se não for para toda regional/divisão, deve ter pelo menos uma associação específica
  CONSTRAINT locais_associacao_check CHECK (
    para_toda_regional = TRUE OR 
    para_toda_divisao = TRUE OR 
    regional_id IS NOT NULL OR 
    divisao_id IS NOT NULL OR 
    segmento_id IS NOT NULL
  )
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_locais_local ON locais(local);
CREATE INDEX IF NOT EXISTS idx_locais_regional_id ON locais(regional_id);
CREATE INDEX IF NOT EXISTS idx_locais_divisao_id ON locais(divisao_id);
CREATE INDEX IF NOT EXISTS idx_locais_segmento_id ON locais(segmento_id);
CREATE INDEX IF NOT EXISTS idx_locais_para_toda_regional ON locais(para_toda_regional);
CREATE INDEX IF NOT EXISTS idx_locais_para_toda_divisao ON locais(para_toda_divisao);

-- Trigger para atualizar updated_at automaticamente
CREATE TRIGGER update_locais_updated_at BEFORE UPDATE ON locais
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Políticas RLS (Row Level Security)
ALTER TABLE locais ENABLE ROW LEVEL SECURITY;

-- Política para permitir todas as operações
CREATE POLICY "Permitir todas as operações em locais" ON locais
  FOR ALL USING (true) WITH CHECK (true);

-- Comentários na tabela
COMMENT ON TABLE locais IS 'Tabela de cadastro de locais com associações flexíveis';
COMMENT ON COLUMN locais.local IS 'Nome do local';
COMMENT ON COLUMN locais.descricao IS 'Descrição do local';
COMMENT ON COLUMN locais.para_toda_regional IS 'Se TRUE, o local se aplica a toda a regional';
COMMENT ON COLUMN locais.para_toda_divisao IS 'Se TRUE, o local se aplica a toda a divisão';
COMMENT ON COLUMN locais.regional_id IS 'ID da regional específica (se não for para toda regional)';
COMMENT ON COLUMN locais.divisao_id IS 'ID da divisão específica (se não for para toda divisão)';
COMMENT ON COLUMN locais.segmento_id IS 'ID do segmento específico';



