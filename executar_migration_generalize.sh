#!/bin/bash
# ============================================
# EXECUTAR MIGRATION TELEGRAM GENERALIZADO
# ============================================

echo "Executando migration para generalizar integração Telegram..."
echo ""

# Executar migration do arquivo
if [ -f "/root/20260124_telegram_generalize.sql" ]; then
  echo "Executando migration do arquivo local..."
  docker exec -i supabase-db psql -U postgres -d postgres < /root/20260124_telegram_generalize.sql
else
  echo "⚠️ Arquivo de migration não encontrado. Copie o arquivo primeiro."
  echo "   scp supabase/migrations/20260124_telegram_generalize.sql root@212.85.0.249:/root/"
  exit 1
fi

echo ""
echo "Verificando tabelas criadas..."
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('telegram_communities', 'telegram_task_topics', 'telegram_delivery_logs')
ORDER BY table_name;
"

echo ""
echo "✅ Migration concluída!"
