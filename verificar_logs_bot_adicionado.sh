#!/bin/bash
# ============================================
# VERIFICAR LOGS QUANDO BOT FOI ADICIONADO
# ============================================

echo "==========================================="
echo "VERIFICAR LOGS - BOT ADICIONADO"
echo "==========================================="
echo ""

echo "1. Últimas 100 linhas de log:"
echo "-------------------------------------------"
journalctl -u telegram-webhook -n 100 --no-pager | tail -50
echo ""

echo "2. Buscando eventos de 'new_chat_members' ou 'Bot adicionado':"
echo "-------------------------------------------"
journalctl -u telegram-webhook -n 200 --no-pager | grep -iE "(new_chat_members|bot adicionado|handleBotAddedToGroup|Supergrupo com tópicos)" || echo "Nenhum evento encontrado"
echo ""

echo "3. Buscando updates recebidos recentemente:"
echo "-------------------------------------------"
journalctl -u telegram-webhook -n 200 --no-pager | grep "Update recebido" | tail -5
echo ""

echo "4. Verificando se há erros:"
echo "-------------------------------------------"
journalctl -u telegram-webhook -n 200 --no-pager | grep -iE "(erro|error|❌)" | tail -10
echo ""

echo "5. Verificando se o grupo foi cadastrado:"
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
LIMIT 5;
" 2>/dev/null
