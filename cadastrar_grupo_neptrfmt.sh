#!/bin/bash
# ============================================
# CADASTRAR GRUPO NEPTRFMT - LINHAS DE TRANSMISSÃO
# ============================================

echo "==========================================="
echo "CADASTRAR GRUPO NEPTRFMT - LINHAS DE TRANSMISSÃO"
echo "==========================================="
echo ""

# Buscar comunidades NEPTRFMT - Linhas de Transmissão que não têm grupo
echo "1. Buscando comunidades NEPTRFMT - Linhas de Transmissão sem grupo..."
echo "-------------------------------------------"

COMUNIDADES=$(docker exec supabase-db psql -U postgres -d postgres -t -A -F'|' -c "
SELECT 
  c.id,
  c.divisao_nome || ' - ' || c.segmento_nome as nome
FROM comunidades c
LEFT JOIN telegram_communities tc ON tc.comunidade_id = c.id
WHERE 
  c.divisao_nome = 'NEPTRFMT' 
  AND c.segmento_nome = 'Linhas de Transmissão'
  AND tc.id IS NULL
LIMIT 1;
" 2>/dev/null)

if [ -z "$COMUNIDADES" ]; then
  echo "❌ Nenhuma comunidade NEPTRFMT - Linhas de Transmissão sem grupo encontrada"
  echo ""
  echo "Comunidades existentes:"
  docker exec supabase-db psql -U postgres -d postgres -c "
  SELECT 
    c.id,
    c.divisao_nome || ' - ' || c.segmento_nome as nome,
    CASE WHEN tc.id IS NOT NULL THEN '✅ TEM GRUPO' ELSE '❌ SEM GRUPO' END as status
  FROM comunidades c
  LEFT JOIN telegram_communities tc ON tc.comunidade_id = c.id
  WHERE c.divisao_nome = 'NEPTRFMT' AND c.segmento_nome = 'Linhas de Transmissão';
  " 2>/dev/null
  exit 1
fi

IFS='|' read -r COMMUNITY_ID COMMUNITY_NAME <<< "$COMUNIDADES"
echo "✅ Comunidade encontrada: $COMMUNITY_NAME"
echo "   ID: $COMMUNITY_ID"
echo ""

# Obter Chat ID do grupo (do log mais recente ou pedir ao usuário)
echo "2. Tentando obter Chat ID do grupo..."
echo "-------------------------------------------"

# Tentar obter do log mais recente
CHAT_ID=$(journalctl -u telegram-webhook -n 200 --no-pager | grep -E "NEPTRFMT - Linhas de Transmissão" | grep -E '"id": -[0-9]+' | tail -1 | grep -oE '"-?[0-9]+"' | head -1 | tr -d '"')

if [ -z "$CHAT_ID" ]; then
  echo "⚠️ Chat ID não encontrado nos logs"
  echo ""
  echo "Por favor, forneça o Chat ID do grupo:"
  echo "  - Envie uma mensagem no grupo e veja os logs"
  echo "  - Ou use o bot @getidsbot"
  echo "  - Ou veja nas informações do grupo"
  echo ""
  read -p "Digite o Chat ID (ex: -1001234567890): " CHAT_ID
fi

if [ -z "$CHAT_ID" ]; then
  echo "❌ Chat ID não fornecido"
  exit 1
fi

echo "   Chat ID: $CHAT_ID"
echo ""

# Cadastrar grupo
echo "3. Cadastrando grupo..."
echo "-------------------------------------------"

RESULT=$(docker exec supabase-db psql -U postgres -d postgres -t -c "
INSERT INTO telegram_communities (community_id, telegram_chat_id)
VALUES ('$COMMUNITY_ID', $CHAT_ID)
ON CONFLICT DO NOTHING
RETURNING id;
" 2>&1)

if [ $? -eq 0 ] && [ -n "$RESULT" ]; then
  echo "✅ Grupo cadastrado com sucesso!"
  echo ""
  echo "Verificando cadastro..."
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
  echo "❌ Erro ao cadastrar: $RESULT"
  exit 1
fi
