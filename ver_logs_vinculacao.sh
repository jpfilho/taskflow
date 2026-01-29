#!/bin/bash
# ============================================
# VER LOGS DE VINCULACAO
# ============================================

echo "==========================================="
echo "LOGS DE VINCULACAO E MENSAGENS"
echo "==========================================="
echo ""

echo "Buscando logs recentes relacionados a vinculacao e mensagens..."
echo ""

journalctl -u telegram-webhook -n 100 --no-pager | grep -E "(nao vinculado|vinculado|Telegram.*nao|processando mensagem|identity)" | tail -30

echo ""
echo "==========================================="
echo "TODOS OS LOGS RECENTES (últimas 20 linhas):"
echo "==========================================="
journalctl -u telegram-webhook -n 20 --no-pager
