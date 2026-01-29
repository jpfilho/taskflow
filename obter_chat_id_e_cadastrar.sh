#!/bin/bash
# ============================================
# OBTER CHAT ID E CADASTRAR GRUPO
# ============================================

echo "==========================================="
echo "OBTER CHAT ID E CADASTRAR GRUPO"
echo "==========================================="
echo ""

# Obter Chat ID do grupo via API do Telegram
echo "1. Obtendo informações do bot..."
BOT_TOKEN="8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec"

# Tentar obter updates pendentes (pode não funcionar se webhook estiver ativo)
echo ""
echo "2. Verificando se há updates pendentes..."
UPDATES=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?offset=-10" | jq -r '.result[] | select(.message.chat.type == "supergroup" or .message.chat.type == "group") | "Chat ID: \(.message.chat.id), Nome: \(.message.chat.title), Tipo: \(.message.chat.type)"' 2>/dev/null)

if [ -n "$UPDATES" ]; then
  echo "$UPDATES"
else
  echo "Nenhum update encontrado (webhook pode estar ativo)"
fi

echo ""
echo "3. Para obter o Chat ID manualmente:"
echo "   - Envie uma mensagem no grupo"
echo "   - Ou use o bot @getidsbot"
echo "   - Ou veja os logs do servidor quando enviar uma mensagem"
echo ""

echo "4. Comunidades disponíveis para cadastro:"
echo "-------------------------------------------"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  c.id,
  c.divisao_nome || ' - ' || c.segmento_nome as comunidade_nome,
  CASE 
    WHEN tc.id IS NOT NULL THEN '✅ TEM GRUPO'
    ELSE '❌ SEM GRUPO'
  END as status
FROM comunidades c
LEFT JOIN telegram_communities tc ON tc.comunidade_id = c.id
ORDER BY 
  CASE WHEN tc.id IS NOT NULL THEN 0 ELSE 1 END,
  c.divisao_nome, 
  c.segmento_nome;
" 2>/dev/null

echo ""
echo "5. Para cadastrar manualmente, use:"
echo "   .\cadastrar_grupo_comunidade.ps1 -CommunityId <ID> -TelegramChatId <CHAT_ID>"
echo ""
