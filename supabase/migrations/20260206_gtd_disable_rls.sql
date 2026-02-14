-- ============================================
-- GTD: desabilitar RLS nas tabelas GTD
-- Controle de acesso é feito no Flutter (filtro por user_id da tabela usuarios).
-- Não usamos Supabase Auth; sem RLS as roles anon/authenticated podem
-- ler/escrever e o app garante .eq('user_id', currentUserId) em todas as queries.
-- ============================================

ALTER TABLE IF EXISTS public.gtd_contexts DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.gtd_projects DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.gtd_inbox DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.gtd_reference DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.gtd_actions DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.gtd_weekly_reviews DISABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.gtd_inbox IS 'Inbox GTD. RLS desabilitado; filtro user_id no app (tabela usuarios).';

NOTIFY pgrst, 'reload schema';
