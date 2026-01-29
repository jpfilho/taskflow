#!/bin/bash
# ============================================
# VERIFICAR ESTRUTURA DA TABELA COMUNIDADES
# ============================================

echo "==========================================="
echo "ESTRUTURA DA TABELA COMUNIDADES"
echo "==========================================="
echo ""

echo "1. Colunas da tabela comunidades:"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'comunidades'
ORDER BY ordinal_position;
" 2>/dev/null

echo ""
echo "2. Estrutura da tabela telegram_communities:"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'telegram_communities'
ORDER BY ordinal_position;
" 2>/dev/null

echo ""
echo "3. Dados da tabela comunidades (primeiras 5 linhas):"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT * FROM comunidades LIMIT 5;
" 2>/dev/null

echo ""
echo "4. Dados da tabela telegram_communities:"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT * FROM telegram_communities;
" 2>/dev/null

echo ""
echo "5. Tentando JOIN entre as tabelas:"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  tc.id,
  tc.comunidade_id,
  tc.telegram_chat_id,
  c.*
FROM telegram_communities tc
LEFT JOIN comunidades c ON c.id = tc.comunidade_id
LIMIT 5;
" 2>/dev/null
