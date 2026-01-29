#!/bin/bash
# ============================================
# CRIAR SUBSCRIPTIONS AUTOMATICAMENTE
# ============================================

CHAT_ID="$1"

if [ -z "$CHAT_ID" ]; then
    echo "Erro: Chat ID nao fornecido!"
    echo "Uso: $0 <chat_id>"
    exit 1
fi

echo "=========================================="
echo "CRIAR SUBSCRIPTIONS AUTOMATICAMENTE"
echo "=========================================="
echo ""
echo "Chat ID Telegram: $CHAT_ID"
echo ""

# Buscar todos os grupos
echo "Buscando todos os grupos..."
GRUPOS=$(docker exec supabase-db psql -U postgres -d postgres -t -c "SELECT id, tarefa_nome FROM grupos_chat ORDER BY created_at DESC;")

if [ -z "$GRUPOS" ]; then
    echo "Nenhum grupo encontrado!"
    exit 1
fi

echo "Grupos encontrados:"
echo "$GRUPOS"
echo ""
echo "Criando subscriptions..."
echo ""

# Contador
TOTAL=0
SUCESSO=0
ERRO=0

# Para cada grupo, criar subscription
while IFS='|' read -r GRUPO_ID TAREFA_NOME; do
    GRUPO_ID=$(echo "$GRUPO_ID" | xargs)
    TAREFA_NOME=$(echo "$TAREFA_NOME" | xargs)
    
    if [ -z "$GRUPO_ID" ]; then
        continue
    fi
    
    TOTAL=$((TOTAL + 1))
    
    echo "[$TOTAL] Criando subscription para: $TAREFA_NOME"
    
    RESULT=$(docker exec supabase-db psql -U postgres -d postgres -t -c "
        INSERT INTO telegram_subscriptions (
            thread_type,
            thread_id,
            mode,
            telegram_chat_id,
            telegram_topic_id,
            active
        ) VALUES (
            'TASK',
            '$GRUPO_ID',
            'group_plain',
            $CHAT_ID,
            NULL,
            true
        ) ON CONFLICT (thread_type, thread_id, telegram_chat_id, telegram_topic_id)
        DO UPDATE SET
            active = true,
            updated_at = NOW()
        RETURNING id;
    " 2>&1)
    
    if [ $? -eq 0 ]; then
        SUCESSO=$((SUCESSO + 1))
        echo "    ✓ Sucesso"
    else
        ERRO=$((ERRO + 1))
        echo "    ✗ Erro: $RESULT"
    fi
done <<< "$GRUPOS"

echo ""
echo "=========================================="
echo "RESUMO"
echo "=========================================="
echo "Total de grupos: $TOTAL"
echo "Subscriptions criadas: $SUCESSO"
echo "Erros: $ERRO"
echo ""

# Verificar subscriptions criadas
echo "Verificando subscriptions criadas..."
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
    COUNT(*) as total,
    ts.telegram_chat_id,
    ts.active
FROM telegram_subscriptions ts
WHERE ts.telegram_chat_id = $CHAT_ID
GROUP BY ts.telegram_chat_id, ts.active;
"

echo ""
echo "Concluido!"
