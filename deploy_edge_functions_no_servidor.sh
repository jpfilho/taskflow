#!/bin/bash
# =========================================
# DEPLOY TELEGRAM EDGE FUNCTIONS
# Execute este script DENTRO DO SERVIDOR
# =========================================

set -e

echo ""
echo "======================================="
echo " DEPLOY TELEGRAM EDGE FUNCTIONS"
echo "======================================="
echo ""

# Variáveis
SUPABASE_PATH="/root/supabase"
FUNCTIONS_PATH="$SUPABASE_PATH/volumes/functions"

# =========================================
# 1. CRIAR DIRETÓRIOS
# =========================================

echo "📁 Criando diretórios..."
mkdir -p "$FUNCTIONS_PATH/telegram-webhook"
mkdir -p "$FUNCTIONS_PATH/telegram-send"
echo "✅ Diretórios criados!"
echo ""

# =========================================
# 2. VERIFICAR ESTRUTURA
# =========================================

echo "📂 Estrutura de diretórios:"
ls -la "$FUNCTIONS_PATH/" | grep telegram || echo "   (ainda vazio)"
echo ""

# =========================================
# 3. AGUARDANDO ARQUIVOS VIA SCP
# =========================================

echo "⏳ Agora você precisa copiar os arquivos do seu PC Windows!"
echo ""
echo "Execute estes comandos no PowerShell (no seu PC):"
echo ""
echo "  scp -r supabase\functions\telegram-webhook\* root@212.85.0.249:$FUNCTIONS_PATH/telegram-webhook/"
echo "  scp -r supabase\functions\telegram-send\* root@212.85.0.249:$FUNCTIONS_PATH/telegram-send/"
echo ""
echo "Pressione ENTER quando terminar de copiar os arquivos..."
read -r

# =========================================
# 4. VERIFICAR ARQUIVOS COPIADOS
# =========================================

echo ""
echo "🔍 Verificando arquivos copiados..."
echo ""

if [ -f "$FUNCTIONS_PATH/telegram-webhook/index.ts" ]; then
    echo "✅ telegram-webhook/index.ts"
else
    echo "❌ telegram-webhook/index.ts NÃO ENCONTRADO!"
fi

if [ -f "$FUNCTIONS_PATH/telegram-webhook/.env" ]; then
    echo "✅ telegram-webhook/.env"
else
    echo "❌ telegram-webhook/.env NÃO ENCONTRADO!"
fi

if [ -f "$FUNCTIONS_PATH/telegram-send/index.ts" ]; then
    echo "✅ telegram-send/index.ts"
else
    echo "❌ telegram-send/index.ts NÃO ENCONTRADO!"
fi

if [ -f "$FUNCTIONS_PATH/telegram-send/.env" ]; then
    echo "✅ telegram-send/.env"
else
    echo "❌ telegram-send/.env NÃO ENCONTRADO!"
fi

echo ""

# =========================================
# 5. REINICIAR CONTAINER
# =========================================

echo "🔄 Reiniciando container edge-functions..."
cd "$SUPABASE_PATH"
docker-compose restart edge-functions

echo ""
echo "✅ Container reiniciado!"
echo ""

# =========================================
# 6. AGUARDAR INICIALIZAÇÃO
# =========================================

echo "⏳ Aguardando 5 segundos para inicialização..."
sleep 5

# =========================================
# 7. VERIFICAR LOGS
# =========================================

echo ""
echo "📋 Últimos logs do container:"
echo "======================================="
docker-compose logs --tail=30 edge-functions
echo "======================================="
echo ""

# =========================================
# 8. TESTAR ENDPOINTS
# =========================================

echo "🧪 Testando endpoints..."
echo ""

echo "📡 Testando telegram-webhook:"
curl -k -s "https://212.85.0.249/functions/v1/telegram-webhook" | head -c 200
echo ""
echo ""

echo "📡 Testando telegram-send:"
curl -k -s "https://212.85.0.249/functions/v1/telegram-send" | head -c 200
echo ""
echo ""

# =========================================
# CONCLUÍDO
# =========================================

echo "✅ DEPLOY CONCLUÍDO!"
echo ""
echo "📝 PRÓXIMOS PASSOS:"
echo ""
echo "1. Configurar webhook do Telegram"
echo "2. Executar migration SQL no Supabase Studio"
echo "3. Testar integração no app Flutter"
echo ""
