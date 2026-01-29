#!/bin/bash
# ============================================
# VERIFICAR COMUNIDADES SEM SUPERGRUPO
# ============================================

echo "==========================================="
echo "VERIFICAR COMUNIDADES SEM SUPERGRUPO"
echo "==========================================="
echo ""

echo "1. Total de comunidades:"
docker exec supabase-db psql -U postgres -d postgres -t -c "
SELECT COUNT(*) FROM comunidades;
" 2>/dev/null

echo ""
echo "2. Comunidades SEM supergrupo configurado:"
RESULT=$(docker exec supabase-db psql -U postgres -d postgres -t -c "
SELECT COUNT(*) 
FROM comunidades c
LEFT JOIN telegram_communities tc ON tc.comunidade_id = c.id
WHERE tc.id IS NULL;
" 2>/dev/null | tr -d ' ')

if [ -z "$RESULT" ] || [ "$RESULT" = "0" ]; then
  echo "   ✅ Todas as comunidades têm supergrupo configurado!"
else
  echo "   ⚠️  Encontradas $RESULT comunidades sem supergrupo:"
  docker exec supabase-db psql -U postgres -d postgres -c "
  SELECT 
    c.id,
    c.nome,
    c.created_at
  FROM comunidades c
  LEFT JOIN telegram_communities tc ON tc.comunidade_id = c.id
  WHERE tc.id IS NULL
  ORDER BY c.nome;
  " 2>/dev/null
fi

echo ""
echo "3. Comunidades COM supergrupo configurado:"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  c.id,
  c.nome,
  tc.telegram_chat_id,
  TO_CHAR(tc.created_at, 'DD/MM/YYYY HH24:MI:SS') as cadastrado_em
FROM comunidades c
INNER JOIN telegram_communities tc ON tc.comunidade_id = c.id
ORDER BY c.nome;
" 2>/dev/null
