#!/bin/bash
# ============================================
# CADASTRAR GRUPO TELEGRAM PARA COMUNIDADE
# ============================================

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Uso: $0 <community_id> <telegram_chat_id>"
  echo ""
  echo "Exemplo:"
  echo "  $0 1a8afda9-9b15-4985-bc30-423f2458623c -1001234567890"
  echo ""
  echo "Para listar os IDs das comunidades, execute:"
  echo "  docker exec supabase-db psql -U postgres -d postgres -c \"SELECT id, divisao_nome || ' - ' || segmento_nome as nome FROM comunidades;\""
  exit 1
fi

COMMUNITY_ID="$1"
TELEGRAM_CHAT_ID="$2"

echo "==========================================="
echo "CADASTRAR GRUPO PARA COMUNIDADE"
echo "==========================================="
echo ""

echo "Community ID: $COMMUNITY_ID"
echo "Telegram Chat ID: $TELEGRAM_CHAT_ID"
echo ""

echo "Verificando comunidade..."
COMUNIDADE=$(docker exec supabase-db psql -U postgres -d postgres -t -A -F'|' -c "
SELECT 
  id::text,
  divisao_nome || ' - ' || segmento_nome
FROM comunidades
WHERE id = '$COMMUNITY_ID';
" 2>/dev/null)

if [ -z "$COMUNIDADE" ]; then
  echo "❌ Comunidade não encontrada!"
  exit 1
fi

echo "Comunidade encontrada: $(echo $COMUNIDADE | cut -d'|' -f2)"
echo ""

echo "Cadastrando grupo..."
RESULT=$(docker exec supabase-db psql -U postgres -d postgres -t -c "
INSERT INTO telegram_communities (community_id, telegram_chat_id)
VALUES ('$COMMUNITY_ID', $TELEGRAM_CHAT_ID)
ON CONFLICT (community_id) 
DO UPDATE SET 
  telegram_chat_id = $TELEGRAM_CHAT_ID,
  updated_at = NOW()
RETURNING id;
" 2>&1)

if [ $? -eq 0 ]; then
  echo "✅ Grupo cadastrado com sucesso!"
  echo ""
  echo "Verificando cadastro..."
  docker exec supabase-db psql -U postgres -d postgres -c "
  SELECT 
    tc.id,
    c.divisao_nome || ' - ' || c.segmento_nome as comunidade_nome,
    tc.telegram_chat_id,
    TO_CHAR(tc.created_at, 'DD/MM/YYYY HH24:MI:SS') as cadastrado_em
  FROM telegram_communities tc
  JOIN comunidades c ON c.id = tc.comunidade_id
  WHERE tc.comunidade_id = '$COMMUNITY_ID';
  " 2>/dev/null
else
  echo "❌ Erro ao cadastrar: $RESULT"
  exit 1
fi
