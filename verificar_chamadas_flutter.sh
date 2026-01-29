#!/bin/bash
# ============================================
# VERIFICAR SE FLUTTER ESTÁ CHAMANDO O ENDPOINT
# ============================================

echo "1. Monitorando requisições ao endpoint /send-message (últimos 2 minutos)..."
echo "   (Pressione Ctrl+C para parar)"
echo ""

# Monitorar logs em tempo real por 30 segundos
timeout 30 journalctl -u telegram-webhook -f --no-pager | grep --line-buffered -E "(send-message|Recebida requisição|Enviando mensagem)" || true

echo ""
echo ""
echo "2. Verificando últimas requisições ao /send-message..."
journalctl -u telegram-webhook --since "5 minutes ago" --no-pager | grep -E "(send-message|Recebida requisição)" | tail -10

echo ""
echo "3. Buscando mensagens recentes do Flutter (source = app ou NULL)..."
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
    id,
    grupo_id,
    usuario_nome,
    LEFT(conteudo, 50) as conteudo_preview,
    source,
    created_at
FROM mensagens
WHERE source IS NULL OR source = 'app'
ORDER BY created_at DESC
LIMIT 5;
"

echo ""
echo "4. Verificando subscriptions ativas para esses grupos..."
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
    thread_type,
    thread_id,
    telegram_chat_id,
    active,
    created_at
FROM telegram_subscriptions
WHERE active = true
ORDER BY created_at DESC
LIMIT 5;
"
