#!/bin/bash
# ============================================
# CADASTRAR TODAS AS COMUNIDADES FALTANTES
# ============================================

TELEGRAM_CHAT_ID="${1:-1003721115749}"

echo "=========================================="
echo "CADASTRAR COMUNIDADES FALTANTES"
echo "=========================================="
echo ""
echo "Telegram Chat ID: $TELEGRAM_CHAT_ID"
echo ""

# Buscar comunidades sem supergrupo configurado
echo "Buscando comunidades sem supergrupo configurado..."
COMUNIDADES_SEM_TELEGRAM=$(docker exec supabase-db psql -U postgres -d postgres -t -A -F'|' -c "
SELECT 
    c.id,
    c.divisao_nome,
    c.segmento_nome
FROM comunidades c
LEFT JOIN telegram_communities tc ON tc.community_id = c.id
WHERE tc.id IS NULL
ORDER BY c.divisao_nome, c.segmento_nome;
")

if [ -z "$COMUNIDADES_SEM_TELEGRAM" ]; then
  echo "✅ Todas as comunidades já têm supergrupo configurado!"
  exit 0
fi

# Contar quantas serão cadastradas
COUNT=$(echo "$COMUNIDADES_SEM_TELEGRAM" | grep -c "|" || echo "0")
echo "Encontradas $COUNT comunidades sem supergrupo."
echo ""

if [ "$COUNT" -eq 0 ]; then
  echo "✅ Todas as comunidades já têm supergrupo configurado!"
  exit 0
fi

echo "Cadastrando todas automaticamente..."
echo ""

# Processar cada comunidade
CADASTRADAS=0
ERROS=0

while IFS='|' read -r ID DIVISAO SEGMENTO; do
  if [ -z "$ID" ]; then
    continue
  fi
  
  echo "  Cadastrando: $DIVISAO - $SEGMENTO"
  
  # Inserir ou atualizar
  RESULT=$(docker exec supabase-db psql -U postgres -d postgres -t -c "
  INSERT INTO telegram_communities (community_id, telegram_chat_id)
  VALUES ('$ID', $TELEGRAM_CHAT_ID)
  ON CONFLICT (community_id) 
  DO UPDATE SET 
    telegram_chat_id = $TELEGRAM_CHAT_ID,
    updated_at = NOW()
  RETURNING id;
  " 2>&1)
  
  if [ $? -eq 0 ]; then
    echo "    ✅ Cadastrada"
    CADASTRADAS=$((CADASTRADAS + 1))
  else
    echo "    ❌ Erro: $RESULT"
    ERROS=$((ERROS + 1))
  fi
done <<< "$COMUNIDADES_SEM_TELEGRAM"

echo ""
echo "=========================================="
echo "RESUMO"
echo "=========================================="
echo "  Cadastradas: $CADASTRADAS"
echo "  Erros: $ERROS"
echo ""

if [ $CADASTRADAS -gt 0 ]; then
  echo "Verificando cadastros..."
  docker exec supabase-db psql -U postgres -d postgres -c "
  SELECT 
      COUNT(*) as total_cadastradas,
      COUNT(DISTINCT telegram_chat_id) as supergrupos_unicos
  FROM telegram_communities;
  "
fi

echo ""
echo "✅ Processo concluído!"
