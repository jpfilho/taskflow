#!/bin/bash
# ============================================
# VER LOGS DO SERVIDOR - TÓPICOS
# ============================================

echo "==========================================="
echo "LOGS DO SERVIDOR - TÓPICOS"
echo "==========================================="
echo ""

echo "Últimas 50 linhas de log do servidor:"
journalctl -u telegram-webhook -n 50 --no-pager

echo ""
echo "==========================================="
echo "FILTRANDO LOGS DE TÓPICOS..."
echo "==========================================="
journalctl -u telegram-webhook -n 100 --no-pager | grep -E "(ensureTaskTopic|Topic|telegram_chat_id|comunidade|Grupo de chat|Supergrupo|Criando tópico|Erro ao criar)" || echo "Nenhum log relevante encontrado"
