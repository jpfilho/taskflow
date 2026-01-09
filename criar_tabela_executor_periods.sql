-- ============================================
-- TABELA PARA PERÍODOS ESPECÍFICOS POR EXECUTOR
-- ============================================
-- Esta tabela permite que cada executor tenha períodos diferentes dentro da mesma tarefa

CREATE TABLE IF NOT EXISTS executor_periods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  executor_id UUID NOT NULL REFERENCES executores(id) ON DELETE CASCADE,
  executor_nome VARCHAR(200) NOT NULL, -- Cache do nome para performance
  data_inicio TIMESTAMPTZ NOT NULL,
  data_fim TIMESTAMPTZ NOT NULL,
  label VARCHAR(200),
  tipo VARCHAR(10) NOT NULL CHECK (tipo IN ('BEA', 'FER', 'COMP', 'TRN', 'BSL', 'APO', 'OUT', 'ADM')),
  tipo_periodo VARCHAR(20) DEFAULT 'EXECUCAO' CHECK (tipo_periodo IN ('EXECUCAO', 'PLANEJAMENTO', 'DESLOCAMENTO')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT valid_date_range CHECK (data_fim >= data_inicio),
  CONSTRAINT unique_executor_period UNIQUE(task_id, executor_id, data_inicio, data_fim)
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_executor_periods_task_id ON executor_periods(task_id);
CREATE INDEX IF NOT EXISTS idx_executor_periods_executor_id ON executor_periods(executor_id);
CREATE INDEX IF NOT EXISTS idx_executor_periods_dates ON executor_periods(data_inicio, data_fim);

-- Comentários
COMMENT ON TABLE executor_periods IS 'Armazena períodos específicos de trabalho para cada executor em uma tarefa';
COMMENT ON COLUMN executor_periods.executor_nome IS 'Nome do executor (cache para evitar joins frequentes)';
COMMENT ON COLUMN executor_periods.tipo_periodo IS 'Tipo do período: EXECUCAO, PLANEJAMENTO ou DESLOCAMENTO';
