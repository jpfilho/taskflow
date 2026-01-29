#!/bin/bash
# ============================================
# LISTAR TODAS AS VINCULACOES
# ============================================

echo "==========================================="
echo "TODAS AS VINCULACOES"
echo "==========================================="
echo ""

psql -h 127.0.0.1 -U postgres -d postgres <<EOF
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
ORDER BY ti.linked_at DESC;
EOF

echo ""
echo "==========================================="
echo "MENSAGENS DO TELEGRAM (últimas 5)"
echo "==========================================="
echo ""

psql -h 127.0.0.1 -U postgres -d postgres <<EOF
SELECT 
  m.id,
  m.usuario_id,
  m.usuario_nome,
  LEFT(m.conteudo, 30) as conteudo,
  m.source,
  TO_CHAR(m.created_at, 'DD/MM/YYYY HH24:MI:SS') as data,
  (m.telegram_metadata->>'from_id')::bigint as telegram_user_id,
  (m.telegram_metadata->>'first_name') as telegram_first_name
FROM mensagens m
WHERE m.source = 'telegram'
ORDER BY m.created_at DESC
LIMIT 5;
EOF
