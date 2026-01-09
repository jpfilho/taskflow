#!/bin/bash

echo "=========================================="
echo "Localizando instalação do Supabase"
echo "=========================================="
echo ""

# 1. Verificar se está usando Docker
echo "1. Verificando containers Docker do Supabase..."
docker ps -a | grep -i supabase || echo "Nenhum container Supabase encontrado"
echo ""

# 2. Verificar se há docker-compose
echo "2. Procurando docker-compose.yml do Supabase..."
find /opt /home /root -name "docker-compose.yml" -o -name "docker-compose.yaml" 2>/dev/null | head -10
echo ""

# 3. Procurar diretórios comuns do Supabase
echo "3. Procurando diretórios do Supabase..."
for dir in /opt/supabase /home/*/supabase /root/supabase /var/lib/supabase /usr/local/supabase; do
    if [ -d "$dir" ]; then
        echo "Encontrado: $dir"
        ls -la "$dir" | head -5
    fi
done
echo ""

# 4. Procurar arquivos .env relacionados ao Supabase
echo "4. Procurando arquivos .env do Supabase..."
find /opt /home /root -name ".env" -o -name "*.env" 2>/dev/null | grep -i supabase | head -10
echo ""

# 5. Verificar processos do Supabase
echo "5. Verificando processos do Supabase..."
ps aux | grep -i supabase | grep -v grep || echo "Nenhum processo Supabase encontrado"
echo ""

# 6. Verificar se há instalação via npm/supabase CLI
echo "6. Verificando instalação via Supabase CLI..."
which supabase || echo "Supabase CLI não encontrado no PATH"
echo ""

# 7. Procurar por arquivos de configuração do Supabase
echo "7. Procurando arquivos config.toml..."
find /opt /home /root -name "config.toml" 2>/dev/null | head -10
echo ""

# 8. Verificar se há volumes Docker
echo "8. Verificando volumes Docker..."
docker volume ls | grep -i supabase || echo "Nenhum volume Supabase encontrado"
echo ""

# 9. Verificar portas em uso (Supabase geralmente usa 54321, 54322, etc.)
echo "9. Verificando portas do Supabase em uso..."
netstat -tulpn 2>/dev/null | grep -E "54321|54322|54323|54324|54325" || ss -tulpn 2>/dev/null | grep -E "54321|54322|54323|54324|54325" || echo "Portas padrão do Supabase não encontradas"
echo ""

# 10. Verificar se há instalação via snap
echo "10. Verificando instalação via snap..."
snap list | grep -i supabase || echo "Nenhum snap do Supabase encontrado"
echo ""

echo "=========================================="
echo "Busca concluída!"
echo "=========================================="
echo ""
echo "Próximos passos:"
echo "1. Se encontrar docker-compose.yml, edite-o ou o arquivo .env na mesma pasta"
echo "2. Se encontrar diretório /opt/supabase ou similar, procure por .env ou config.toml"
echo "3. Se estiver usando Docker, use: docker exec -it <container> env | grep -i auth"
echo ""






