# ============================================
# CORRIGIR TUDO - FLUTTER PARA TELEGRAM
# ============================================

$SERVER = "root@212.85.0.249"
$REMOTE_DIR = "/root/telegram-webhook"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "CORRIGIR INTEGRACAO FLUTTER -> TELEGRAM" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Copiando servidor atualizado..." -ForegroundColor Yellow
scp telegram-webhook-server.js "${SERVER}:${REMOTE_DIR}/"

Write-Host ""
Write-Host "2. Reiniciando servico..." -ForegroundColor Yellow
ssh $SERVER "systemctl restart telegram-webhook"
Start-Sleep -Seconds 3

Write-Host ""
Write-Host "3. Configurando Nginx para /send-message..." -ForegroundColor Yellow
ssh $SERVER @'
# Verificar se ja existe
if grep -q "location /send-message" /etc/nginx/sites-available/supabase-ssl; then
    echo "Endpoint /send-message ja existe"
else
    # Adicionar antes do ultimo }
    sed -i '/^}$/i\    location /send-message {\n        proxy_pass http://127.0.0.1:3001/send-message;\n        proxy_set_header Host $host;\n        proxy_set_header X-Real-IP $remote_addr;\n        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n        proxy_set_header X-Forwarded-Proto https;\n        proxy_http_version 1.1;\n        proxy_set_header Upgrade $http_upgrade;\n        proxy_set_header Connection "upgrade";\n    }' /etc/nginx/sites-available/supabase-ssl
    
    echo "Endpoint /send-message adicionado"
fi

nginx -t && systemctl reload nginx
'@

Write-Host ""
Write-Host "4. Verificando se endpoint funciona..." -ForegroundColor Yellow
$testResult = ssh $SERVER "curl -s -X POST http://127.0.0.1:3001/send-message -H 'Content-Type: application/json' -d '{\"mensagem_id\":\"test\",\"thread_type\":\"TASK\",\"thread_id\":\"test\"}' 2>&1"
Write-Host $testResult

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "SERVIDOR ATUALIZADO!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "PROXIMO PASSO NO FLUTTER:" -ForegroundColor Yellow
Write-Host "  1. Execute: flutter pub get" -ForegroundColor White
Write-Host "  2. Reinicie o app Flutter" -ForegroundColor White
Write-Host "  3. Envie uma mensagem no chat" -ForegroundColor White
Write-Host "  4. Verifique se aparece no Telegram!" -ForegroundColor White
Write-Host ""
Write-Host "Para ver logs em tempo real:" -ForegroundColor Cyan
Write-Host "  ssh root@212.85.0.249 'journalctl -u telegram-webhook -f'" -ForegroundColor Gray
Write-Host ""
