#!/bin/bash
# ============================================
# VERIFICAR CONFIGURAÇÃO DO GRUPO TELEGRAM
# ============================================

echo "==========================================="
echo "VERIFICAR CONFIGURAÇÃO DO GRUPO"
echo "==========================================="
echo ""

echo "1. Verificando logs recentes do grupo 'NEPTRFMT - Linhas de Transmissão':"
echo "-------------------------------------------"
journalctl -u telegram-webhook -n 200 --no-pager | grep "NEPTRFMT - Linhas de Transmissão" -A 10 -B 5 | grep -E "(type|is_forum|chat|id)" | head -30
echo ""

echo "2. Buscando Chat ID do grupo:"
echo "-------------------------------------------"
CHAT_ID=$(journalctl -u telegram-webhook -n 500 --no-pager | grep "NEPTRFMT - Linhas de Transmissão" | grep '"id":' | grep -oE '"-?[0-9]+"' | tail -1 | tr -d '"')

if [ -n "$CHAT_ID" ]; then
  echo "✅ Chat ID encontrado: $CHAT_ID"
  echo ""
  echo "3. Verificando se o grupo está cadastrado:"
  echo "-------------------------------------------"
  docker exec supabase-db psql -U postgres -d postgres -c "
  SELECT 
    tc.id,
    tc.telegram_chat_id,
    c.divisao_nome || ' - ' || c.segmento_nome as comunidade,
    TO_CHAR(tc.created_at, 'DD/MM/YYYY HH24:MI:SS') as cadastrado_em
  FROM telegram_communities tc
  JOIN comunidades c ON c.id = tc.comunidade_id
  WHERE tc.telegram_chat_id = $CHAT_ID;
  " 2>/dev/null
  
  if [ $? -ne 0 ] || [ -z "$(docker exec supabase-db psql -U postgres -d postgres -t -c "SELECT id FROM telegram_communities WHERE telegram_chat_id = $CHAT_ID;" 2>/dev/null)" ]; then
    echo "❌ Grupo não está cadastrado no banco"
  fi
else
  echo "⚠️ Chat ID não encontrado nos logs"
  echo ""
  echo "Para obter o Chat ID:"
  echo "1. Envie uma mensagem no grupo"
  echo "2. Execute: journalctl -u telegram-webhook -f"
  echo "3. Procure por 'chat' e 'id' no log"
fi

echo ""
echo "4. INSTRUÇÕES PARA CONFIGURAR O GRUPO:"
echo "-------------------------------------------"
echo ""
echo "Para que o grupo funcione corretamente com o TaskFlow:"
echo ""
echo "1. ✅ Certifique-se de que o grupo é um SUPERGRUPO"
echo "   - Se ainda não for, converta:"
echo "     Configurações do Grupo → Converter para Supergrupo"
echo ""
echo "2. ✅ Habilite TÓPICOS (Fórum)"
echo "   - Configurações do Grupo → Tipo → Fórum"
echo "   - Ative os tópicos"
echo ""
echo "3. ✅ Torne o bot ADMINISTRADOR"
echo "   - Adicione o bot @TaskFlow_chat_bot"
echo "   - Torne-o administrador"
echo "   - Dê permissão 'Manage Topics' (Gerenciar Tópicos)"
echo ""
echo "4. ✅ Depois de configurar, envie uma mensagem no grupo"
echo "   - O bot detectará automaticamente"
echo "   - Ou use o comando: /associar <ID_DA_COMUNIDADE>"
echo ""
