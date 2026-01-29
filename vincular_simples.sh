#!/bin/bash
# ============================================
# VINCULAR EXECUTOR 264259 AO TELEGRAM
# ============================================

echo "Buscando executor com matricula 264259..."
docker exec supabase-db psql -U postgres -d postgres << 'EOF'

DO $$
DECLARE
    executor_id UUID;
    executor_nome VARCHAR;
BEGIN
    -- Buscar executor
    SELECT id, nome INTO executor_id, executor_nome
    FROM executores 
    WHERE matricula = '264259';
    
    IF executor_id IS NULL THEN
        RAISE EXCEPTION 'Executor com matricula 264259 nao encontrado!';
    END IF;
    
    RAISE NOTICE 'Executor encontrado: % (ID: %)', executor_nome, executor_id;
    
    -- Vincular Telegram
    INSERT INTO telegram_identities (
        user_id,
        telegram_user_id,
        telegram_username,
        telegram_first_name,
        linked_at
    ) VALUES (
        executor_id,
        7807721517,
        'jose_user',
        'JOSE',
        NOW()
    ) ON CONFLICT (telegram_user_id) DO UPDATE SET
        user_id = EXCLUDED.user_id,
        telegram_first_name = EXCLUDED.telegram_first_name,
        linked_at = NOW();
    
    RAISE NOTICE 'Telegram vinculado com sucesso!';
END $$;

-- Verificar vinculacao
SELECT 
    ti.telegram_user_id,
    ti.telegram_first_name,
    e.matricula,
    e.nome,
    e.telefone,
    ti.linked_at
FROM telegram_identities ti
JOIN executores e ON e.id = ti.user_id
WHERE ti.telegram_user_id = 7807721517;

EOF

echo ""
echo "Vinculacao concluida!"
