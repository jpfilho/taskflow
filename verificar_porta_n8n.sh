#!/bin/bash
# Verificar configuração da porta do N8N

echo "========================================="
echo "Verificando porta do N8N"
echo "========================================="
echo ""

echo "1. Verificando container N8N:"
docker ps | grep n8n
echo ""

echo "2. Verificando mapeamento de porta:"
docker inspect n8n 2>/dev/null | grep -A 10 "PortBindings" || echo "   Container não encontrado"
echo ""

echo "3. Testando acesso local (127.0.0.1):"
curl -s http://127.0.0.1:5678/ | head -5
echo ""
echo ""

echo "4. Testando acesso externo (212.85.0.249):"
curl -s http://212.85.0.249:5678/ 2>&1 | head -5
echo ""
echo ""

echo "5. Verificando se porta está escutando:"
netstat -tuln | grep 5678 || ss -tuln | grep 5678
echo ""
