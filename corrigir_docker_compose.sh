#!/bin/bash

echo "=========================================="
echo "Corrigindo docker-compose.yml"
echo "=========================================="
echo ""

cd /root/supabase/docker || {
    echo "❌ Erro: Não foi possível acessar /root/supabase/docker"
    exit 1
}

echo "✅ Diretório: $(pwd)"
echo ""

# Fazer backup
echo "💾 Fazendo backup..."
cp docker-compose.yml docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S)
echo "✅ Backup criado"
echo ""

# Corrigir valores booleanos para strings
echo "🔧 Corrigindo valores booleanos para strings..."

# Lista de variáveis que precisam ser corrigidas
sed -i 's/: true$/: "true"/g' docker-compose.yml
sed -i 's/: false$/: "false"/g' docker-compose.yml

echo "✅ Valores booleanos corrigidos"
echo ""

# Verificar se há problema com campo 'name'
echo "🔍 Verificando campo 'name'..."
if grep -q "^name:" docker-compose.yml; then
    echo "⚠️ Campo 'name' encontrado. Verificando..."
    # Se o campo name estiver no topo e não começar com 'x-', comentar ou remover
    sed -i '/^name:/s/^/# /' docker-compose.yml
    echo "✅ Campo 'name' comentado"
else
    echo "✅ Nenhum problema com campo 'name'"
fi

echo ""
echo "📋 Verificando alterações..."
echo ""
grep -E "GOTRUE_MAILER_AUTOCONFIRM|NEXT_PUBLIC_ENABLE_LOGS|LOGFLARE_SINGLE_TENANT|SEED_SELF_HOST|CLUSTER_POSTGRES" docker-compose.yml | head -10
echo ""

# Validar sintaxe do docker-compose.yml
echo "🔍 Validando sintaxe..."
if docker-compose config > /dev/null 2>&1; then
    echo "✅ docker-compose.yml está válido!"
else
    echo "⚠️ Ainda há erros. Verifique manualmente:"
    docker-compose config 2>&1 | head -20
    exit 1
fi

echo ""
echo "=========================================="
echo "✅ Correções aplicadas!"
echo "=========================================="
echo ""
echo "🔄 Agora recrie o container:"
echo "   docker-compose up -d supabase-auth"
echo ""






