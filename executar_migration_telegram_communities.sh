#!/bin/bash
# ============================================
# EXECUTAR MIGRATION TELEGRAM_COMMUNITIES
# ============================================

echo "==========================================="
echo "ATUALIZANDO TELEGRAM_COMMUNITIES"
echo "==========================================="
echo ""

echo "Copiando migration para o container..."
docker cp /tmp/20260125_atualizar_telegram_communities.sql supabase-db:/tmp/ 2>&1

echo ""
echo "Executando migration..."
docker exec supabase-db psql -U postgres -d postgres -f /tmp/20260125_atualizar_telegram_communities.sql 2>&1

if [ $? -eq 0 ]; then
  echo ""
  echo "✅ Migration executada com sucesso!"
  echo ""
  echo "Verificando estrutura da tabela..."
  docker exec supabase-db psql -U postgres -d postgres -c "\d telegram_communities" 2>&1
else
  echo ""
  echo "❌ Erro ao executar migration!"
  exit 1
fi
