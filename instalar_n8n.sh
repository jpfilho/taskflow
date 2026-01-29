#!/bin/bash

# Script para instalar N8N no servidor
# Servidor: 212.85.0.249

SERVER_IP="212.85.0.249"
N8N_PORT="5678"
N8N_DATA_DIR="/opt/n8n"

echo "========================================="
echo "Instalação do N8N no Servidor"
echo "========================================="
echo ""

# Verificar se o Docker está instalado
echo "[1/5] Verificando se o Docker está instalado..."
if ! command -v docker &> /dev/null; then
    echo "Docker não encontrado. Instalando Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    systemctl start docker
    systemctl enable docker
    usermod -aG docker $USER
    echo "Docker instalado com sucesso!"
else
    echo "Docker já está instalado: $(docker --version)"
fi

# Criar diretório para dados do N8N
echo ""
echo "[2/5] Criando diretório para dados do N8N..."
mkdir -p $N8N_DATA_DIR
chmod 755 $N8N_DATA_DIR
echo "Diretório criado: $N8N_DATA_DIR"

# Parar e remover container existente (se houver)
echo ""
echo "[3/5] Verificando containers existentes..."
docker stop n8n 2>/dev/null || true
docker rm n8n 2>/dev/null || true

# Instalar N8N via Docker
echo ""
echo "[4/5] Instalando N8N via Docker..."
docker run -d \
    --name n8n \
    --restart unless-stopped \
    -p ${N8N_PORT}:5678 \
    -v $N8N_DATA_DIR:/home/node/.n8n \
    -e N8N_BASIC_AUTH_ACTIVE=true \
    -e N8N_BASIC_AUTH_USER=admin \
    -e N8N_BASIC_AUTH_PASSWORD=n8n_admin_2026 \
    -e N8N_HOST=212.85.0.249 \
    -e N8N_PORT=5678 \
    -e N8N_PROTOCOL=http \
    -e WEBHOOK_URL=http://212.85.0.249:5678/ \
    n8nio/n8n:latest

if [ $? -eq 0 ]; then
    echo "N8N instalado com sucesso!"
else
    echo "Erro ao instalar N8N. Verifique os logs."
    exit 1
fi

# Verificar status do container
echo ""
echo "[5/5] Verificando status do N8N..."
sleep 5
if docker ps | grep -q n8n; then
    echo "N8N está rodando!"
    echo ""
    echo "========================================="
    echo "Instalação Concluída!"
    echo "========================================="
    echo ""
    echo "Acesso ao N8N:"
    echo "  URL: http://${SERVER_IP}:${N8N_PORT}"
    echo ""
    echo "Credenciais de acesso:"
    echo "  Usuário: admin"
    echo "  Senha: n8n_admin_2026"
    echo ""
    echo "Dados salvos em: $N8N_DATA_DIR"
    echo ""
    echo "Comandos úteis:"
    echo "  Ver logs: docker logs n8n"
    echo "  Parar: docker stop n8n"
    echo "  Iniciar: docker start n8n"
    echo "  Reiniciar: docker restart n8n"
    echo "  Remover: docker stop n8n && docker rm n8n"
else
    echo "N8N não está rodando. Verifique os logs:"
    echo "  docker logs n8n"
    exit 1
fi
