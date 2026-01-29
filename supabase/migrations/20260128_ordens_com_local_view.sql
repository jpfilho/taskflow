-- ============================================
-- VIEW ordens_com_local: para os dados virem da VIEW (coluna local + filtro centro)
-- ============================================
-- O app usa ordens_com_local primeiro; se não existir, cai na tabela ordens e
-- a coluna Local fica vazia e o filtro por centro_trabalho_responsavel falha.
-- Execute este script no SQL Editor do Supabase (ou aplique a migration).
-- ============================================

-- 1) Garantir colunas usadas pela VIEW na tabela ordens (se não existirem)
ALTER TABLE public.ordens
  ADD COLUMN IF NOT EXISTS tolerancia DATE,
  ADD COLUMN IF NOT EXISTS centro_trabalho_responsavel TEXT,
  ADD COLUMN IF NOT EXISTS sala TEXT;

COMMENT ON COLUMN public.ordens.tolerancia IS 'Data limite/prazo da ordem';
COMMENT ON COLUMN public.ordens.centro_trabalho_responsavel IS 'Centro de trabalho responsável (filtro por perfil)';
COMMENT ON COLUMN public.ordens.sala IS 'Sala da instalação';

-- 2) Remover a VIEW se já existir (para recriar)
DROP VIEW IF EXISTS public.ordens_com_local;

-- 3) Criar a VIEW (definição igual à do banco: ordens + coluna local da tabela locais)
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

COMMENT ON VIEW public.ordens_com_local IS
'Ordens com coluna local (join com locais). Usada pelo app para listar ordens e filtrar por centro_trabalho_responsavel.';

-- 4) Permissões
GRANT SELECT ON public.ordens_com_local TO authenticated;
GRANT SELECT ON public.ordens_com_local TO anon;

-- 5) Recarregar schema do PostgREST (Supabase)
NOTIFY pgrst, 'reload schema';
