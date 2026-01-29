#!/bin/bash
# ============================================
# MONITORAR CHAMADAS DO FLUTTER EM TEMPO REAL
# ============================================

echo "Monitorando chamadas ao endpoint /send-message..."
echo "Envie uma mensagem do Flutter agora e veja se aparece aqui."
echo "Pressione Ctrl+C para parar."
echo ""

# Monitorar logs em tempo real
journalctl -u telegram-webhook -f --no-pager | grep --line-buffered -E "(send-message|Recebida requisição|Enviando mensagem|Mensagem enviada|Erro ao enviar)" | while read line; do
  echo "[$(date +%H:%M:%S)] $line"
done
