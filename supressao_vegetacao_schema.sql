-- Supressão de Vegetação em Linhas de Transmissão
-- Estrutura inicial para importar a planilha "NOVA PLANILHA MAPEAMENTO OOTFA.C OUTRUBRO 2025 (1).xlsx"
-- Ajuste conforme necessário.

-- Tabela de linhas de transmissão
CREATE TABLE IF NOT EXISTS public.linhas_transmissao (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nome TEXT NOT NULL,
  tensao_kv NUMERIC(10,2),
  uf TEXT,
  concessionaria TEXT,
  segmento TEXT NOT NULL DEFAULT 'Linhas de Transmissao',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabela de vãos / supressão
CREATE TABLE IF NOT EXISTS public.vaos_supressao (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  linha_id UUID NOT NULL REFERENCES public.linhas_transmissao(id) ON DELETE CASCADE,
  est_codigo TEXT NOT NULL, -- coluna EST.
  vao_frente_m NUMERIC(14,3), -- Vão de Frente (m)
  vao_largura_m NUMERIC(14,3), -- Largura (m)
  map_mec_extensao_m NUMERIC(14,3), -- Mapeamento Mec. Extensão
  map_mec_largura_m NUMERIC(14,3), -- Largura
  map_data DATE, -- Data do mapeamento (manual e mecanizado, mesmo dia)
  map_man_extensao_m NUMERIC(14,3), -- Mapeamento Man. Extensão
  map_man_largura_m NUMERIC(14,3), -- Largura .1
  exec_mec_extensao_m NUMERIC(14,3), -- Execução Mec. Extensão
  exec_mec_largura_m NUMERIC(14,3), -- Largura .2
  exec_mec_data DATE, -- Data conclusão
  exec_man_extensao_m NUMERIC(14,3), -- Execução Man. Extensão
  exec_man_largura_m NUMERIC(14,3), -- Largura .3
  exec_man_data DATE, -- Data conclusão.1
  vao_data_conclusao DATE, -- DATA CONCLUSÃO DO VÃO
  roco_concluido BOOLEAN, -- ROÇO CONCLUÍDO: SIM / NÃO ?
  numeracao_ggt TEXT, -- Numeração GGT
  mapeamento_ggt TEXT, -- MAPEAMENTO GGT
  codigo_ggt_execucao TEXT, -- CÓDIGO GGT (execução)
  descricao_servicos TEXT, -- DESCRIÇÃO DOS SERVIÇOS
  prioridade TEXT, -- PRIORIDADE
  conferencia_vao TEXT, -- Conferência do Vão Sobra (-) ou Falta (+)
  pend_manual TEXT, -- Manual
  pend_mecanizado TEXT, -- Mecanizado
  pend_seletivo TEXT, -- Seletivo / Preservação / Cultivado
  pend_manual_extra TEXT, -- Manual (segunda coluna)
  pend_mecanizado_extra TEXT, -- Mecanizado (segunda coluna)
  pend_seletivo_extra TEXT, -- Seletivo / Preservação / Cultivado (segunda)
  pendencias_execucao TEXT, -- PENDÊNCIAS NA EXECUÇÃO DO ROÇO
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (linha_id, est_codigo)
);

-- Log de importações
CREATE TABLE IF NOT EXISTS public.importacoes_supressao (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  filename TEXT NOT NULL,
  filepath TEXT,
  status TEXT NOT NULL DEFAULT 'pending', -- pending, success, error
  imported_at TIMESTAMPTZ,
  log TEXT
);

-- Índices de apoio
CREATE INDEX IF NOT EXISTS idx_vaos_supressao_linha ON public.vaos_supressao(linha_id);
CREATE INDEX IF NOT EXISTS idx_vaos_supressao_prioridade ON public.vaos_supressao(prioridade);
CREATE INDEX IF NOT EXISTS idx_vaos_supressao_roco_concluido ON public.vaos_supressao(roco_concluido);

-- View de resumo por linha
CREATE OR REPLACE VIEW public.vw_supressao_resumo AS
SELECT
  lt.id AS linha_id,
  lt.nome AS linha,
  lt.tensao_kv,
  lt.uf,
  lt.concessionaria,
  COUNT(v.id) AS total_vaos,
  COUNT(v.id) FILTER (WHERE v.roco_concluido = TRUE) AS vaos_concluidos,
  COUNT(v.id) FILTER (WHERE v.roco_concluido = FALSE OR v.roco_concluido IS NULL) AS vaos_pendentes,
  ROUND(
    CASE WHEN COUNT(v.id) = 0 THEN 0
         ELSE (COUNT(v.id) FILTER (WHERE v.roco_concluido = TRUE)::NUMERIC / COUNT(v.id)) * 100
    END, 2
  ) AS perc_concluido
FROM public.linhas_transmissao lt
LEFT JOIN public.vaos_supressao v ON v.linha_id = lt.id
GROUP BY lt.id, lt.nome, lt.tensao_kv, lt.uf, lt.concessionaria;

