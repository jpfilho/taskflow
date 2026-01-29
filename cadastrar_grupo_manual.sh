#!/bin/bash
# ============================================
# CADASTRAR GRUPO MANUALMENTE
# ============================================

COMMUNITY_ID="54f622b4-4dea-4ad3-af48-9e5dd4d12b35"
CHAT_ID="-1003878325215"

echo "==========================================="
echo "CADASTRAR GRUPO MANUALMENTE"
echo "==========================================="
echo ""

echo "Comunidade: NEPTRFMT - Linhas de Transmissão"
echo "Chat ID: $CHAT_ID"
echo ""

echo "Cadastrando..."
RESULT=$(docker exec supabase-db psql -U postgres -d postgres -t -c "
INSERT INTO telegram_communities (comunidade_id, telegram_chat_id)
VALUES ('$COMMUNITY_ID', $CHAT_ID)
ON CONFLICT (comunidade_id) 
DO UPDATE SET 
  telegram_chat_id = $CHAT_ID,
  updated_at = NOW()
RETURNING id;
" 2>&1)

if [ $? -eq 0 ] && [ -n "$RESULT" ]; then
  echo "✅ Grupo cadastrado com sucesso!"
  echo ""
  docker exec supabase-db psql -U postgres -d postgres -c "
  SELECT 
    tc.id,
    c.divisao_nome || ' - ' || c.segmento_nome as comunidade,
    tc.telegram_chat_id,
    TO_CHAR(tc.created_at, 'DD/MM/YYYY HH24:MI:SS') as cadastrado_em
  FROM telegram_communities tc
  JOIN comunidades c ON c.id = tc.comunidade_id
  WHERE tc.comunidade_id = '$COMMUNITY_ID';
  " 2>/dev/null
else
  echo "❌ Erro: $RESULT"
  exit 1
fi
