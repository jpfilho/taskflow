#!/bin/bash

# Script para verificar DNS e configurar HTTPS

DOMINIO="taskflowv3.com.br"
IP_SERVIDOR="212.85.0.249"

echo "=========================================="
echo "Verificação DNS e Configuração HTTPS"
echo "=========================================="
echo ""

# Verificar DNS atual
echo "🔍 Verificando DNS atual..."
IP_DOMINIO=$(dig +short $DOMINIO | head -1)

echo "   Domínio: $DOMINIO"
echo "   IP do domínio: $IP_DOMINIO"
echo "   IP do servidor: $IP_SERVIDOR"
echo ""

if [ "$IP_DOMINIO" != "$IP_SERVIDOR" ]; then
    echo "⚠️  O DNS não está apontando para este servidor!"
    echo ""
    echo "💡 OPÇÕES:"
    echo ""
    echo "1. ATUALIZAR DNS (Recomendado para Let's Encrypt)"
    echo "   - Acesse o painel do seu provedor de domínio"
    echo "   - Configure o registro A:"
    echo "     Nome: @ (ou vazio)"
    echo "     Tipo: A"
    echo "     Valor: $IP_SERVIDOR"
    echo "     TTL: 3600 (ou padrão)"
    echo ""
    echo "   - Se usar subdomínio (ex: app.taskflowv3.com.br):"
    echo "     Nome: app"
    echo "     Tipo: A"
    echo "     Valor: $IP_SERVIDOR"
    echo ""
    echo "   - Aguarde a propagação (pode levar alguns minutos a horas)"
    echo "   - Verifique com: dig +short $DOMINIO"
    echo ""
    echo "2. USAR CERTIFICADO AUTO-ASSINADO (Temporário)"
    echo "   - Funciona imediatamente"
    echo "   - Mostrará aviso de segurança no navegador"
    echo "   - Execute: bash configurar_https_sem_dominio.sh"
    echo ""
    echo "3. VERIFICAR SE HÁ CLOUDFLARE OU PROXY"
    echo "   - Se usar Cloudflare, configure o DNS lá"
    echo "   - Cloudflare pode estar fazendo proxy (laranja)"
    echo "   - Desative o proxy (cinza) para Let's Encrypt funcionar"
    echo ""
    
    read -p "Escolha uma opção (1/2/3) ou 's' para continuar mesmo assim: " opcao
    
    case $opcao in
        1)
            echo ""
            echo "📋 Configure o DNS e depois execute novamente:"
            echo "   bash configurar_https_com_supabase.sh"
            echo ""
            echo "   Para verificar quando o DNS propagou:"
            echo "   dig +short $DOMINIO"
            echo ""
            exit 0
            ;;
        2)
            echo ""
            echo "🔐 Configurando com certificado auto-assinado..."
            bash configurar_https_sem_dominio.sh
            exit $?
            ;;
        3)
            echo ""
            echo "📋 Se você usa Cloudflare:"
            echo "   1. Acesse: https://dash.cloudflare.com"
            echo "   2. Selecione o domínio $DOMINIO"
            echo "   3. Vá em DNS > Records"
            echo "   4. Configure o registro A para $IP_SERVIDOR"
            echo "   5. Clique no ícone de nuvem para DESATIVAR o proxy (ficar cinza)"
            echo "   6. Aguarde alguns minutos"
            echo "   7. Execute novamente: bash configurar_https_com_supabase.sh"
            echo ""
            exit 0
            ;;
        s|S)
            echo ""
            echo "⚠️  Continuando mesmo com DNS incorreto..."
            echo "   O Let's Encrypt pode falhar, mas tentaremos..."
            echo ""
            ;;
        *)
            echo "❌ Opção inválida!"
            exit 1
            ;;
    esac
else
    echo "✅ DNS está correto! Continuando..."
    echo ""
fi

# Continuar com configuração HTTPS
echo "🚀 Executando configuração HTTPS..."
bash configurar_https_com_supabase.sh
