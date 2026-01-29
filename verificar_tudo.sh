#!/bin/bash
# ============================================
# VERIFICAR TUDO
# ============================================

echo "1. Verificando subscriptions atualizadas..."
docker exec supabase-db psql -U postgres -d postgres -c "SELECT COUNT(*) as total, telegram_chat_id FROM telegram_subscriptions WHERE active = true GROUP BY telegram_chat_id;"

echo ""
echo "2. Verificando logs de erro completos..."
journalctl -u telegram-webhook -n 50 --no-pager | grep -B 2 -A 10 "Erro ao enviar"

echo ""
echo "3. Ultimos logs do servidor..."
journalctl -u telegram-webhook -n 20 --no-pager | tail -20
