#!/bin/bash
# ============================================
# CADASTRAR SUPERGRUPO PARA COMUNIDADE
# ============================================

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Uso: $0 <community_id> <telegram_chat_id>"
  echo ""
  echo "Exemplo:"
  echo "  $0 1a8afda9-9b15-4985-bc30-423f2458623c -1003721115749"
  echo ""
  echo "Para listar comunidades disponíveis:"
  echo "  ./listar_comunidades.sh"
  exit 1
fi

COMMUNITY_ID="$1"
TELEGRAM_CHAT_ID="$2"

echo "=========================================="
echo "CADASTRAR SUPERGRUPO TELEGRAM"
echo "=========================================="
echo ""

# Verificar se comunidade existe e mostrar informações
echo "1. Verificando comunidade..."
COMMUNITY_INFO=$(docker exec supabase-db psql -U postgres -d postgres -t -A -F'|' -c "
SELECT id, divisao_nome, segmento_nome
FROM comunidades 
WHERE id = '$COMMUNITY_ID';
")

if [ -z "$COMMUNITY_INFO" ]; then
  echo "❌ Comunidade não encontrada!"
  echo ""
  echo "Comunidades disponíveis:"
  docker exec supabase-db psql -U postgres -d postgres -c "
  SELECT id, divisao_nome, segmento_nome
  FROM comunidades
  ORDER BY divisao_nome, segmento_nome
  LIMIT 10;
  "
  exit 1
fi

IFS='|' read -r ID DIVISAO SEGMENTO <<< "$COMMUNITY_INFO"
echo "   ✅ Comunidade encontrada:"
echo "      Divisão: $DIVISAO"
echo "      Segmento: $SEGMENTO"
echo ""

# Verificar se já existe
echo "2. Verificando cadastro existente..."
EXISTING=$(docker exec supabase-db psql -U postgres -d postgres -t -c "
SELECT COUNT(*) 
FROM telegram_communities 
WHERE community_id = '$COMMUNITY_ID';
" | xargs)

if [ "$EXISTING" != "0" ]; then
  echo "   ⚠️ Comunidade já tem supergrupo cadastrado."
  echo ""
  echo "   Cadastro atual:"
  docker exec supabase-db psql -U postgres -d postgres -c "
  SELECT 
      telegram_chat_id,
      created_at,
      updated_at
  FROM telegram_communities
  WHERE community_id = '$COMMUNITY_ID';
  "
  echo ""
  echo "   Atualizando para novo Chat ID: $TELEGRAM_CHAT_ID"
  docker exec supabase-db psql -U postgres -d postgres -c "
  UPDATE telegram_communities
  SET telegram_chat_id = $TELEGRAM_CHAT_ID,
      updated_at = NOW()
  WHERE community_id = '$COMMUNITY_ID';
  "
  echo "   ✅ Cadastro atualizado!"
else
  echo "   ✅ Criando novo cadastro..."
  docker exec supabase-db psql -U postgres -d postgres -c "
  INSERT INTO telegram_communities (community_id, telegram_chat_id)
  VALUES ('$COMMUNITY_ID', $TELEGRAM_CHAT_ID);
  "
  echo "   ✅ Cadastro criado!"
fi

echo ""
echo "3. Verificando cadastro final..."
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
    tc.id,
    c.divisao_nome as divisao,
    c.segmento_nome as segmento,
    tc.telegram_chat_id,
    tc.created_at,
    tc.updated_at
FROM telegram_communities tc
JOIN comunidades c ON c.id = tc.community_id
WHERE tc.community_id = '$COMMUNITY_ID';
"

echo ""
echo "4. Verificando tarefas desta comunidade..."
TASK_COUNT=$(docker exec supabase-db psql -U postgres -d postgres -t -c "
SELECT COUNT(*)
FROM grupos_chat gc
JOIN comunidades c ON c.id = gc.comunidade_id
WHERE c.id = '$COMMUNITY_ID';
" | xargs)

echo "   Tarefas nesta comunidade: $TASK_COUNT"
if [ "$TASK_COUNT" -gt 0 ]; then
  echo ""
  echo "   ⚠️ IMPORTANTE: Ao enviar mensagens do Flutter, os tópicos serão criados automaticamente."
  echo "   Não é necessário criar tópicos manualmente."
fi

echo ""
echo "=========================================="
echo "✅ SUPERGRUPO CADASTRADO COM SUCESSO!"
echo "=========================================="
echo ""
echo "Próximos passos:"
echo "  1. Certifique-se de que o supergrupo está configurado como Fórum (Topics)"
echo "  2. Torne o bot administrador do supergrupo"
echo "  3. Teste enviando uma mensagem do Flutter em uma tarefa desta comunidade"
echo ""
