#!/bin/bash
# ============================================
# CADASTRAR GRUPO NEPTRFMT - LINHAS DE TRANSMISSÃO
# ============================================

COMMUNITY_ID="54f622b4-4dea-4ad3-af48-9e5dd4d12b35"

echo "==========================================="
echo "CADASTRAR GRUPO NEPTRFMT - LINHAS DE TRANSMISSÃO"
echo "==========================================="
echo ""

if [ -z "$1" ]; then
  echo "⚠️ Chat ID não fornecido!"
  echo ""
  echo "Para obter o Chat ID do grupo 'NEPTRFMT - Linhas de Transmissão':"
  echo ""
  echo "1. Envie uma mensagem no grupo"
  echo "2. Execute: journalctl -u telegram-webhook -f"
  echo "3. Procure por 'chat' e 'id' no log"
  echo ""
  echo "Ou use o bot @getidsbot no Telegram"
  echo ""
  echo "Depois, execute:"
  echo "  $0 <CHAT_ID>"
  echo ""
  echo "Exemplo:"
  echo "  $0 -1001234567890"
  exit 1
fi

CHAT_ID="$1"

echo "1. Verificando comunidade..."
echo "-------------------------------------------"
COMUNIDADE=$(docker exec supabase-db psql -U postgres -d postgres -t -A -F'|' -c "
SELECT 
  id,
  divisao_nome || ' - ' || segmento_nome
FROM comunidades
WHERE id = '$COMMUNITY_ID';
" 2>/dev/null)

if [ -z "$COMUNIDADE" ]; then
  echo "❌ Comunidade não encontrada!"
  exit 1
fi

IFS='|' read -r CID NOME <<< "$COMUNIDADE"
echo "✅ Comunidade: $NOME"
echo ""

echo "2. Verificando se já existe cadastro..."
echo "-------------------------------------------"
EXISTING=$(docker exec supabase-db psql -U postgres -d postgres -t -c "
SELECT COUNT(*) 
FROM telegram_communities 
WHERE comunidade_id = '$COMMUNITY_ID';
" 2>/dev/null | xargs)

if [ "$EXISTING" != "0" ]; then
  echo "⚠️ Comunidade já tem grupo cadastrado!"
  echo ""
  docker exec supabase-db psql -U postgres -d postgres -c "
  SELECT 
    telegram_chat_id,
    TO_CHAR(created_at, 'DD/MM/YYYY HH24:MI:SS') as cadastrado_em
  FROM telegram_communities
  WHERE comunidade_id = '$COMMUNITY_ID';
  " 2>/dev/null
  echo ""
  read -p "Deseja atualizar para o novo Chat ID? (s/N): " CONFIRM
  if [ "$CONFIRM" != "s" ] && [ "$CONFIRM" != "S" ]; then
    echo "Operação cancelada."
    exit 0
  fi
fi

echo ""
echo "3. Cadastrando grupo..."
echo "-------------------------------------------"
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
  echo "4. Verificando cadastro..."
  echo "-------------------------------------------"
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
  
  echo ""
  echo "5. IMPORTANTE: Corrigir tópicos existentes"
  echo "-------------------------------------------"
  echo "Agora você precisa corrigir os tópicos que foram criados no grupo errado:"
  echo ""
  echo "  .\corrigir_topico_grupo_errado.ps1 -TaskId 5ec089a8-1c53-42fd-9885-a69df45a76cb"
  echo ""
  echo "Ou corrigir todos de uma vez:"
  echo "  .\corrigir_todos_topicos_errados.ps1"
  echo ""
else
  echo "❌ Erro ao cadastrar: $RESULT"
  exit 1
fi
