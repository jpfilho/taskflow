#!/bin/bash
# Script para habilitar acesso direto ao N8N via IP (além do HTTPS)

echo "========================================="
echo "Habilitando acesso direto ao N8N"
echo "========================================="
echo ""
echo "⚠️  ATENÇÃO: Isso expõe o N8N diretamente na rede."
echo "   Recomendado apenas para desenvolvimento/testes."
echo ""

read -p "Deseja continuar? (s/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "Cancelado."
    exit 0
fi

echo ""
echo "Parando container atual..."
docker stop n8n 2>/dev/null || true
docker rm n8n 2>/dev/null || true

echo "Recriando container com acesso externo..."
docker run -d \
    --name n8n \
    --restart unless-stopped \
    -p 5678:5678 \
    -v /opt/n8n:/home/node/.n8n \
    -e N8N_BASIC_AUTH_ACTIVE=true \
    -e N8N_BASIC_AUTH_USER=admin \
    -e N8N_BASIC_AUTH_PASSWORD=n8n_admin_2026 \
    -e N8N_HOST=api.taskflowv3.com.br \
    -e N8N_PORT=443 \
    -e N8N_PROTOCOL=https \
    -e WEBHOOK_URL=https://api.taskflowv3.com.br/n8n/ \
    -e N8N_PATH=/n8n \
    n8nio/n8n:latest

sleep 3

if docker ps | grep -q n8n; then
    echo "✅ Container recriado com sucesso!"
    echo ""
    echo "Agora o N8N está acessível em:"
    echo "  - HTTPS: https://api.taskflowv3.com.br/n8n"
    echo "  - HTTP direto: http://212.85.0.249:5678"
    echo ""
    echo "⚠️  Lembre-se: O acesso HTTP direto não é seguro!"
    echo "   Use apenas para desenvolvimento/testes."
else
    echo "❌ Erro ao recriar container"
    docker logs n8n --tail 20
    exit 1
fi
