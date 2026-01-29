#!/bin/bash
# ============================================
# OBTER CHAT ID DO GRUPO NEPTRFMT - LINHAS DE TRANSMISSÃO
# ============================================

echo "==========================================="
echo "OBTER CHAT ID DO GRUPO"
echo "==========================================="
echo ""

echo "Buscando Chat ID nos logs mais recentes..."
echo "-------------------------------------------"

# Buscar nos logs
CHAT_IDS=$(journalctl -u telegram-webhook -n 1000 --no-pager | grep -i "linhas de transmissão" -A 10 -B 10 | grep '"id":' | grep -oE '"-?[0-9]+"' | sort -u)

if [ -n "$CHAT_IDS" ]; then
  echo "Chat IDs encontrados nos logs relacionados a 'Linhas de Transmissão':"
  echo "$CHAT_IDS" | while read -r id; do
    echo "  - $id"
  done
  echo ""
  echo "Chat ID mais recente: $(echo "$CHAT_IDS" | head -1 | tr -d '"')"
  echo ""
  echo "Se este for o Chat ID correto, use:"
  echo "  .\cadastrar_grupo_linhas_transmissao.ps1 -TelegramChatId $(echo "$CHAT_IDS" | head -1 | tr -d '"')"
else
  echo "⚠️ Chat ID não encontrado nos logs"
  echo ""
  echo "Para obter o Chat ID:"
  echo "1. Envie uma mensagem no grupo 'NEPTRFMT - Linhas de Transmissão'"
  echo "2. Execute: journalctl -u telegram-webhook -f"
  echo "3. Procure por 'chat' e 'id' no log"
  echo ""
  echo "Ou use o bot @getidsbot no Telegram"
  echo ""
  echo "Depois, execute:"
  echo "  .\cadastrar_grupo_linhas_transmissao.ps1 -TelegramChatId <CHAT_ID>"
fi
