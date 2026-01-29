#!/bin/bash
# ============================================
# VINCULAR TELEGRAM - INTERATIVO
# ============================================

echo "==========================================="
echo "VINCULAR TELEGRAM - INTERATIVO"
echo "==========================================="
echo ""

# Variáveis
SUPABASE_URL="http://127.0.0.1:8000"
SUPABASE_SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjU4MTc5ODMsImV4cCI6MjA4MTE3Nzk4M30.MYcuHsPkBgYg_M1WVHKbtO3MQYalYNYOppr0Q3ynUgw"

echo "Para vincular sua conta Telegram, preciso de algumas informações:"
echo ""

# 1. Listar executores
echo "1. Listando executores disponíveis..."
psql -h 127.0.0.1 -U postgres -d postgres -c "
SELECT 
  id,
  nome,
  matricula,
  telefone,
  login
FROM executores
WHERE ativo = true
ORDER BY nome;
" 2>/dev/null

echo ""
read -p "Digite a MATRICULA do executor que deseja vincular: " MATRICULA

if [ -z "$MATRICULA" ]; then
  echo "❌ Matrícula não informada!"
  exit 1
fi

echo ""
read -p "Digite seu TELEGRAM USER ID (número, ex: 7807721517): " TELEGRAM_USER_ID

if [ -z "$TELEGRAM_USER_ID" ]; then
  echo "❌ Telegram User ID não informado!"
  echo ""
  echo "Como descobrir seu Telegram User ID:"
  echo "1. Envie uma mensagem no grupo do Telegram"
  echo "2. Execute: .\obter_telegram_user_id.ps1"
  echo "   (o script vai buscar o ID dos logs do servidor)"
  exit 1
fi

echo ""
read -p "Digite seu TELEGRAM USERNAME (opcional, ex: @seu_usuario): " TELEGRAM_USERNAME
read -p "Digite seu PRIMEIRO NOME no Telegram (opcional): " TELEGRAM_FIRST_NAME

# Remover @ do username se presente
TELEGRAM_USERNAME=$(echo "$TELEGRAM_USERNAME" | sed 's/^@//')

echo ""
echo "Vinculando..."
echo "  Matrícula: $MATRICULA"
echo "  Telegram User ID: $TELEGRAM_USER_ID"
echo "  Telegram Username: ${TELEGRAM_USERNAME:-'(não informado)'}"
echo "  Telegram First Name: ${TELEGRAM_FIRST_NAME:-'(não informado)'}"
echo ""

# SQL para vincular
SQL_VINCULAR="
DO \$\$
DECLARE
    executor_id UUID;
    executor_nome VARCHAR;
BEGIN
    -- Buscar executor
    SELECT id, nome INTO executor_id, executor_nome
    FROM executores 
    WHERE matricula = '$MATRICULA';
    
    IF executor_id IS NULL THEN
        RAISE EXCEPTION 'Executor com matricula % nao encontrado!', '$MATRICULA';
    END IF;
    
    RAISE NOTICE 'Executor encontrado: % (ID: %)', executor_nome, executor_id;
    
    -- Vincular Telegram
    INSERT INTO telegram_identities (
        user_id,
        telegram_user_id,
        telegram_username,
        telegram_first_name,
        linked_at
    ) VALUES (
        executor_id,
        $TELEGRAM_USER_ID,
        $(if [ -n "$TELEGRAM_USERNAME" ]; then echo "'$TELEGRAM_USERNAME'"; else echo "NULL"; fi),
        $(if [ -n "$TELEGRAM_FIRST_NAME" ]; then echo "'$TELEGRAM_FIRST_NAME'"; else echo "NULL"; fi),
        NOW()
    ) ON CONFLICT (telegram_user_id) DO UPDATE SET
        user_id = EXCLUDED.user_id,
        telegram_username = COALESCE(EXCLUDED.telegram_username, telegram_identities.telegram_username),
        telegram_first_name = COALESCE(EXCLUDED.telegram_first_name, telegram_identities.telegram_first_name),
        linked_at = NOW();
    
    RAISE NOTICE 'Telegram vinculado com sucesso!';
END \$\$;
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
    ti.telegram_first_name,
    ti.telegram_username,
    e.matricula,
    e.nome,
    ti.linked_at
  FROM telegram_identities ti
  JOIN executores e ON e.id = ti.user_id
  WHERE ti.telegram_user_id = $TELEGRAM_USER_ID;
  " 2>/dev/null
  
  echo ""
  echo "Agora você pode enviar mensagens no Telegram e elas aparecerão no Flutter!"
else
  echo ""
  echo "❌ Erro ao vincular!"
fi
