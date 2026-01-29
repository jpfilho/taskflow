#!/bin/bash
# ============================================
# VERIFICAR INTEGRAÇÃO FLUTTER -> NODE.JS
# ============================================

echo "1. Verificando se o servidor Node.js está rodando..."
systemctl is-active telegram-webhook

echo ""
echo "2. Verificando logs recentes do servidor (últimas requisições)..."
journalctl -u telegram-webhook -n 50 --no-pager | grep -E "(send-message|Recebida requisição|Enviando mensagem)" | tail -20

echo ""
echo "3. Verificando se o endpoint está acessível localmente..."
curl -s -X POST http://localhost:3001/send-message \
  -H "Content-Type: application/json" \
  -d '{"mensagem_id":"test","thread_type":"TASK","thread_id":"test"}' | jq '.' || echo "Erro ao testar endpoint local"

echo ""
echo "4. Verificando se o endpoint está acessível via HTTPS..."
curl -s -X POST https://api.taskflowv3.com.br/send-message \
  -H "Content-Type: application/json" \
  -d '{"mensagem_id":"test","thread_type":"TASK","thread_id":"test"}' | jq '.' || echo "Erro ao testar endpoint HTTPS"

echo ""
echo "5. Verificando configuração do Nginx para /send-message..."
grep -A 10 "location /send-message" /etc/nginx/sites-available/default || echo "Configuração não encontrada"
