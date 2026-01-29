#!/bin/bash
# ============================================
# LISTAR COMUNIDADES DISPONÍVEIS
# ============================================

echo "Comunidades disponíveis:"
echo ""

docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
    c.id,
    c.divisao_nome,
    c.segmento_nome,
    CASE 
        WHEN tc.telegram_chat_id IS NOT NULL THEN '✅ Configurado'
        ELSE '❌ Não configurado'
    END as status_telegram,
    tc.telegram_chat_id
FROM comunidades c
LEFT JOIN telegram_communities tc ON tc.community_id = c.id
ORDER BY c.divisao_nome, c.segmento_nome
LIMIT 20;
"

echo ""
echo "Para cadastrar um supergrupo:"
echo "  ./cadastrar_community_telegram.sh <community_id> <telegram_chat_id>"
