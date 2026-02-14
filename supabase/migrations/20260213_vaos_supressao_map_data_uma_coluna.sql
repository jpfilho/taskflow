-- Se você já rodou 20260212 com map_mec_data e map_man_data, use esta migration para uma única coluna map_data
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'vaos_supressao' AND column_name = 'map_man_data'
  ) THEN
    ALTER TABLE public.vaos_supressao DROP COLUMN map_man_data;
  END IF;
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'vaos_supressao' AND column_name = 'map_mec_data'
  ) THEN
    ALTER TABLE public.vaos_supressao RENAME COLUMN map_mec_data TO map_data;
  ELSIF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'vaos_supressao' AND column_name = 'map_data'
  ) THEN
    ALTER TABLE public.vaos_supressao ADD COLUMN map_data DATE;
  END IF;
END $$;

DROP VIEW IF EXISTS public.vw_mapeamento_completo;

CREATE VIEW public.vw_mapeamento_completo AS
SELECT
  e.id AS estrutura_id,
  e.lt,
  e.estrutura AS est_codigo,
  e.familia,
  e.tipo,
  e.progressiva,
  e.vao_m,
  e.altura_util_m,
  e.deflexao,
  e.equipe,
  e.geo_lat,
  e.geo_lon,
  e.numeracao_antiga,
  v.id AS vao_id,
  v.linha_id,
  v.vao_frente_m,
  v.vao_largura_m,
  v.map_mec_extensao_m,
  v.map_mec_largura_m,
  v.map_man_extensao_m,
  v.map_man_largura_m,
  v.map_data,
  v.exec_mec_extensao_m,
  v.exec_mec_largura_m,
  v.exec_mec_data,
  v.exec_man_extensao_m,
  v.exec_man_largura_m,
  v.exec_man_data,
  v.vao_data_conclusao,
  v.roco_concluido,
  v.numeracao_ggt,
  v.mapeamento_ggt,
  v.codigo_ggt_execucao,
  v.descricao_servicos,
  v.prioridade,
  v.conferencia_vao,
  v.pend_manual,
  v.pend_mecanizado,
  v.pend_seletivo,
  v.pend_manual_extra,
  v.pend_mecanizado_extra,
  v.pend_seletivo_extra,
  v.pendencias_execucao,
  v.created_at AS vao_created_at
FROM public.estruturas e
LEFT JOIN public.vaos_supressao v
  ON v.est_codigo = e.estrutura
  AND v.linha_id = (SELECT id FROM public.linhas_transmissao lt WHERE lt.nome = e.lt LIMIT 1);

COMMENT ON VIEW public.vw_mapeamento_completo IS
'Lista completa de LT/Estruturas unidas ao mapeamento (vaos_supressao); traz todas as estruturas, mesmo sem registro de mapeamento.';
