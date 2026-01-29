-- ============================================
-- REMOVER FOREIGN KEYS DE EQUIPMENT_ID E ROOM_ID
-- ============================================
-- Execute este script para remover as foreign keys de equipment_id e room_id
-- Isso permite usar IDs gerados dinamicamente (UUIDs determinísticos)
-- que podem não existir nas tabelas equipments/rooms
-- ============================================

-- Remover foreign key de equipment_id
ALTER TABLE media_images 
DROP CONSTRAINT IF EXISTS media_images_equipment_id_fkey;

-- Remover foreign key de room_id
ALTER TABLE media_images 
DROP CONSTRAINT IF EXISTS media_images_room_id_fkey;

-- Verificar foreign keys restantes em media_images
SELECT
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_name = 'media_images'
ORDER BY kcu.column_name;

-- Deve mostrar apenas a foreign key de created_by (se ainda existir)

-- ============================================
-- NOTA IMPORTANTE
-- ============================================
-- Após remover essas foreign keys:
-- 
-- 1. segment_id: Pode conter IDs de 'segments' ou 'segmentos'
-- 2. equipment_id: Pode conter UUIDs determinísticos gerados a partir de localizacao
-- 3. room_id: Pode conter UUIDs determinísticos gerados a partir de sala+localizacao
--
-- Esses IDs são gerados dinamicamente no código Dart e não precisam existir
-- nas tabelas equipments/rooms, pois são derivados de equipamentos_sap.
--
-- A aplicação deve validar a existência antes de usar, mas não há mais
-- restrição de integridade referencial no banco para esses campos.
-- ============================================
