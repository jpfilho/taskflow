#!/bin/bash
# ============================================
# MONITORAR IDENTIFICAÇÃO DE GRUPOS EM TEMPO REAL
# ============================================

echo "==========================================="
echo "MONITORANDO IDENTIFICAÇÃO DE GRUPOS"
echo "==========================================="
echo ""
echo "Pressione Ctrl+C para parar"
echo ""

# Monitorar logs em tempo real
journalctl -u telegram-webhook -f --no-pager | grep --line-buffered -E "(Bot adicionado|Grupo cadastrado|Match|associar|comunidade|handleBotAddedToGroup)" || true
