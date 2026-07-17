-- ============================================
-- MIGRATION: SISTEMA DE FEEDBACK ESTRUTURADO DE NOTAS E ORDENS
-- ============================================

-- ============================================
-- 1. TABELAS DE DOMÍNIO E AUDITORIA
-- ============================================

-- 1.1 Sessões de Feedback (Agrupador lógico de rascunhos e envios)
CREATE TABLE IF NOT EXISTS public.chat_feedback_sessions (
    id UUID PRIMARY KEY,
    task_id UUID NOT NULL,
    message_id UUID NULL,
    status TEXT NOT NULL CHECK (status IN ('draft', 'submitted', 'cancelled', 'sync_pending', 'sync_failed')),
    created_by UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    submitted_at TIMESTAMPTZ NULL,
    client_id TEXT NOT NULL,
    CONSTRAINT uq_session_client_id UNIQUE (created_by, client_id)
);
COMMENT ON TABLE public.chat_feedback_sessions IS 'Sessões de preenchimento de feedback no chat. Agrupa múltiplos itens avaliados.';
COMMENT ON COLUMN public.chat_feedback_sessions.client_id IS 'ID gerado no cliente para idempotência do offline-first.';

-- 1.2 Itens Vinculados à Sessão (Nota, Ordem ou Geral)
CREATE TABLE IF NOT EXISTS public.chat_feedback_items (
    id UUID PRIMARY KEY,
    session_id UUID NOT NULL REFERENCES public.chat_feedback_sessions(id) ON DELETE CASCADE,
    task_id UUID NOT NULL,
    item_type TEXT NOT NULL CHECK (item_type IN ('NOTA', 'ORDEM', 'GERAL')),
    source_item_id UUID NULL,
    item_number TEXT NULL,
    item_description TEXT NULL,
    location TEXT NULL,
    room TEXT NULL,
    created_by UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.chat_feedback_items IS 'Itens selecionados durante uma sessão de feedback.';
COMMENT ON COLUMN public.chat_feedback_items.source_item_id IS 'ID original da Nota ou Ordem na tabela de tarefas.';

-- 1.3 Feedbacks Individuais (Vários por item)
CREATE TABLE IF NOT EXISTS public.chat_item_feedbacks (
    id UUID PRIMARY KEY,
    feedback_item_id UUID NOT NULL REFERENCES public.chat_feedback_items(id) ON DELETE CASCADE,
    sequence_number INTEGER NOT NULL,
    execution_status TEXT NOT NULL,
    execution_percentage NUMERIC NULL,
    non_execution_reason TEXT NULL,
    comment TEXT NULL,
    execution_date TIMESTAMPTZ NULL,
    follow_up_required BOOLEAN NOT NULL DEFAULT false,
    is_closed BOOLEAN NOT NULL DEFAULT false,
    created_by UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    client_id TEXT NULL,
    
    CONSTRAINT chk_execution_percentage CHECK (
        execution_percentage IS NULL
        OR (execution_percentage >= 0 AND execution_percentage <= 100)
    ),
    CONSTRAINT chk_non_execution_reason CHECK (
        non_execution_reason IS NULL OR
        non_execution_reason IN (
            'material_unavailable',
            'team_unavailable',
            'operational_impediment',
            'shutdown_required',
            'weather_condition',
            'access_problem',
            'registration_divergence',
            'item_not_found',
            'other'
        )
    )
);
COMMENT ON TABLE public.chat_item_feedbacks IS 'Registros operacionais do feedback. Vários registros formam a linha do tempo do item.';

-- 1.4 Histórico de Edição do Feedback (Auditoria Técnica)
CREATE TABLE IF NOT EXISTS public.chat_item_feedback_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    feedback_id UUID NOT NULL REFERENCES public.chat_item_feedbacks(id) ON DELETE CASCADE,
    changed_fields JSONB NOT NULL,
    changed_by UUID NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.chat_item_feedback_history IS 'Tabela de auditoria para rastrear alterações num MESMO registro de feedback operacional.';

-- 1.5 Anexos Específicos do Feedback
CREATE TABLE IF NOT EXISTS public.chat_item_feedback_anexos (
    id UUID PRIMARY KEY,
    feedback_id UUID NOT NULL REFERENCES public.chat_item_feedbacks(id) ON DELETE CASCADE,
    nome_arquivo TEXT NOT NULL,
    tipo_arquivo TEXT NOT NULL,
    caminho_arquivo TEXT NOT NULL,
    tamanho_bytes INTEGER NOT NULL,
    mime_type TEXT NULL,
    created_by UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    client_id TEXT NULL
);
COMMENT ON TABLE public.chat_item_feedback_anexos IS 'Evidências fotográficas restritas a um feedback específico.';

-- ============================================
-- 2. ALTERAR TABELA MENSAGENS E FKs
-- ============================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'mensagens' AND column_name = 'feedback_session_id'
    ) THEN
        ALTER TABLE public.mensagens ADD COLUMN feedback_session_id UUID REFERENCES public.chat_feedback_sessions(id) ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'mensagens' AND column_name = 'structured_payload'
    ) THEN
        ALTER TABLE public.mensagens ADD COLUMN structured_payload JSONB NULL;
    END IF;
END $$;

-- FK Circular: A sessão conhece a mensagem
ALTER TABLE public.chat_feedback_sessions 
    DROP CONSTRAINT IF EXISTS fk_session_message;
    
ALTER TABLE public.chat_feedback_sessions 
    ADD CONSTRAINT fk_session_message 
    FOREIGN KEY (message_id) REFERENCES public.mensagens(id) ON DELETE SET NULL;


-- ============================================
-- 3. ÍNDICES DE PERFORMANCE E CONSULTAS
-- ============================================

CREATE INDEX IF NOT EXISTS idx_chat_feedback_sessions_task_id ON public.chat_feedback_sessions(task_id);
CREATE INDEX IF NOT EXISTS idx_chat_feedback_sessions_message_id ON public.chat_feedback_sessions(message_id);
CREATE INDEX IF NOT EXISTS idx_chat_feedback_sessions_created_by ON public.chat_feedback_sessions(created_by);

CREATE INDEX IF NOT EXISTS idx_chat_feedback_items_session_id ON public.chat_feedback_items(session_id);
CREATE INDEX IF NOT EXISTS idx_chat_feedback_items_task_id ON public.chat_feedback_items(task_id);
CREATE INDEX IF NOT EXISTS idx_chat_feedback_items_source_item_id ON public.chat_feedback_items(source_item_id);

CREATE INDEX IF NOT EXISTS idx_chat_item_feedbacks_item_id ON public.chat_item_feedbacks(feedback_item_id);
CREATE INDEX IF NOT EXISTS idx_chat_item_feedbacks_created_by ON public.chat_item_feedbacks(created_by);
CREATE INDEX IF NOT EXISTS idx_chat_item_feedbacks_is_closed ON public.chat_item_feedbacks(is_closed);
CREATE INDEX IF NOT EXISTS idx_chat_item_feedbacks_execution_status ON public.chat_item_feedbacks(execution_status);

CREATE INDEX IF NOT EXISTS idx_chat_feedback_anexos_feedback_id ON public.chat_item_feedback_anexos(feedback_id);

CREATE INDEX IF NOT EXISTS idx_mensagens_feedback_session_id ON public.mensagens(feedback_session_id);


-- ============================================
-- 4. POLÍTICAS RLS (Row Level Security)
-- ============================================

-- Habilitar RLS
ALTER TABLE public.chat_feedback_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_feedback_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_item_feedbacks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_item_feedback_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_item_feedback_anexos ENABLE ROW LEVEL SECURITY;

-- Políticas permissivas baseadas no auth() do Supabase (consistentes com o projeto)
CREATE POLICY "Permitir leitura de sessions para todos" ON public.chat_feedback_sessions FOR SELECT USING (true);
CREATE POLICY "Permitir insert de sessions" ON public.chat_feedback_sessions FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "Permitir update de sessions do próprio autor" ON public.chat_feedback_sessions FOR UPDATE USING (auth.uid()::text = created_by::text OR auth.role() = 'service_role');

CREATE POLICY "Permitir leitura de items para todos" ON public.chat_feedback_items FOR SELECT USING (true);
CREATE POLICY "Permitir insert de items" ON public.chat_feedback_items FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Permitir leitura de feedbacks para todos" ON public.chat_item_feedbacks FOR SELECT USING (true);
CREATE POLICY "Permitir insert de feedbacks" ON public.chat_item_feedbacks FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "Permitir update de feedbacks do próprio autor" ON public.chat_item_feedbacks FOR UPDATE USING (auth.uid()::text = created_by::text OR auth.role() = 'service_role');

CREATE POLICY "Permitir leitura de history para todos" ON public.chat_item_feedback_history FOR SELECT USING (true);
CREATE POLICY "Permitir insert de history" ON public.chat_item_feedback_history FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Permitir leitura de anexos para todos" ON public.chat_item_feedback_anexos FOR SELECT USING (true);
CREATE POLICY "Permitir insert de anexos" ON public.chat_item_feedback_anexos FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "Permitir delete de anexos do próprio autor" ON public.chat_item_feedback_anexos FOR DELETE USING (auth.uid()::text = created_by::text OR auth.role() = 'service_role');


-- ============================================
-- 5. TRIGGER DE UPDATED_AT (Sessões e Feedbacks)
-- ============================================

-- Verifica se a função set_updated_at já existe, se não, cria
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_chat_feedback_sessions_updated_at ON public.chat_feedback_sessions;
CREATE TRIGGER set_chat_feedback_sessions_updated_at
BEFORE UPDATE ON public.chat_feedback_sessions
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS set_chat_item_feedbacks_updated_at ON public.chat_item_feedbacks;
CREATE TRIGGER set_chat_item_feedbacks_updated_at
BEFORE UPDATE ON public.chat_item_feedbacks
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================
-- 6. VERIFICAÇÃO PÓS-MIGRAÇÃO
-- ============================================
/*
SELECT table_name, column_name, data_type 
FROM information_schema.columns 
WHERE table_name IN (
    'chat_feedback_sessions', 
    'chat_feedback_items', 
    'chat_item_feedbacks', 
    'chat_item_feedback_history', 
    'chat_item_feedback_anexos'
) ORDER BY table_name, ordinal_position;
*/

-- ============================================
-- 7. SCRIPT DE ROLLBACK
-- ============================================
/*
-- 1. Remover FKs de Mensagens
ALTER TABLE public.mensagens DROP COLUMN IF EXISTS feedback_session_id;
ALTER TABLE public.mensagens DROP COLUMN IF EXISTS structured_payload;

-- 2. Dropar Triggers
DROP TRIGGER IF EXISTS set_chat_feedback_sessions_updated_at ON public.chat_feedback_sessions;
DROP TRIGGER IF EXISTS set_chat_item_feedbacks_updated_at ON public.chat_item_feedbacks;

-- 3. Dropar Tabelas
DROP TABLE IF EXISTS public.chat_item_feedback_anexos CASCADE;
DROP TABLE IF EXISTS public.chat_item_feedback_history CASCADE;
DROP TABLE IF EXISTS public.chat_item_feedbacks CASCADE;
DROP TABLE IF EXISTS public.chat_feedback_items CASCADE;
DROP TABLE IF EXISTS public.chat_feedback_sessions CASCADE;
*/
