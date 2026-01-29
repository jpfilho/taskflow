-- Criar VIEW que retorna ordens com coluna 'local' calculada automaticamente
-- Inclui também todos os campos da tabela ordens (ex.: tolerancia/prazo)
-- A coluna 'local' será preenchida quando local_instalacao_sap da tabela locais
-- estiver contido no local_instalacao da ordem.
--
-- POR QUE OS DADOS NÃO VÊM DA VIEW? Porque esta VIEW precisa existir no banco.
-- Execute este script no SQL Editor do Supabase (Dashboard > SQL Editor).
-- Ou use a migration: supabase/migrations/20260128_ordens_com_local_view.sql

-- Garantir colunas usadas pela VIEW na tabela ordens (se não existirem)
ALTER TABLE public.ordens
  ADD COLUMN IF NOT EXISTS tolerancia DATE,
  ADD COLUMN IF NOT EXISTS centro_trabalho_responsavel TEXT,
  ADD COLUMN IF NOT EXISTS sala TEXT;

-- Remover a VIEW se já existir
DROP VIEW IF EXISTS public.ordens_com_local;

-- Criar a VIEW (definição igual à do banco)
CREATE VIEW public.ordens_com_local AS
SELECT
  o.id,
  o.ordem,
  o.inicio_base,
  o.fim_base,
  o.tipo,
  o.status_sistema,
  o.denominacao_local_instalacao,
  o.denominacao_objeto,
  o.texto_breve,
  o.tolerancia,
  o.local_instalacao,
  o.centro_trabalho_responsavel,
  o.sala,
  o.status_usuario,
  o.codigo_si,
  o.gpm,
  o.data_importacao,
  o.created_at,
  o.updated_at,
  l.local
FROM public.ordens o
LEFT JOIN public.locais l ON l.local_instalacao_sap IS NOT NULL
  AND TRIM(BOTH FROM l.local_instalacao_sap) <> ''::text
  AND o.local_instalacao IS NOT NULL
  AND o.local_instalacao ~~ (('%'::text || l.local_instalacao_sap) || '%'::text);

-- Comentário na VIEW
COMMENT ON VIEW public.ordens_com_local IS 
'VIEW que retorna todas as ordens com uma coluna adicional "local" que corresponde ao local da tabela locais quando o local_instalacao_sap está contido no local_instalacao da ordem.';

-- Garantir permissões (ajustar conforme necessário)
GRANT SELECT ON public.ordens_com_local TO authenticated;
GRANT SELECT ON public.ordens_com_local TO anon;

-- Recarregar o schema do PostgREST
NOTIFY pgrst, 'reload schema';

-- Exemplo de uso:
-- SELECT * FROM ordens_com_local WHERE local IS NOT NULL LIMIT 10;
