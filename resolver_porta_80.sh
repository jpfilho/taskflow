#!/bin/bash

# Script para executar NO SERVIDOR
# Resolve o conflito da porta 80

echo "=========================================="
echo "Resolvendo Conflito da Porta 80"
echo "=========================================="
echo ""

# Verificar o que está usando a porta 80
echo "🔍 Verificando o que está usando a porta 80..."
echo ""

# Verificar processos na porta 80
echo "Processos na porta 80:"
lsof -i :80 2>/dev/null || netstat -tulpn | grep :80 || ss -tulpn | grep :80

echo ""
echo "=========================================="
echo ""

# Verificar se é o Supabase ou outro serviço
echo "📋 Verificando serviços Docker..."
docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -E "80|443" || echo "Nenhum container Docker usando porta 80"

echo ""
echo "=========================================="
echo ""

# Opções de solução
echo "💡 OPÇÕES DE SOLUÇÃO:"
echo ""
echo "1. Se for o Supabase usando a porta 80:"
echo "   - Configure o Nginx para usar outra porta (ex: 8080)"
echo "   - Ou configure o Supabase para usar outra porta"
echo ""
echo "2. Se for outro serviço:"
echo "   - Pare o serviço: systemctl stop [nome-do-servico]"
echo "   - Ou configure o Nginx para usar outra porta"
echo ""
echo "3. Usar Nginx em porta alternativa (8080):"
echo "   - Edite /etc/nginx/sites-available/task2026"
echo "   - Mude 'listen 80' para 'listen 8080'"
echo "   - Acesse: http://212.85.0.249:8080/task2026/"
echo ""
