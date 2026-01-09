#!/bin/bash

echo "=========================================="
echo "Adicionando variáveis de email ao docker-compose.yml"
echo "=========================================="
echo ""

cd /root/supabase/docker || {
    echo "❌ Erro: Não foi possível acessar /root/supabase/docker"
    exit 1
}

echo "✅ Diretório: $(pwd)"
echo ""

# Fazer backup
echo "💾 Fazendo backup do docker-compose.yml..."
cp docker-compose.yml docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S)
echo "✅ Backup criado"
echo ""

# Verificar se já existe GOTRUE_MAILER_AUTOCONFIRM
if grep -q "GOTRUE_MAILER_AUTOCONFIRM" docker-compose.yml; then
    echo "⚠️ GOTRUE_MAILER_AUTOCONFIRM já existe, atualizando..."
    sed -i 's/.*GOTRUE_MAILER_AUTOCONFIRM.*/      - GOTRUE_MAILER_AUTOCONFIRM=true/' docker-compose.yml
    echo "✅ Atualizado"
else
    echo "🔧 Adicionando GOTRUE_MAILER_AUTOCONFIRM..."
    # Encontrar a linha com GOTRUE_SITE_URL e adicionar depois
    if grep -q "GOTRUE_SITE_URL" docker-compose.yml; then
        sed -i '/GOTRUE_SITE_URL/a\      - GOTRUE_MAILER_AUTOCONFIRM=true' docker-compose.yml
        echo "✅ Adicionado após GOTRUE_SITE_URL"
    else
        # Se não encontrar, adicionar no final da seção environment
        # Procurar pela última linha de environment antes do fechamento
        sed -i '/environment:/a\      - GOTRUE_MAILER_AUTOCONFIRM=true' docker-compose.yml
        echo "✅ Adicionado na seção environment"
    fi
fi

echo ""

# Verificar se já existe ENABLE_EMAIL_AUTOCONFIRM
if grep -q "ENABLE_EMAIL_AUTOCONFIRM" docker-compose.yml; then
    echo "⚠️ ENABLE_EMAIL_AUTOCONFIRM já existe, atualizando..."
    sed -i 's/.*ENABLE_EMAIL_AUTOCONFIRM.*/      - ENABLE_EMAIL_AUTOCONFIRM=true/' docker-compose.yml
    echo "✅ Atualizado"
else
    echo "🔧 Adicionando ENABLE_EMAIL_AUTOCONFIRM..."
    # Adicionar após GOTRUE_MAILER_AUTOCONFIRM
    if grep -q "GOTRUE_MAILER_AUTOCONFIRM" docker-compose.yml; then
        sed -i '/GOTRUE_MAILER_AUTOCONFIRM/a\      - ENABLE_EMAIL_AUTOCONFIRM=true' docker-compose.yml
        echo "✅ Adicionado após GOTRUE_MAILER_AUTOCONFIRM"
    else
        sed -i '/GOTRUE_SITE_URL/a\      - ENABLE_EMAIL_AUTOCONFIRM=true' docker-compose.yml
        echo "✅ Adicionado"
    fi
fi

echo ""
echo "📋 Verificando alterações na seção supabase-auth:"
echo ""
grep -A 20 "supabase-auth:" docker-compose.yml | grep -A 15 "environment:" | head -20
echo ""

# Reiniciar o container
echo "🔄 Reiniciando container supabase-auth..."
docker restart supabase-auth

if [ $? -eq 0 ]; then
    echo "✅ Container reiniciado com sucesso!"
    echo ""
    echo "⏳ Aguardando 5 segundos..."
    sleep 5
    echo ""
    echo "📋 Verificando logs:"
    docker logs supabase-auth --tail 10
else
    echo "❌ Erro ao reiniciar container"
    exit 1
fi

echo ""
echo "=========================================="
echo "✅ Configuração concluída!"
echo "=========================================="
echo ""
echo "🧪 Teste agora criando um novo usuário no app"
echo ""






