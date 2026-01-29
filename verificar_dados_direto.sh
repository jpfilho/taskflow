#!/bin/bash
# ============================================
# VERIFICAR DADOS DIRETO
# ============================================

echo "==========================================="
echo "VERIFICAR DADOS DIRETO"
echo "==========================================="
echo ""

echo "1. Testando conexão com banco..."
docker exec supabase-db psql -U postgres -d postgres -c "SELECT 1;" 2>&1

echo ""
echo "2. Contando registros em telegram_communities..."
docker exec supabase-db psql -U postgres -d postgres -t -A -c "SELECT COUNT(*) FROM telegram_communities;" 2>&1

echo ""
echo "3. Listando TODOS os registros (formato simples)..."
docker exec supabase-db psql -U postgres -d postgres -t -A -F'|' -c "
SELECT 
  id::text,
  comunidade_id::text,
  telegram_chat_id::text,
  created_at::text
FROM telegram_communities
LIMIT 10;
" 2>&1

echo ""
echo "4. Verificando estrutura da tabela..."
docker exec supabase-db psql -U postgres -d postgres -c "
\d telegram_communities
" 2>&1
