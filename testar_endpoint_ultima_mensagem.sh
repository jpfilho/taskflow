#!/bin/bash
# ============================================
# TESTAR ENDPOINT COM ÚLTIMA MENSAGEM
# ============================================

echo "Buscando última mensagem do Flutter..."
MENSAGEM_ID=$(docker exec supabase-db psql -U postgres -d postgres -t -c "
SELECT id 
FROM mensagens 
WHERE (source IS NULL OR source = 'app')
  AND grupo_id = '369377cf-3678-43e2-8314-f4accf58575f'
ORDER BY created_at DESC 
LIMIT 1;
" | xargs | tr -d '\r')

if [ -z "$MENSAGEM_ID" ]; then
  echo "❌ Nenhuma mensagem do Flutter encontrada!"
  exit 1
fi

echo "Mensagem ID: $MENSAGEM_ID"
echo "Grupo ID: 369377cf-3678-43e2-8314-f4accf58575f"
echo ""

echo "Testando endpoint /send-message via HTTPS..."
RESPONSE=$(curl -s -X POST https://api.taskflowv3.com.br/send-message \
  -H "Content-Type: application/json" \
  -d "{
    \"mensagem_id\": \"$MENSAGEM_ID\",
    \"thread_type\": \"TASK\",
    \"thread_id\": \"369377cf-3678-43e2-8314-f4accf58575f\"
  }")

echo "Resposta:"
echo "$RESPONSE" | jq '.' || echo "$RESPONSE"

echo ""
echo "Verificando logs do servidor (últimas 5 linhas)..."
journalctl -u telegram-webhook -n 10 --no-pager | grep -E "(send-message|Enviando mensagem|Mensagem enviada|Erro)" | tail -5
