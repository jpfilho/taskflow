-- ============================================
-- GTD (Getting Things Done) - Tabelas e índices
-- Controle de acesso por user_id (enviado pelo app); sem RLS baseado em auth.uid().
-- ============================================

-- Função para atualizar updated_at
CREATE OR REPLACE FUNCTION public.gtd_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now() AT TIME ZONE 'utc';
  RETURN NEW;
END;
$$; 

-- ------------------------------
-- gtd_contexts (ex: @casa, @trabalho)
-- ------------------------------
CREATE TABLE IF NOT EXISTS public.gtd_contexts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  UNIQUE(user_id, name)
);

CREATE INDEX IF NOT EXISTS idx_gtd_contexts_user_id ON public.gtd_contexts(user_id);

DROP TRIGGER IF EXISTS gtd_contexts_updated_at ON public.gtd_contexts;
CREATE TRIGGER gtd_contexts_updated_at
  BEFORE UPDATE ON public.gtd_contexts
  FOR EACH ROW EXECUTE FUNCTION public.gtd_updated_at();

COMMENT ON TABLE public.gtd_contexts IS 'Contextos GTD por usuário (tenant via user_id do app).';

-- ------------------------------
-- gtd_projects
-- ------------------------------
CREATE TABLE IF NOT EXISTS public.gtd_projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  name TEXT NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc')
);

CREATE INDEX IF NOT EXISTS idx_gtd_projects_user_id ON public.gtd_projects(user_id);
CREATE INDEX IF NOT EXISTS idx_gtd_projects_updated_at ON public.gtd_projects(updated_at);

DROP TRIGGER IF EXISTS gtd_projects_updated_at ON public.gtd_projects;
CREATE TRIGGER gtd_projects_updated_at
  BEFORE UPDATE ON public.gtd_projects
  FOR EACH ROW EXECUTE FUNCTION public.gtd_updated_at();

COMMENT ON TABLE public.gtd_projects IS 'Projetos GTD por usuário.';

-- ------------------------------
-- gtd_inbox (captura rápida)
-- ------------------------------
CREATE TABLE IF NOT EXISTS public.gtd_inbox (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  content TEXT NOT NULL,
  processed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc')
);

CREATE INDEX IF NOT EXISTS idx_gtd_inbox_user_id ON public.gtd_inbox(user_id);
CREATE INDEX IF NOT EXISTS idx_gtd_inbox_processed ON public.gtd_inbox(user_id, (processed_at IS NULL));
CREATE INDEX IF NOT EXISTS idx_gtd_inbox_updated_at ON public.gtd_inbox(updated_at);

DROP TRIGGER IF EXISTS gtd_inbox_updated_at ON public.gtd_inbox;
CREATE TRIGGER gtd_inbox_updated_at
  BEFORE UPDATE ON public.gtd_inbox
  FOR EACH ROW EXECUTE FUNCTION public.gtd_updated_at();

COMMENT ON TABLE public.gtd_inbox IS 'Inbox GTD: itens capturados ainda não processados.';

-- ------------------------------
-- gtd_reference (referência / algum dia)
-- ------------------------------
CREATE TABLE IF NOT EXISTS public.gtd_reference (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  title TEXT NOT NULL,
  content TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc')
);

CREATE INDEX IF NOT EXISTS idx_gtd_reference_user_id ON public.gtd_reference(user_id);
CREATE INDEX IF NOT EXISTS idx_gtd_reference_updated_at ON public.gtd_reference(updated_at);

DROP TRIGGER IF EXISTS gtd_reference_updated_at ON public.gtd_reference;
CREATE TRIGGER gtd_reference_updated_at
  BEFORE UPDATE ON public.gtd_reference
  FOR EACH ROW EXECUTE FUNCTION public.gtd_updated_at();

COMMENT ON TABLE public.gtd_reference IS 'Referência ou lista algum dia/talvez.';

-- ------------------------------
-- gtd_actions (próximas ações, aguardando, someday)
-- ------------------------------
CREATE TABLE IF NOT EXISTS public.gtd_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  project_id UUID REFERENCES public.gtd_projects(id) ON DELETE SET NULL,
  context_id UUID REFERENCES public.gtd_contexts(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'next', -- next, waiting, someday, done
  energy TEXT, -- low, med, high
  time_min INTEGER,
  due_at TIMESTAMPTZ,
  waiting_for TEXT,
  notes TEXT,
  linked_task_id UUID NULL, -- vínculo opcional com tarefa do TaskFlow
  created_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc')
);

CREATE INDEX IF NOT EXISTS idx_gtd_actions_user_id ON public.gtd_actions(user_id);
CREATE INDEX IF NOT EXISTS idx_gtd_actions_status ON public.gtd_actions(user_id, status);
CREATE INDEX IF NOT EXISTS idx_gtd_actions_due_at ON public.gtd_actions(user_id, due_at);
CREATE INDEX IF NOT EXISTS idx_gtd_actions_project_id ON public.gtd_actions(project_id);
CREATE INDEX IF NOT EXISTS idx_gtd_actions_context_id ON public.gtd_actions(context_id);
CREATE INDEX IF NOT EXISTS idx_gtd_actions_updated_at ON public.gtd_actions(updated_at);

DROP TRIGGER IF EXISTS gtd_actions_updated_at ON public.gtd_actions;
CREATE TRIGGER gtd_actions_updated_at
  BEFORE UPDATE ON public.gtd_actions
  FOR EACH ROW EXECUTE FUNCTION public.gtd_updated_at();

COMMENT ON TABLE public.gtd_actions IS 'Ações GTD: next, waiting, someday, done. linked_task_id opcional para TaskFlow.';

-- ------------------------------
-- gtd_weekly_reviews
-- ------------------------------
CREATE TABLE IF NOT EXISTS public.gtd_weekly_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  notes TEXT,
  completed_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  created_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc')
);

CREATE INDEX IF NOT EXISTS idx_gtd_weekly_reviews_user_id ON public.gtd_weekly_reviews(user_id);
CREATE INDEX IF NOT EXISTS idx_gtd_weekly_reviews_completed_at ON public.gtd_weekly_reviews(user_id, completed_at DESC);

DROP TRIGGER IF EXISTS gtd_weekly_reviews_updated_at ON public.gtd_weekly_reviews;
CREATE TRIGGER gtd_weekly_reviews_updated_at
  BEFORE UPDATE ON public.gtd_weekly_reviews
  FOR EACH ROW EXECUTE FUNCTION public.gtd_updated_at();

COMMENT ON TABLE public.gtd_weekly_reviews IS 'Registros de revisão semanal GTD.';

-- ------------------------------
-- Permissões (anon/authenticated; filtro user_id no app)
-- ------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON public.gtd_contexts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.gtd_contexts TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.gtd_projects TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.gtd_projects TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.gtd_inbox TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.gtd_inbox TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.gtd_reference TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.gtd_reference TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.gtd_actions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.gtd_actions TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.gtd_weekly_reviews TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.gtd_weekly_reviews TO anon;

-- RLS: desabilitado explicitamente. Controle de acesso via user_id no Flutter (tabela usuarios).
-- Não usamos Supabase Auth; o app envia .eq('user_id', currentUserId) em todas as queries.
ALTER TABLE public.gtd_contexts DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.gtd_projects DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.gtd_inbox DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.gtd_reference DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.gtd_actions DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.gtd_weekly_reviews DISABLE ROW LEVEL SECURITY;

NOTIFY pgrst, 'reload schema';
