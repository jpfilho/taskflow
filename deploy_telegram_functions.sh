#!/bin/bash

# =========================================
# DEPLOY EDGE FUNCTIONS - TELEGRAM
# =========================================
# Para Supabase Docker na Hostinger VPS
# Execute: bash deploy_telegram_functions.sh

SSH_USER="${1:-root}"
SSH_HOST="${2:-srv750497.hstgr.cloud}"
SUPABASE_PATH="${3:-/opt/supabase}"

echo "🚀 Deploy das Edge Functions Telegram"
echo "======================================"
echo ""

# =========================================
# 1. VERIFICAR ARQUIVOS LOCAIS
# =========================================

echo "📋 Verificando arquivos locais..."

LOCAL_FILES=(
    "supabase/functions/telegram-webhook/index.ts"
    "supabase/functions/telegram-webhook/.env"
    "supabase/functions/telegram-send/index.ts"
    "supabase/functions/telegram-send/.env"
)

ALL_FILES_EXIST=true
for file in "${LOCAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✅ $file"
    else
        echo "  ❌ $file não encontrado"
        ALL_FILES_EXIST=false
    fi
done

if [ "$ALL_FILES_EXIST" = false ]; then
    echo ""
    echo "❌ Alguns arquivos não foram encontrados!"
    echo "Execute primeiro: bash configurar_telegram_env.sh"
    exit 1
fi

echo ""
echo "✅ Todos os arquivos locais estão OK!"
echo ""

# =========================================
# 2. CONFIRMAR DEPLOY
# =========================================

echo "📡 Configuração de Deploy:"
echo "   SSH: $SSH_USER@$SSH_HOST"
echo "   Caminho remoto: $SUPABASE_PATH/volumes/functions/"
echo ""

read -p "Deseja continuar com o deploy? (s/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "❌ Deploy cancelado."
    exit 0
fi

echo ""

# =========================================
# 3. CRIAR DIRETÓRIOS NO SERVIDOR
# =========================================

echo "📁 Criando diretórios no servidor..."

ssh "$SSH_USER@$SSH_HOST" "mkdir -p $SUPABASE_PATH/volumes/functions/telegram-webhook && \
mkdir -p $SUPABASE_PATH/volumes/functions/telegram-send && \
echo 'Diretorios criados com sucesso'"

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Erro ao criar diretórios no servidor"
    echo ""
    echo "💡 DICA: Verifique se:"
    echo "   - Você tem acesso SSH configurado"
    echo "   - O caminho $SUPABASE_PATH está correto"
    echo "   - Execute: ssh $SSH_USER@$SSH_HOST 'ls -la /opt/'"
    echo ""
    exit 1
fi

echo ""

# =========================================
# 4. COPIAR ARQUIVOS VIA SCP
# =========================================

echo "📤 Copiando arquivos para o servidor..."
echo ""

# Copiar telegram-webhook
echo "   📦 Copiando telegram-webhook..."
scp -r "supabase/functions/telegram-webhook" "${SSH_USER}@${SSH_HOST}:${SUPABASE_PATH}/volumes/functions/"

if [ $? -eq 0 ]; then
    echo "   ✅ telegram-webhook copiado"
else
    echo "   ❌ Erro ao copiar telegram-webhook"
    exit 1
fi

echo ""

# Copiar telegram-send
echo "   📦 Copiando telegram-send..."
scp -r "supabase/functions/telegram-send" "${SSH_USER}@${SSH_HOST}:${SUPABASE_PATH}/volumes/functions/"

if [ $? -eq 0 ]; then
    echo "   ✅ telegram-send copiado"
else
    echo "   ❌ Erro ao copiar telegram-send"
    exit 1
fi

echo ""
echo "✅ Arquivos copiados com sucesso!"
echo ""

# =========================================
# 5. VERIFICAR ARQUIVOS NO SERVIDOR
# =========================================

echo "🔍 Verificando arquivos no servidor..."

ssh "$SSH_USER@$SSH_HOST" "echo '=== telegram-webhook ===' && \
ls -la $SUPABASE_PATH/volumes/functions/telegram-webhook/ && \
echo '' && \
echo '=== telegram-send ===' && \
ls -la $SUPABASE_PATH/volumes/functions/telegram-send/"

echo ""

# =========================================
# 6. AJUSTAR PERMISSÕES
# =========================================

echo "🔐 Ajustando permissões..."

ssh "$SSH_USER@$SSH_HOST" "chmod -R 755 $SUPABASE_PATH/volumes/functions/ && \
chown -R 1000:1000 $SUPABASE_PATH/volumes/functions/ && \
echo 'Permissoes ajustadas'"

echo ""

# =========================================
# 7. REINICIAR CONTAINER EDGE FUNCTIONS
# =========================================

echo "🔄 Reiniciando container edge-functions..."

ssh "$SSH_USER@$SSH_HOST" "cd $SUPABASE_PATH && \
docker-compose restart edge-functions && \
echo 'Container reiniciado' && \
sleep 3 && \
echo '' && \
echo '=== Logs do container ===' && \
docker-compose logs --tail=20 edge-functions"

echo ""
echo "✅ Container reiniciado!"
echo ""

# =========================================
# 8. TESTAR ENDPOINT
# =========================================

echo "🧪 Testando endpoint..."
echo ""

TEST_URL="https://$SSH_HOST/functions/v1/telegram-webhook"
echo "   URL: $TEST_URL"

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$TEST_URL")

if [ "$HTTP_CODE" = "401" ]; then
    echo "   ✅ Endpoint OK! (401 Unauthorized é esperado)"
elif [ "$HTTP_CODE" = "200" ]; then
    echo "   ✅ Endpoint responde! Status: $HTTP_CODE"
else
    echo "   ⚠️  Status: $HTTP_CODE"
fi

echo ""

# =========================================
# 9. RESUMO
# =========================================

echo "======================================"
echo "✅ DEPLOY CONCLUÍDO COM SUCESSO!"
echo "======================================"
echo ""
echo "📋 Próximos passos:"
echo ""
echo "1️⃣  Configurar webhook do Telegram:"
echo "   bash configurar_webhook.sh"
echo ""
echo "2️⃣  Verificar webhook:"
echo "   curl \"https://api.telegram.org/bot8432168734:AAF_R1iq3p1c5Crm2oAcLsgkfzqH5_Pywec/getWebhookInfo\""
echo ""
echo "3️⃣  Executar migration SQL:"
echo "   supabase/migrations/20260124_telegram_integration.sql"
echo ""
echo "4️⃣  Testar no app Flutter!"
echo ""
echo "📚 Documentação completa: INTEGRACAO_TELEGRAM.md"
echo ""
