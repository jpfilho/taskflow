#!/bin/bash
# ============================================
# VERIFICAR IDENTIFICAÇÃO DE GRUPOS
# ============================================

echo "==========================================="
echo "VERIFICAR IDENTIFICAÇÃO DE GRUPOS"
echo "==========================================="
echo ""

echo "1. Verificando qual arquivo o serviço está usando..."
echo "-------------------------------------------"
systemctl cat telegram-webhook | grep "ExecStart" || echo "Não foi possível verificar"
echo ""

echo "2. Verificando logs recentes de identificação..."
echo "-------------------------------------------"
journalctl -u telegram-webhook -n 100 --no-pager | grep -E "(🤖 Bot adicionado|✅ Grupo cadastrado|⚠️.*Match|/associar|handleBotAddedToGroup|cadastrarGrupoParaComunidade)" || echo "Nenhum log de identificação encontrado"
echo ""

echo "3. Status atual das comunidades e grupos:"
echo "-------------------------------------------"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  c.id as community_id,
  c.divisao_nome || ' - ' || c.segmento_nome as comunidade_nome,
  CASE 
    WHEN tc.id IS NOT NULL THEN '✅ SIM'
    ELSE '❌ NÃO'
  END as tem_grupo,
  tc.telegram_chat_id,
  TO_CHAR(tc.created_at, 'DD/MM/YYYY HH24:MI:SS') as cadastrado_em
FROM comunidades c
LEFT JOIN telegram_communities tc ON tc.comunidade_id = c.id
ORDER BY 
  CASE WHEN tc.id IS NOT NULL THEN 0 ELSE 1 END,
  c.divisao_nome, 
  c.segmento_nome;
" 2>/dev/null

echo ""
echo "4. Grupos cadastrados no Telegram:"
echo "-------------------------------------------"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  tc.telegram_chat_id,
  c.divisao_nome || ' - ' || c.segmento_nome as comunidade,
  TO_CHAR(tc.created_at, 'DD/MM/YYYY HH24:MI:SS') as cadastrado_em
FROM telegram_communities tc
JOIN comunidades c ON c.id = tc.comunidade_id
ORDER BY tc.created_at DESC;
" 2>/dev/null

echo ""
echo "5. Últimas 30 linhas de log do servidor:"
echo "-------------------------------------------"
journalctl -u telegram-webhook -n 30 --no-pager | tail -30
