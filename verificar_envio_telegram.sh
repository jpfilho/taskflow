#!/bin/bash
# ============================================
# VERIFICAR ENVIO FLUTTER -> TELEGRAM
# ============================================

echo "1. Verificando logs mais recentes do servidor..."
echo ""
journalctl -u telegram-webhook -n 30 --no-pager | grep -E "(Enviando mensagem|Erro ao enviar|Mensagem enviada)" | tail -10

echo ""
echo "2. Verificando se há subscriptions ativas..."
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
    thread_type,
    thread_id,
    telegram_chat_id,
    active,
    created_at
FROM telegram_subscriptions
WHERE active = true
LIMIT 5;
"

echo ""
echo "3. Buscando última mensagem enviada do Flutter..."
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
    id,
    grupo_id,
    usuario_nome,
    conteudo,
    source,
    created_at
FROM mensagens
WHERE source IS NULL OR source = 'app'
ORDER BY created_at DESC
LIMIT 3;
"
