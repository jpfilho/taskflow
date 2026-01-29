#!/bin/bash
# ============================================
# OBTER TELEGRAM USER ID DOS LOGS
# ============================================

echo "==========================================="
echo "OBTER TELEGRAM USER ID DOS LOGS"
echo "==========================================="
echo ""

echo "Buscando Telegram User IDs nos logs recentes do servidor..."
echo "(Envie uma mensagem no Telegram primeiro)"
echo ""

# Buscar nos logs do webhook
journalctl -u telegram-webhook -n 100 --no-pager | grep -E "from.*id|telegram_user_id" | tail -20

echo ""
echo "Ou busque manualmente nos logs:"
echo "  journalctl -u telegram-webhook -n 200 | grep 'from'"
