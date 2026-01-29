#!/bin/bash
# ============================================
# CORRIGIR NGINX - INSERIR /send-message CORRETAMENTE
# ============================================

echo "Corrigindo configuracao do Nginx..."

# Remover configuracoes duplicadas ou incorretas
sed -i '/location \/send-message/,/^    }/d' /etc/nginx/sites-available/supabase-ssl

# Ler o arquivo e encontrar onde inserir (dentro do bloco server que tem listen 443)
# Inserir antes do location /telegram-webhook OU antes do location /
if grep -q "location /telegram-webhook" /etc/nginx/sites-available/supabase-ssl; then
    # Inserir antes de /telegram-webhook
    sed -i '/location \/telegram-webhook/i\    location /send-message {\n        proxy_pass http://127.0.0.1:3001/send-message;\n        proxy_set_header Host $host;\n        proxy_set_header X-Real-IP $remote_addr;\n        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n        proxy_set_header X-Forwarded-Proto https;\n        proxy_http_version 1.1;\n        proxy_set_header Upgrade $http_upgrade;\n        proxy_set_header Connection "upgrade";\n    }' /etc/nginx/sites-available/supabase-ssl
else
    # Inserir antes do location /
    sed -i '/location \//i\    location /send-message {\n        proxy_pass http://127.0.0.1:3001/send-message;\n        proxy_set_header Host $host;\n        proxy_set_header X-Real-IP $remote_addr;\n        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n        proxy_set_header X-Forwarded-Proto https;\n        proxy_http_version 1.1;\n        proxy_set_header Upgrade $http_upgrade;\n        proxy_set_header Connection "upgrade";\n    }' /etc/nginx/sites-available/supabase-ssl
fi

# Testar e recarregar
if nginx -t; then
    systemctl reload nginx
    echo "Nginx configurado com sucesso!"
else
    echo "ERRO: Configuracao do Nginx invalida!"
    exit 1
fi
