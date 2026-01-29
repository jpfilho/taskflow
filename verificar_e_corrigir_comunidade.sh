#!/bin/bash
# ============================================
# VERIFICAR E CORRIGIR COMUNIDADE
# ============================================

COMMUNITY_ID="54f622b4-4dea-4ad3-af48-9e5dd4d12b35"

echo "==========================================="
echo "VERIFICAR E CORRIGIR COMUNIDADE"
echo "==========================================="
echo ""

echo "1. Verificando comunidade 'NEPTRFMT - Linhas de Transmissão':"
echo "-------------------------------------------"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  id,
  divisao_nome || ' - ' || segmento_nome as comunidade_nome
FROM comunidades
WHERE id = '$COMMUNITY_ID';
" 2>/dev/null

echo ""
echo "2. Verificando qual grupo Telegram está configurado:"
echo "-------------------------------------------"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  tc.id,
  tc.telegram_chat_id,
  c.divisao_nome || ' - ' || c.segmento_nome as comunidade_nome
FROM telegram_communities tc
JOIN comunidades c ON c.id = tc.comunidade_id
WHERE tc.comunidade_id = '$COMMUNITY_ID';
" 2>/dev/null

echo ""
echo "3. Verificando todos os grupos cadastrados:"
echo "-------------------------------------------"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  tc.telegram_chat_id,
  c.divisao_nome || ' - ' || c.segmento_nome as comunidade_nome,
  COUNT(DISTINCT tc.comunidade_id) as num_comunidades
FROM telegram_communities tc
JOIN comunidades c ON c.id = tc.comunidade_id
GROUP BY tc.telegram_chat_id, c.divisao_nome, c.segmento_nome
ORDER BY tc.telegram_chat_id;
" 2>/dev/null

echo ""
echo "4. Verificando qual grupo deveria ser usado:"
echo "-------------------------------------------"
echo "A comunidade 'NEPTRFMT - Linhas de Transmissão' precisa ter um grupo Telegram configurado."
echo ""
echo "Grupos disponíveis nos logs:"
echo "  - -1003721115749 (NEPTRFMT - Subestação)"
echo ""
echo "Se você criou um grupo 'NEPTRFMT - Linhas de Transmissão', obtenha o Chat ID e cadastre:"
echo "  .\cadastrar_grupo_comunidade.ps1 -CommunityId $COMMUNITY_ID -TelegramChatId <CHAT_ID>"
echo ""
