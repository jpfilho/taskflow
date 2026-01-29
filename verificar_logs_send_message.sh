#!/bin/bash
# ============================================
# VERIFICAR LOGS DO /SEND-MESSAGE
# ============================================

echo "==========================================="
echo "LOGS DO /SEND-MESSAGE"
echo "==========================================="
echo ""

echo "Buscando logs recentes do /send-message..."
journalctl -u telegram-webhook -n 200 --no-pager | grep -E "(send-message|ensureTaskTopic|Verificando tópico|Criando tópico|Topic not available|Task not found|Grupo de chat|Supergrupo Telegram)" | tail -30

echo ""
echo "==========================================="
echo "TODOS OS LOGS RECENTES (últimas 30 linhas):"
echo "==========================================="
journalctl -u telegram-webhook -n 30 --no-pager
