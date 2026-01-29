#!/bin/bash
# ============================================
# VERIFICAR SUBSCRIPTION E LOGS
# ============================================

GRUPO_ID="369377cf-3678-43e2-8314-f4accf58575f"

echo "Grupo ID: $GRUPO_ID"
echo ""
echo "Buscando subscriptions para este grupo..."
docker exec supabase-db psql -U postgres -d postgres -c "SELECT id, thread_type, thread_id, telegram_chat_id, active FROM telegram_subscriptions WHERE thread_id = '$GRUPO_ID' AND active = true;"

echo ""
echo "Verificando logs completos..."
journalctl -u telegram-webhook -n 30 --no-pager | tail -30
