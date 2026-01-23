-- Tabela de junção para relacionamento many-to-many entre regras_prazo_notas e segmentos
-- Permite que uma regra se aplique a múltiplos segmentos específicos

CREATE TABLE IF NOT EXISTS regras_prazo_notas_segmentos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  regra_prazo_nota_id UUID NOT NULL REFERENCES regras_prazo_notas(id) ON DELETE CASCADE,
  segmento_id UUID NOT NULL REFERENCES segmentos(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(regra_prazo_nota_id, segmento_id) -- Evitar duplicatas
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_regras_prazo_notas_segmentos_regra_id ON regras_prazo_notas_segmentos(regra_prazo_nota_id);
CREATE INDEX IF NOT EXISTS idx_regras_prazo_notas_segmentos_segmento_id ON regras_prazo_notas_segmentos(segmento_id);

-- Políticas RLS (Row Level Security)
ALTER TABLE regras_prazo_notas_segmentos ENABLE ROW LEVEL SECURITY;

-- Política para permitir todas as operações
CREATE POLICY "Permitir todas as operações em regras_prazo_notas_segmentos" ON regras_prazo_notas_segmentos
  FOR ALL USING (true) WITH CHECK (true);

-- Comentários na tabela
COMMENT ON TABLE regras_prazo_notas_segmentos IS 'Relacionamento many-to-many entre regras de prazo e segmentos';
COMMENT ON COLUMN regras_prazo_notas_segmentos.regra_prazo_nota_id IS 'ID da regra de prazo';
COMMENT ON COLUMN regras_prazo_notas_segmentos.segmento_id IS 'ID do segmento';

-- Recarregar o schema do PostgREST para que a nova tabela seja reconhecida
NOTIFY pgrst, 'reload schema';
