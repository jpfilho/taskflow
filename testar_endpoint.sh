#!/bin/bash
# ============================================
# TESTAR ENDPOINT COM DADOS REAIS
# ============================================

echo "Buscando mensagem real no banco..."

# Buscar mensagem
MENSAGEM_ID=$(docker exec supabase-db psql -U postgres -d postgres -t -c "SELECT id FROM mensagens WHERE source = 'app' ORDER BY created_at DESC LIMIT 1;" | xargs)

if [ -z "$MENSAGEM_ID" ]; then
    echo "Nenhuma mensagem encontrada!"
    exit 1
fi

echo "Mensagem ID: $MENSAGEM_ID"

# Buscar grupo
GRUPO_ID=$(docker exec supabase-db psql -U postgres -d postgres -t -c "SELECT grupo_id FROM mensagens WHERE id = '$MENSAGEM_ID';" | xargs)

echo "Grupo ID: $GRUPO_ID"

# Testar endpoint
echo ""
echo "Testando endpoint..."
curl -X POST http://127.0.0.1:3001/send-message \
  -H "Content-Type: application/json" \
  -d "{\"mensagem_id\":\"$MENSAGEM_ID\",\"thread_type\":\"TASK\",\"thread_id\":\"$GRUPO_ID\"}"

echo ""
echo ""
echo "Teste concluido!"
