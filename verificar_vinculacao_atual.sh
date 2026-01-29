#!/bin/bash
# ============================================
# VERIFICAR VINCULACAO ATUAL
# ============================================

echo "==========================================="
echo "VERIFICAR VINCULACAO ATUAL"
echo "==========================================="
echo ""

echo "1. Verificando todas as vinculacoes existentes..."
result1=$(psql -h 127.0.0.1 -U postgres -d postgres -t -c "
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
" 2>/dev/null)

if [ -z "$result1" ] || [ "$(echo "$result1" | wc -l)" -le 1 ]; then
  echo "   Nenhuma vinculacao encontrada."
else
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
ORDER BY ti.linked_at DESC;
" 2>/dev/null
fi

echo ""
echo "2. Verificando mensagens recentes do Telegram..."
result2=$(psql -h 127.0.0.1 -U postgres -d postgres -t -c "
SELECT COUNT(*) 
FROM mensagens 
WHERE source = 'telegram';
" 2>/dev/null | tr -d ' ')

if [ -z "$result2" ] || [ "$result2" = "0" ]; then
  echo "   Nenhuma mensagem do Telegram encontrada."
else
  echo "   Total de mensagens do Telegram: $result2"
  psql -h 127.0.0.1 -U postgres -d postgres -c "
SELECT 
  m.id,
  m.usuario_id,
  m.usuario_nome,
  LEFT(m.conteudo, 50) as conteudo_preview,
  m.source,
  m.created_at,
  (m.telegram_metadata->>'from_id')::bigint as telegram_user_id
FROM mensagens m
WHERE m.source = 'telegram'
ORDER BY m.created_at DESC
LIMIT 10;
" 2>/dev/null
fi

echo ""
echo "3. Verificando se há mensagens sem usuario_id (não vinculadas)..."
psql -h 127.0.0.1 -U postgres -d postgres -c "
SELECT 
  COUNT(*) as total_mensagens_telegram,
  COUNT(DISTINCT usuario_id) as usuarios_unicos,
  COUNT(CASE WHEN usuario_id IS NULL THEN 1 END) as sem_usuario_id
FROM mensagens
WHERE source = 'telegram';
" 2>/dev/null
