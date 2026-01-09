#!/bin/bash

echo "=========================================="
echo "Configurando Supabase para desabilitar confirmação de email"
echo "=========================================="
echo ""

# Ir para o diretório do Supabase
cd /root/supabase/docker || {
    echo "❌ Erro: Não foi possível acessar /root/supabase/docker"
    exit 1
}

echo "✅ Diretório encontrado: $(pwd)"
echo ""

# Verificar se .env existe
if [ ! -f ".env" ]; then
    echo "❌ Arquivo .env não encontrado!"
    exit 1
fi

echo "📄 Verificando configurações atuais..."
echo ""
grep -i "mail\|email\|confirm" .env || echo "Nenhuma configuração de email encontrada"
echo ""

# Fazer backup do .env
echo "💾 Fazendo backup do .env..."
cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
echo "✅ Backup criado: .env.backup.$(date +%Y%m%d_%H%M%S)"
echo ""

# Adicionar ou modificar GOTRUE_MAILER_AUTOCONFIRM
echo "🔧 Configurando GOTRUE_MAILER_AUTOCONFIRM=true..."

# Verificar se já existe
if grep -q "GOTRUE_MAILER_AUTOCONFIRM" .env; then
    # Substituir valor existente
    sed -i 's/^GOTRUE_MAILER_AUTOCONFIRM=.*/GOTRUE_MAILER_AUTOCONFIRM=true/' .env
    echo "✅ Valor atualizado"
else
    # Adicionar novo
    echo "" >> .env
    echo "# Desabilitar confirmação de email" >> .env
    echo "GOTRUE_MAILER_AUTOCONFIRM=true" >> .env
    echo "✅ Valor adicionado"
fi

echo ""

# Verificar se ENABLE_EMAIL_CONFIRMATION existe
if grep -q "ENABLE_EMAIL_CONFIRMATION" .env; then
    sed -i 's/^ENABLE_EMAIL_CONFIRMATION=.*/ENABLE_EMAIL_CONFIRMATION=false/' .env
    echo "✅ ENABLE_EMAIL_CONFIRMATION atualizado"
else
    echo "ENABLE_EMAIL_CONFIRMATION=false" >> .env
    echo "✅ ENABLE_EMAIL_CONFIRMATION adicionado"
fi

echo ""
echo "📋 Configurações atualizadas:"
echo ""
grep -i "mail\|email\|confirm" .env
echo ""

# Reiniciar o container de autenticação
echo "🔄 Reiniciando container supabase-auth..."
docker-compose restart supabase-auth

if [ $? -eq 0 ]; then
    echo "✅ Container reiniciado com sucesso!"
else
    echo "❌ Erro ao reiniciar container. Tente manualmente:"
    echo "   docker-compose restart supabase-auth"
fi

echo ""
echo "=========================================="
echo "✅ Configuração concluída!"
echo "=========================================="
echo ""
echo "📝 Próximos passos:"
echo "1. Aguarde alguns segundos para o container reiniciar"
echo "2. Verifique os logs: docker logs supabase-auth | tail -20"
echo "3. Teste criar um novo usuário no app Flutter"
echo ""
echo "💡 Se algo der errado, restaure o backup:"
echo "   cp .env.backup.* .env"
echo ""

