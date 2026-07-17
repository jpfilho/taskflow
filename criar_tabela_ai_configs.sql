-- Script para criar a tabela de configurações de IA no Supabase
-- Execute este script no SQL Editor do console do seu Supabase.

CREATE TABLE IF NOT EXISTS public.ai_configs (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Habilitar Row Level Security (RLS)
ALTER TABLE public.ai_configs ENABLE ROW LEVEL SECURITY;

-- Remover políticas existentes para evitar duplicados
DROP POLICY IF EXISTS "Permitir leitura de configs" ON public.ai_configs;
DROP POLICY IF EXISTS "Permitir inserção de configs" ON public.ai_configs;
DROP POLICY IF EXISTS "Permitir atualização de configs" ON public.ai_configs;
DROP POLICY IF EXISTS "Permitir remoção de configs" ON public.ai_configs;

-- Criar políticas para anon e authenticated (desenvolvimento e produção seguros)
CREATE POLICY "Permitir leitura de configs" ON public.ai_configs
    FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "Permitir inserção de configs" ON public.ai_configs
    FOR INSERT TO anon, authenticated WITH CHECK (true);

CREATE POLICY "Permitir atualização de configs" ON public.ai_configs
    FOR UPDATE TO anon, authenticated USING (true);

CREATE POLICY "Permitir remoção de configs" ON public.ai_configs
    FOR DELETE TO anon, authenticated USING (true);
