# ============================================
# ATUALIZAR SERVIDOR E NGINX
# ============================================

$SERVER = "root@212.85.0.249"
$REMOTE_DIR = "/root/telegram-webhook"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "ATUALIZAR SERVIDOR TELEGRAM" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Copiando servidor atualizado..." -ForegroundColor Yellow
scp telegram-webhook-server.js "${SERVER}:${REMOTE_DIR}/"

Write-Host ""
Write-Host "2. Reiniciando servico..." -ForegroundColor Yellow
ssh $SERVER "systemctl restart telegram-webhook"

Write-Host ""
Write-Host "Aguardando 3 segundos..." -ForegroundColor Gray
Start-Sleep -Seconds 3

Write-Host ""
Write-Host "3. Verificando status..." -ForegroundColor Yellow
ssh $SERVER "systemctl status telegram-webhook --no-pager | head -15"

Write-Host ""
Write-Host "4. Configurando Nginx para /send-message..." -ForegroundColor Yellow
ssh $SERVER @'
cat > /tmp/nginx_send_message.conf << 'EOF'
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

# Adicionar ao arquivo de configuracao do Supabase
if grep -q "location /send-message" /etc/nginx/sites-available/supabase-ssl; then
    echo "Configuracao /send-message ja existe"
else
    # Inserir antes do ultimo }
    sed -i '/^}$/i\    location /send-message {\n        proxy_pass http://127.0.0.1:3001/send-message;\n        proxy_set_header Host \$host;\n        proxy_set_header X-Real-IP \$remote_addr;\n        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;\n        proxy_set_header X-Forwarded-Proto https;\n        proxy_http_version 1.1;\n        proxy_set_header Upgrade \$http_upgrade;\n        proxy_set_header Connection "upgrade";\n    }' /etc/nginx/sites-available/supabase-ssl
fi

nginx -t && systemctl reload nginx
'@

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "ATUALIZACAO CONCLUIDA!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "PROXIMO PASSO:" -ForegroundColor Yellow
Write-Host "  1. Adicione o pacote 'http' no pubspec.yaml" -ForegroundColor White
Write-Host "  2. Execute: flutter pub get" -ForegroundColor White
Write-Host "  3. Teste enviando uma mensagem no app!" -ForegroundColor White
Write-Host ""
