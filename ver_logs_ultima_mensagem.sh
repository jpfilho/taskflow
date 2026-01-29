#!/bin/bash
# ============================================
# VER LOGS DA ULTIMA MENSAGEM
# ============================================

echo "==========================================="
echo "LOGS DA ULTIMA MENSAGEM"
echo "==========================================="
echo ""

echo "Buscando logs mais recentes do /send-message..."
journalctl -u telegram-webhook -n 100 --no-pager | grep -A 10 -B 5 "send-message\|ensureTaskTopic\|Verificando tópico\|Criando tópico\|Topic not available\|Task not found\|Grupo de chat\|Supergrupo Telegram" | tail -50

echo ""
echo "==========================================="
echo "TODOS OS LOGS RECENTES (últimas 50 linhas):"
echo "==========================================="
journalctl -u telegram-webhook -n 50 --no-pager
