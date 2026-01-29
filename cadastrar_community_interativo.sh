#!/bin/bash
# ============================================
# CADASTRAR SUPERGRUPO - MODO INTERATIVO
# ============================================

echo "=========================================="
echo "CADASTRAR SUPERGRUPO TELEGRAM"
echo "=========================================="
echo ""

# Listar comunidades
echo "Comunidades disponíveis:"
echo ""
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
    ROW_NUMBER() OVER (ORDER BY divisao_nome, segmento_nome) as num,
    id,
    divisao_nome,
    segmento_nome,
    CASE 
        WHEN tc.telegram_chat_id IS NOT NULL THEN '✅ Configurado'
        ELSE '❌ Não configurado'
    END as status
FROM comunidades c
LEFT JOIN telegram_communities tc ON tc.community_id = c.id
ORDER BY divisao_nome, segmento_nome
LIMIT 20;
"

echo ""
echo "Digite o número da comunidade que deseja cadastrar (ou 'sair' para cancelar):"
read -r NUMERO

if [ "$NUMERO" = "sair" ] || [ -z "$NUMERO" ]; then
  echo "Operação cancelada."
  exit 0
fi

# Buscar ID da comunidade pelo número
COMMUNITY_ID=$(docker exec supabase-db psql -U postgres -d postgres -t -A -c "
SELECT id
FROM (
  SELECT 
      ROW_NUMBER() OVER (ORDER BY divisao_nome, segmento_nome) as num,
      id,
      divisao_nome,
      segmento_nome
  FROM comunidades
  ORDER BY divisao_nome, segmento_nome
  LIMIT 20
) sub
WHERE num = $NUMERO;
" | xargs)

if [ -z "$COMMUNITY_ID" ]; then
  echo "❌ Número inválido!"
  exit 1
fi

# Mostrar informações da comunidade selecionada
COMMUNITY_INFO=$(docker exec supabase-db psql -U postgres -d postgres -t -A -F'|' -c "
SELECT divisao_nome, segmento_nome
FROM comunidades
WHERE id = '$COMMUNITY_ID';
")

IFS='|' read -r DIVISAO SEGMENTO <<< "$COMMUNITY_INFO"
echo ""
echo "Comunidade selecionada:"
echo "  Divisão: $DIVISAO"
echo "  Segmento: $SEGMENTO"
echo "  ID: $COMMUNITY_ID"
echo ""

echo "Digite o Telegram Chat ID do supergrupo (ex: -1003721115749):"
read -r TELEGRAM_CHAT_ID

if [ -z "$TELEGRAM_CHAT_ID" ]; then
  echo "❌ Chat ID não pode ser vazio!"
  exit 1
fi

# Validar formato (deve começar com -100 para supergrupos)
if [[ ! "$TELEGRAM_CHAT_ID" =~ ^-?[0-9]+$ ]]; then
  echo "❌ Chat ID inválido! Deve ser um número (ex: -1003721115749)"
  exit 1
fi

echo ""
echo "Confirmar cadastro? (s/n)"
read -r CONFIRMA

if [ "$CONFIRMA" != "s" ] && [ "$CONFIRMA" != "S" ]; then
  echo "Operação cancelada."
  exit 0
fi

# Executar cadastro
echo ""
echo "Cadastrando..."
docker exec supabase-db psql -U postgres -d postgres -c "
INSERT INTO telegram_communities (community_id, telegram_chat_id)
VALUES ('$COMMUNITY_ID', $TELEGRAM_CHAT_ID)
ON CONFLICT (community_id) 
DO UPDATE SET 
  telegram_chat_id = $TELEGRAM_CHAT_ID,
  updated_at = NOW();
"

echo ""
echo "Verificando cadastro..."
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
    tc.id,
    c.divisao_nome as divisao,
    c.segmento_nome as segmento,
    tc.telegram_chat_id,
    tc.created_at
FROM telegram_communities tc
JOIN comunidades c ON c.id = tc.community_id
WHERE tc.community_id = '$COMMUNITY_ID';
"

echo ""
echo "=========================================="
echo "✅ SUPERGRUPO CADASTRADO COM SUCESSO!"
echo "=========================================="
