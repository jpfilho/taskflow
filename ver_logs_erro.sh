#!/bin/bash
# ============================================
# VER LOGS COMPLETOS DO ERRO
# ============================================

echo "Ultimos 30 logs do servidor:"
echo ""
journalctl -u telegram-webhook -n 30 --no-pager | tail -30

echo ""
echo "Buscando erros especificos:"
journalctl -u telegram-webhook -n 50 --no-pager | grep -A 5 "Erro ao enviar"
