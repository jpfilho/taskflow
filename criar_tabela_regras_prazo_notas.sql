-- Tabela de regras de prazo para notas SAP
-- Define quantos dias uma nota tem para ser concluída baseado na prioridade
-- A data de referência pode ser a data de criação ou o início desejado

CREATE TABLE IF NOT EXISTS regras_prazo_notas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prioridade VARCHAR(50) NOT NULL, -- Alta, Baixa, Emergência, Média, Monitoramento, Por Oportunidade, Urgência
  dias_prazo INTEGER NOT NULL CHECK (dias_prazo > 0), -- Quantidade de dias para conclusão
  data_referencia VARCHAR(20) NOT NULL CHECK (data_referencia IN ('criacao', 'inicio_desejado')), -- Data base para cálculo
  -- Segmentos são relacionados via tabela de junção regras_prazo_notas_segmentos
  -- Se não houver segmentos na tabela de junção, a regra se aplica a todos os segmentos
  ativo BOOLEAN DEFAULT true, -- Se a regra está ativa
  descricao TEXT, -- Descrição opcional da regra
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_regras_prazo_notas_prioridade ON regras_prazo_notas(prioridade);
CREATE INDEX IF NOT EXISTS idx_regras_prazo_notas_ativo ON regras_prazo_notas(ativo);
CREATE INDEX IF NOT EXISTS idx_regras_prazo_notas_data_referencia ON regras_prazo_notas(data_referencia);

-- Constraint parcial: uma prioridade pode ter apenas uma regra ativa por data_referencia
-- Se a regra não tiver segmentos específicos (todos os segmentos), só pode haver uma regra ativa
-- Se tiver segmentos específicos, pode haver múltiplas regras ativas (uma por combinação de segmentos)
-- A validação de unicidade será feita no código da aplicação

-- Trigger para atualizar updated_at automaticamente
CREATE TRIGGER update_regras_prazo_notas_updated_at BEFORE UPDATE ON regras_prazo_notas
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Políticas RLS (Row Level Security)
ALTER TABLE regras_prazo_notas ENABLE ROW LEVEL SECURITY;

-- Política para permitir todas as operações
CREATE POLICY "Permitir todas as operações em regras_prazo_notas" ON regras_prazo_notas
  FOR ALL USING (true) WITH CHECK (true);

-- Comentários na tabela
COMMENT ON TABLE regras_prazo_notas IS 'Tabela de regras de prazo para notas SAP baseado na prioridade';
COMMENT ON COLUMN regras_prazo_notas.prioridade IS 'Prioridade da nota (Alta, Baixa, Emergência, Média, Monitoramento, Por Oportunidade, Urgência)';
COMMENT ON COLUMN regras_prazo_notas.dias_prazo IS 'Quantidade de dias para conclusão da nota';
COMMENT ON COLUMN regras_prazo_notas.data_referencia IS 'Data base para cálculo: criacao (data de criação) ou inicio_desejado (início desejado)';
COMMENT ON COLUMN regras_prazo_notas.ativo IS 'Se a regra está ativa e deve ser aplicada. Segmentos são relacionados via tabela regras_prazo_notas_segmentos. Se não houver segmentos relacionados, a regra se aplica a todos.';
COMMENT ON COLUMN regras_prazo_notas.ativo IS 'Se a regra está ativa e deve ser aplicada';

-- Recarregar o schema do PostgREST para que a nova tabela seja reconhecida
NOTIFY pgrst, 'reload schema';
