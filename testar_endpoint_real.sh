#!/bin/bash
# ============================================
# TESTAR ENDPOINT COM MENSAGEM REAL
# ============================================

echo "Buscando última mensagem do Flutter no banco..."
MENSAGEM_ID=$(docker exec supabase-db psql -U postgres -d postgres -t -c "
SELECT id 
FROM mensagens 
WHERE (source IS NULL OR source = 'app')
ORDER BY created_at DESC 
LIMIT 1;
" | xargs)

if [ -z "$MENSAGEM_ID" ]; then
  echo "❌ Nenhuma mensagem do Flutter encontrada!"
  exit 1
fi

echo "Mensagem ID: $MENSAGEM_ID"

GRUPO_ID=$(docker exec supabase-db psql -U postgres -d postgres -t -c "
SELECT grupo_id 
FROM mensagens 
WHERE id = '$MENSAGEM_ID';
" | xargs)

echo "Grupo ID: $GRUPO_ID"
echo ""

echo "Testando endpoint /send-message..."
curl -X POST https://api.taskflowv3.com.br/send-message \
  -H "Content-Type: application/json" \
  -d "{
    \"mensagem_id\": \"$MENSAGEM_ID\",
    \"thread_type\": \"TASK\",
    \"thread_id\": \"$GRUPO_ID\"
  }" | jq '.'

echo ""
echo "Verificando logs do servidor..."
journalctl -u telegram-webhook -n 10 --no-pager | grep -E "(send-message|Enviando mensagem|Mensagem enviada)" | tail -5
