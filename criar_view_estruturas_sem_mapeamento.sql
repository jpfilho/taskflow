-- View para identificar estruturas que não aparecem no mapeamento (vaos_supressao)
-- Premissa: cada combinação lt/estrutura em `estruturas` deve existir em `vaos_supressao`
--           (supondo colunas lt e estrutura em vaos_supressao; ajuste os nomes se divergirem)

CREATE OR REPLACE VIEW public.estruturas_sem_mapeamento AS
SELECT 
  e.*,
  lt.nome AS lt_mapeamento
FROM public.estruturas e
LEFT JOIN public.vaos_supressao v
  ON v.est_codigo = e.estrutura
LEFT JOIN public.linhas_transmissao lt
  ON lt.id = v.linha_id
  AND lt.nome = e.lt
WHERE lt.id IS NULL;

COMMENT ON VIEW public.estruturas_sem_mapeamento IS
'Lista estruturas sem correspondência no mapeamento (vaos_supressao.est_codigo + linha_id ligado a linhas_transmissao.nome).';
