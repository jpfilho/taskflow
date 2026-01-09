#!/bin/bash

echo "=========================================="
echo "Corrigindo configuração de email do Supabase"
echo "=========================================="
echo ""

# Ir para o diretório do Supabase
cd /root/supabase/docker || {
    echo "❌ Erro: Não foi possível acessar /root/supabase/docker"
    exit 1
}

echo "✅ Diretório: $(pwd)"
echo ""

# Fazer backup
echo "💾 Fazendo backup do .env..."
cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
echo "✅ Backup criado"
echo ""

# CORRIGIR: ENABLE_EMAIL_AUTOCONFIRM deve ser true
echo "🔧 Corrigindo ENABLE_EMAIL_AUTOCONFIRM para true..."

if grep -q "^ENABLE_EMAIL_AUTOCONFIRM=" .env; then
    # Substituir false por true
    sed -i 's/^ENABLE_EMAIL_AUTOCONFIRM=.*/ENABLE_EMAIL_AUTOCONFIRM=true/' .env
    echo "✅ ENABLE_EMAIL_AUTOCONFIRM alterado para true"
else
    # Adicionar se não existir
    echo "ENABLE_EMAIL_AUTOCONFIRM=true" >> .env
    echo "✅ ENABLE_EMAIL_AUTOCONFIRM adicionado como true"
fi

echo ""

# Garantir que GOTRUE_MAILER_AUTOCONFIRM está true
echo "🔧 Verificando GOTRUE_MAILER_AUTOCONFIRM..."

if grep -q "^GOTRUE_MAILER_AUTOCONFIRM=" .env; then
    sed -i 's/^GOTRUE_MAILER_AUTOCONFIRM=.*/GOTRUE_MAILER_AUTOCONFIRM=true/' .env
    echo "✅ GOTRUE_MAILER_AUTOCONFIRM confirmado como true"
else
    echo "GOTRUE_MAILER_AUTOCONFIRM=true" >> .env
    echo "✅ GOTRUE_MAILER_AUTOCONFIRM adicionado como true"
fi

echo ""

# Garantir que ENABLE_EMAIL_CONFIRMATION está false
echo "🔧 Verificando ENABLE_EMAIL_CONFIRMATION..."

if grep -q "^ENABLE_EMAIL_CONFIRMATION=" .env; then
    sed -i 's/^ENABLE_EMAIL_CONFIRMATION=.*/ENABLE_EMAIL_CONFIRMATION=false/' .env
    echo "✅ ENABLE_EMAIL_CONFIRMATION confirmado como false"
else
    echo "ENABLE_EMAIL_CONFIRMATION=false" >> .env
    echo "✅ ENABLE_EMAIL_CONFIRMATION adicionado como false"
fi

echo ""
echo "📋 Configurações finais:"
echo ""
grep -E "^ENABLE_EMAIL_AUTOCONFIRM=|^GOTRUE_MAILER_AUTOCONFIRM=|^ENABLE_EMAIL_CONFIRMATION=" .env
echo ""

# Reiniciar o container de autenticação
echo "🔄 Reiniciando container supabase-auth..."
docker-compose restart supabase-auth

if [ $? -eq 0 ]; then
    echo "✅ Container reiniciado com sucesso!"
    echo ""
    echo "⏳ Aguardando 5 segundos para o container inicializar..."
    sleep 5
    echo ""
    echo "📋 Últimas linhas dos logs:"
    docker logs supabase-auth --tail 10
else
    echo "❌ Erro ao reiniciar container"
    exit 1
fi

echo ""
echo "=========================================="
echo "✅ Configuração corrigida!"
echo "=========================================="
echo ""
echo "📝 O que foi alterado:"
echo "   - ENABLE_EMAIL_AUTOCONFIRM: false → true"
echo "   - GOTRUE_MAILER_AUTOCONFIRM: confirmado como true"
echo "   - ENABLE_EMAIL_CONFIRMATION: confirmado como false"
echo ""
echo "🧪 Teste agora:"
echo "   1. Tente criar um novo usuário no app Flutter"
echo "   2. O usuário deve ser criado e logado automaticamente"
echo "   3. Não deve aparecer erro de confirmação de email"
echo ""






