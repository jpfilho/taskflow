#!/bin/bash
# ============================================
# CONFIGURAR NGINX PARA /send-message
# ============================================

echo "Configurando Nginx para /send-message..."

# Verificar se ja existe
if grep -q "location /send-message" /etc/nginx/sites-available/supabase-ssl; then
    echo "Endpoint /send-message ja existe"
else
    # Criar arquivo temporario com a configuracao
    cat > /tmp/send_message_location.conf << 'EOF'
    location /send-message {
        proxy_pass http://127.0.0.1:3001/send-message;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
EOF

    # Inserir antes do ultimo }
    sed -i '/^}$/r /tmp/send_message_location.conf' /etc/nginx/sites-available/supabase-ssl
    
    echo "Endpoint /send-message adicionado"
fi

# Testar e recarregar
nginx -t && systemctl reload nginx

echo "Nginx configurado!"
