#!/bin/bash
# ============================================
# VERIFICAR VINCULACAO DO JOSE
# ============================================

echo "==========================================="
echo "VERIFICAR VINCULACAO DO JOSE"
echo "==========================================="
echo ""

echo "1. Buscando vinculacoes com nome JOSE..."
psql -h 127.0.0.1 -U postgres -d postgres -c "
SELECT 
  ti.telegram_user_id,
  ti.telegram_first_name,
  ti.telegram_username,
  e.id as executor_id,
  e.nome as executor_nome,
  e.matricula,
  e.login,
  ti.linked_at
FROM telegram_identities ti
LEFT JOIN executores e ON e.id = ti.user_id
WHERE ti.telegram_first_name ILIKE '%JOSE%' OR e.nome ILIKE '%JOSE%'
ORDER BY ti.linked_at DESC;
" 2>/dev/null

echo ""
echo "2. Buscando mensagens recentes do JOSE..."
psql -h 127.0.0.1 -U postgres -d postgres -c "
SELECT 
  m.id,
  m.usuario_id,
  m.usuario_nome,
  LEFT(m.conteudo, 50) as conteudo_preview,
  m.source,
  m.created_at,
  (m.telegram_metadata->>'from_id')::bigint as telegram_user_id,
  (m.telegram_metadata->>'first_name') as telegram_first_name
FROM mensagens m
WHERE m.usuario_nome ILIKE '%JOSE%' OR (m.telegram_metadata->>'first_name') ILIKE '%JOSE%'
ORDER BY m.created_at DESC
LIMIT 5;
" 2>/dev/null

echo ""
echo "3. Verificando todos os telegram_user_id que enviaram mensagens..."
psql -h 127.0.0.1 -U postgres -d postgres -c "
SELECT DISTINCT
  (m.telegram_metadata->>'from_id')::bigint as telegram_user_id,
  (m.telegram_metadata->>'first_name') as telegram_first_name,
  COUNT(*) as total_mensagens
FROM mensagens m
WHERE m.source = 'telegram' AND m.telegram_metadata IS NOT NULL
GROUP BY telegram_user_id, telegram_first_name
ORDER BY total_mensagens DESC;
" 2>/dev/null
