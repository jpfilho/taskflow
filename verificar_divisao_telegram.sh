#!/bin/bash
# ============================================
# VERIFICAR DIVISÃO ESPECÍFICA NO TELEGRAM
# ============================================
# Verifica se uma divisão específica tem Chat ID cadastrado

if [ -z "$1" ]; then
  echo "Uso: $0 <nome_da_divisao>"
  echo "Exemplo: $0 NEPTRFMT"
  exit 1
fi

DIVISAO_NOME="$1"

echo "==========================================="
echo "VERIFICAR DIVISÃO: $DIVISAO_NOME"
echo "==========================================="
echo ""

echo "1. Buscando divisão..."
DIVISAO_ID=$(docker exec supabase-db psql -U postgres -d postgres -t -A -c "
SELECT id FROM divisoes WHERE divisao ILIKE '%$DIVISAO_NOME%' LIMIT 1;
" 2>/dev/null | tr -d ' ')

if [ -z "$DIVISAO_ID" ]; then
  echo "❌ Divisão '$DIVISAO_NOME' não encontrada!"
  echo ""
  echo "Divisões disponíveis:"
  docker exec supabase-db psql -U postgres -d postgres -c "
  SELECT divisao FROM divisoes ORDER BY divisao;
  " 2>/dev/null
  exit 1
fi

echo "✅ Divisão encontrada: ID = $DIVISAO_ID"
echo ""

echo "2. Segmentos da divisão:"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  s.segmento,
  ds.segmento_id
FROM divisoes_segmentos ds
INNER JOIN segmentos s ON s.id = ds.segmento_id
WHERE ds.divisao_id = '$DIVISAO_ID'
ORDER BY s.segmento;
" 2>/dev/null

echo ""
echo "3. Comunidades criadas para esta divisão:"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  c.id as comunidade_id,
  c.divisao_nome || ' - ' || c.segmento_nome as comunidade_nome,
  c.segmento_id
FROM comunidades c
WHERE c.divisao_id = '$DIVISAO_ID'
ORDER BY c.segmento_nome;
" 2>/dev/null

echo ""
echo "4. Status do Chat ID do Telegram para cada comunidade:"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  c.divisao_nome || ' - ' || c.segmento_nome as comunidade_nome,
  CASE 
    WHEN tc.telegram_chat_id IS NOT NULL THEN '✅ Cadastrado'
    ELSE '❌ Não cadastrado'
  END as status,
  tc.telegram_chat_id,
  TO_CHAR(tc.created_at, 'DD/MM/YYYY HH24:MI:SS') as cadastrado_em
FROM comunidades c
LEFT JOIN telegram_communities tc ON tc.community_id = c.id
WHERE c.divisao_id = '$DIVISAO_ID'
ORDER BY c.segmento_nome;
" 2>/dev/null

echo ""
echo "5. Resumo:"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  COUNT(*) as total_comunidades,
  COUNT(tc.id) as com_chat_id,
  COUNT(*) - COUNT(tc.id) as sem_chat_id
FROM comunidades c
LEFT JOIN telegram_communities tc ON tc.community_id = c.id
WHERE c.divisao_id = '$DIVISAO_ID';
" 2>/dev/null
