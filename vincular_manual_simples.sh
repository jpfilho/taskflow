#!/bin/bash
# ============================================
# VINCULAR TELEGRAM - MANUAL SIMPLES
# ============================================

echo "==========================================="
echo "VINCULAR TELEGRAM - MANUAL"
echo "==========================================="
echo ""

read -p "Digite o EMAIL do usuario (do Flutter): " EMAIL_USUARIO

if [ -z "$EMAIL_USUARIO" ]; then
  echo "❌ Email não informado!"
  exit 1
fi

echo ""
echo "Buscando executor pelo login (email)..."
psql -h 127.0.0.1 -U postgres -d postgres -c "
SELECT 
  id,
  nome,
  matricula,
  login,
  telefone
FROM executores
WHERE login = '$EMAIL_USUARIO'
LIMIT 5;
" 2>/dev/null

echo ""
read -p "Digite o ID do executor encontrado acima (ou deixe vazio se não encontrou): " EXECUTOR_ID

if [ -z "$EXECUTOR_ID" ]; then
  echo ""
  echo "Listando todos os executores para você escolher:"
  psql -h 127.0.0.1 -U postgres -d postgres -c "
  SELECT 
    id,
    nome,
    matricula,
    login,
    telefone
  FROM executores
  WHERE ativo = true
  ORDER BY nome
  LIMIT 20;
  " 2>/dev/null
  
  echo ""
  read -p "Digite o ID do executor que deseja vincular: " EXECUTOR_ID
fi

if [ -z "$EXECUTOR_ID" ]; then
  echo "❌ ID do executor não informado!"
  exit 1
fi

echo ""
read -p "Digite seu TELEGRAM USER ID (número, ex: 7807721517): " TELEGRAM_USER_ID

if [ -z "$TELEGRAM_USER_ID" ]; then
  echo "❌ Telegram User ID não informado!"
  echo ""
  echo "Para descobrir:"
  echo "1. Envie uma mensagem no grupo do Telegram"
  echo "2. Execute: .\obter_telegram_user_id.ps1"
  exit 1
fi

echo ""
echo "Vinculando..."
echo "  Executor ID: $EXECUTOR_ID"
echo "  Telegram User ID: $TELEGRAM_USER_ID"
echo ""

SQL_VINCULAR="
INSERT INTO telegram_identities (
  user_id,
  telegram_user_id,
  linked_at,
  last_active_at
) VALUES (
  '$EXECUTOR_ID',
  $TELEGRAM_USER_ID,
  NOW(),
  NOW()
) ON CONFLICT (telegram_user_id) DO UPDATE SET
  user_id = EXCLUDED.user_id,
  linked_at = NOW(),
  last_active_at = NOW();
"

psql -h 127.0.0.1 -U postgres -d postgres -c "$SQL_VINCULAR" 2>/dev/null

if [ $? -eq 0 ]; then
  echo ""
  echo "✅ Vinculação concluída!"
  echo ""
  echo "Verificando vinculação..."
  psql -h 127.0.0.1 -U postgres -d postgres -c "
  SELECT 
    ti.telegram_user_id,
    e.nome,
    e.matricula,
    ti.linked_at
  FROM telegram_identities ti
  JOIN executores e ON e.id = ti.user_id
  WHERE ti.telegram_user_id = $TELEGRAM_USER_ID;
  " 2>/dev/null
else
  echo ""
  echo "❌ Erro ao vincular!"
fi
