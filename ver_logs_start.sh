#!/bin/bash
# ============================================
# VER LOGS DO COMANDO /START
# ============================================

echo "==========================================="
echo "LOGS DO COMANDO /START"
echo "==========================================="
echo ""

echo "Buscando logs recentes relacionados a /start..."
echo ""

journalctl -u telegram-webhook -n 50 --no-pager | grep -E "(start|START|link_|Comando|Processando mensagem|Update recebido)" || echo "Nenhum log relevante encontrado"

echo ""
echo "==========================================="
echo "TODOS OS LOGS RECENTES (últimas 30 linhas):"
echo "==========================================="
journalctl -u telegram-webhook -n 30 --no-pager
