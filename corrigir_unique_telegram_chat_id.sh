#!/bin/bash
# ============================================
# CORRIGIR UNIQUE DE telegram_chat_id
# ============================================

echo "Removendo constraint UNIQUE de telegram_chat_id..."
echo ""

# Remover constraint (método direto)
docker exec supabase-db psql -U postgres -d postgres -c "ALTER TABLE telegram_communities DROP CONSTRAINT IF EXISTS telegram_communities_telegram_chat_id_key;"

# Verificar se foi removida
CONSTRAINT_EXISTS=$(docker exec supabase-db psql -U postgres -d postgres -t -c "
SELECT COUNT(*) 
FROM information_schema.table_constraints 
WHERE table_name = 'telegram_communities' 
  AND constraint_name = 'telegram_communities_telegram_chat_id_key';
" | xargs)

if [ "$CONSTRAINT_EXISTS" != "0" ]; then
  echo "⚠️ Constraint ainda existe. Tentando remover com nome completo..."
  docker exec supabase-db psql -U postgres -d postgres -c "ALTER TABLE telegram_communities DROP CONSTRAINT telegram_communities_telegram_chat_id_key CASCADE;"
fi

# Adicionar índice (sem UNIQUE) para performance
docker exec supabase-db psql -U postgres -d postgres -c "CREATE INDEX IF NOT EXISTS idx_telegram_communities_chat_id ON telegram_communities(telegram_chat_id);"

echo ""
echo "Verificando constraints..."
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
    constraint_name,
    constraint_type
FROM information_schema.table_constraints
WHERE table_name = 'telegram_communities'
  AND constraint_type = 'UNIQUE';
"

echo ""
echo "✅ Constraint removida! Agora múltiplas comunidades podem usar o mesmo supergrupo."
