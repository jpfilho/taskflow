-- ============================================
-- MIGRAÇÃO: ÁLBUNS DE MÍDIA - TABELAS E POLÍTICAS
-- ============================================
-- Este arquivo cria as tabelas, índices, triggers e políticas RLS
-- para o módulo de Álbuns de Mídia do TaskFlow
-- ============================================

-- 1. TABELAS BASE (Segment, Equipment, Room)
-- ============================================

-- Tabela: segments
CREATE TABLE IF NOT EXISTS segments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabela: equipments
CREATE TABLE IF NOT EXISTS equipments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    segment_id UUID NOT NULL REFERENCES segments(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabela: rooms
CREATE TABLE IF NOT EXISTS rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    equipment_id UUID NOT NULL REFERENCES equipments(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabela: media_images
CREATE TABLE IF NOT EXISTS media_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    segment_id UUID REFERENCES segments(id) ON DELETE SET NULL,
    equipment_id UUID REFERENCES equipments(id) ON DELETE SET NULL,
    room_id UUID REFERENCES rooms(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT,
    tags TEXT[] DEFAULT '{}',
    status TEXT DEFAULT 'review' CHECK (status IN ('ok', 'attention', 'review')),
    file_path TEXT NOT NULL,
    file_url TEXT,
    thumb_path TEXT,
    created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. ÍNDICES PARA PERFORMANCE
-- ============================================

-- Índices para media_images (filtros e ordenação)
CREATE INDEX IF NOT EXISTS idx_media_images_segment_id ON media_images(segment_id);
CREATE INDEX IF NOT EXISTS idx_media_images_equipment_id ON media_images(equipment_id);
CREATE INDEX IF NOT EXISTS idx_media_images_room_id ON media_images(room_id);
CREATE INDEX IF NOT EXISTS idx_media_images_created_at_desc ON media_images(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_media_images_created_by ON media_images(created_by);
CREATE INDEX IF NOT EXISTS idx_media_images_status ON media_images(status);

-- Índice GIN para busca em tags (array)
CREATE INDEX IF NOT EXISTS idx_media_images_tags_gin ON media_images USING GIN(tags);

-- Índice para busca full-text em title e description
CREATE INDEX IF NOT EXISTS idx_media_images_search ON media_images USING GIN(
    to_tsvector('portuguese', COALESCE(title, '') || ' ' || COALESCE(description, ''))
);

-- Índices para equipments e rooms (joins)
CREATE INDEX IF NOT EXISTS idx_equipments_segment_id ON equipments(segment_id);
CREATE INDEX IF NOT EXISTS idx_rooms_equipment_id ON rooms(equipment_id);

-- 3. TRIGGERS PARA updated_at
-- ============================================

-- Função para atualizar updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers para cada tabela
CREATE TRIGGER update_segments_updated_at
    BEFORE UPDATE ON segments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_equipments_updated_at
    BEFORE UPDATE ON equipments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_rooms_updated_at
    BEFORE UPDATE ON rooms
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_media_images_updated_at
    BEFORE UPDATE ON media_images
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 4. ROW LEVEL SECURITY (RLS)
-- ============================================

-- Habilitar RLS em todas as tabelas
ALTER TABLE segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE equipments ENABLE ROW LEVEL SECURITY;
ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE media_images ENABLE ROW LEVEL SECURITY;

-- Políticas para segments
-- Leitura: todos autenticados podem ler
CREATE POLICY "segments_select_authenticated"
    ON segments FOR SELECT
    TO authenticated
    USING (true);

-- Escrita: apenas admins (placeholder - ajustar conforme necessário)
-- Por enquanto, permitir escrita para todos autenticados
-- TODO: Implementar verificação de role admin quando disponível
CREATE POLICY "segments_insert_authenticated"
    ON segments FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "segments_update_authenticated"
    ON segments FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

CREATE POLICY "segments_delete_authenticated"
    ON segments FOR DELETE
    TO authenticated
    USING (true);

-- Políticas para equipments
CREATE POLICY "equipments_select_authenticated"
    ON equipments FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "equipments_insert_authenticated"
    ON equipments FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "equipments_update_authenticated"
    ON equipments FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

CREATE POLICY "equipments_delete_authenticated"
    ON equipments FOR DELETE
    TO authenticated
    USING (true);

-- Políticas para rooms
CREATE POLICY "rooms_select_authenticated"
    ON rooms FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "rooms_insert_authenticated"
    ON rooms FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "rooms_update_authenticated"
    ON rooms FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

CREATE POLICY "rooms_delete_authenticated"
    ON rooms FOR DELETE
    TO authenticated
    USING (true);

-- Políticas para media_images
-- Leitura: todos autenticados podem ler
CREATE POLICY "media_images_select_authenticated"
    ON media_images FOR SELECT
    TO authenticated
    USING (true);

-- Inserção: usuários podem inserir suas próprias imagens
CREATE POLICY "media_images_insert_own"
    ON media_images FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = created_by);

-- Atualização: usuários podem atualizar apenas suas próprias imagens
CREATE POLICY "media_images_update_own"
    ON media_images FOR UPDATE
    TO authenticated
    USING (auth.uid() = created_by)
    WITH CHECK (auth.uid() = created_by);

-- Deleção: usuários podem deletar apenas suas próprias imagens
CREATE POLICY "media_images_delete_own"
    ON media_images FOR DELETE
    TO authenticated
    USING (auth.uid() = created_by);

-- 5. STORAGE BUCKET E POLÍTICAS
-- ============================================
-- IMPORTANTE: As políticas de storage estão em um arquivo separado!
-- Execute o arquivo: create_storage_policies.sql
-- 
-- Passos:
-- 1. Crie o bucket 'taskflow-media' no Supabase Dashboard:
--    - Storage > Buckets > New Bucket
--    - Name: taskflow-media
--    - Public: false (privado)
-- 2. Execute o arquivo create_storage_policies.sql
-- ============================================

-- ============================================
-- FIM DA MIGRAÇÃO
-- ============================================
-- PRÓXIMOS PASSOS:
-- 1. Execute este SQL no Supabase SQL Editor
-- 2. Crie o bucket 'taskflow-media' no Supabase Dashboard (Storage > Buckets > New Bucket)
--    - Nome: taskflow-media
--    - Public: false (privado)
-- 3. Execute as políticas de storage (comentadas acima) após criar o bucket
-- ============================================
