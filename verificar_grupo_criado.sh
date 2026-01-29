#!/bin/bash
# ============================================
# VERIFICAR SE O GRUPO FOI CADASTRADO
# ============================================

echo "==========================================="
echo "VERIFICAR GRUPO CRIADO"
echo "==========================================="
echo ""

echo "1. Logs mais recentes do servidor (últimas 100 linhas):"
echo "-------------------------------------------"
journalctl -u telegram-webhook -n 100 --no-pager | tail -50
echo ""

echo "2. Buscando logs de 'Bot adicionado' ou 'handleBotAddedToGroup':"
echo "-------------------------------------------"
journalctl -u telegram-webhook -n 200 --no-pager | grep -iE "(bot adicionado|handleBotAddedToGroup|new_chat_member|group_chat_created|NEPTRFMT)" || echo "Nenhum log encontrado"
echo ""

echo "3. Verificando grupos cadastrados no banco:"
echo "-------------------------------------------"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  tc.id,
  tc.telegram_chat_id,
  c.divisao_nome || ' - ' || c.segmento_nome as comunidade,
  TO_CHAR(tc.created_at, 'DD/MM/YYYY HH24:MI:SS') as cadastrado_em
FROM telegram_communities tc
JOIN comunidades c ON c.id = tc.comunidade_id
ORDER BY tc.created_at DESC
LIMIT 10;
" 2>/dev/null

echo ""
echo "4. Verificando comunidades que contêm 'NEPTRFMT' ou 'Linhas de Transmissão':"
echo "-------------------------------------------"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  id,
  divisao_nome || ' - ' || segmento_nome as comunidade_nome,
  divisao_nome,
  segmento_nome
FROM comunidades
WHERE 
  LOWER(divisao_nome) LIKE '%neptrfmt%' OR
  LOWER(segmento_nome) LIKE '%neptrfmt%' OR
  LOWER(divisao_nome) LIKE '%linhas%' OR
  LOWER(segmento_nome) LIKE '%linhas%' OR
  LOWER(divisao_nome) LIKE '%transmissão%' OR
  LOWER(segmento_nome) LIKE '%transmissão%'
ORDER BY divisao_nome, segmento_nome;
" 2>/dev/null

echo ""
echo "5. Todas as comunidades disponíveis:"
echo "-------------------------------------------"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  id,
  divisao_nome || ' - ' || segmento_nome as comunidade_nome
FROM comunidades
ORDER BY divisao_nome, segmento_nome;
" 2>/dev/null
