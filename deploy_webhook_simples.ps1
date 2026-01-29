# ============================================
# DEPLOY TELEGRAM WEBHOOK - VERSAO SIMPLES
# ============================================

$SERVER = "root@212.85.0.249"
$REMOTE_DIR = "/root/telegram-webhook"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "DEPLOY TELEGRAM WEBHOOK NODE.JS" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Criar diretorio
Write-Host "1. Criando diretorio..." -ForegroundColor Yellow
ssh $SERVER "mkdir -p $REMOTE_DIR"

# 2. Copiar arquivos principais
Write-Host ""
Write-Host "2. Copiando arquivos principais..." -ForegroundColor Yellow
scp telegram-webhook-server.js "${SERVER}:${REMOTE_DIR}/"
scp package.json "${SERVER}:${REMOTE_DIR}/"

# 3. Copiar scripts de instalacao
Write-Host ""
Write-Host "3. Copiando scripts de instalacao..." -ForegroundColor Yellow
scp install_deps.sh "${SERVER}:${REMOTE_DIR}/"
scp setup_service.sh "${SERVER}:${REMOTE_DIR}/"
scp setup_nginx.sh "${SERVER}:${REMOTE_DIR}/"

# 4. Tornar scripts executaveis e instalar dependencias
Write-Host ""
Write-Host "4. Instalando Node.js e dependencias..." -ForegroundColor Yellow
ssh $SERVER "cd $REMOTE_DIR && chmod +x *.sh && ./install_deps.sh"

# 5. Configurar servico
Write-Host ""
Write-Host "5. Configurando servico systemd..." -ForegroundColor Yellow
ssh $SERVER "cd $REMOTE_DIR && ./setup_service.sh"

# 6. Configurar Nginx
Write-Host ""
Write-Host "6. Configurando Nginx..." -ForegroundColor Yellow
ssh $SERVER "cd $REMOTE_DIR && ./setup_nginx.sh"

# 7. Configurar webhook
Write-Host ""
Write-Host "7. Configurando webhook do Telegram..." -ForegroundColor Yellow
$webhookUrl = "https://api.telegram.org/bot8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec/setWebhook"
$body = @{
    url = "https://api.taskflowv3.com.br/telegram-webhook"
    secret_token = "TgWebhook2026Taskflow_Secret"
    allowed_updates = @("message", "edited_message", "callback_query")
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $body -ContentType "application/json"

if ($response.ok) {
    Write-Host "   Webhook configurado com sucesso!" -ForegroundColor Green
    Write-Host "   $($response.description)" -ForegroundColor Gray
} else {
    Write-Host "   ERRO: $($response.description)" -ForegroundColor Red
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "DEPLOY CONCLUIDO!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Servico: telegram-webhook" -ForegroundColor White
Write-Host "Porta: 3001 (local)" -ForegroundColor White
Write-Host "URL: https://api.taskflowv3.com.br/telegram-webhook" -ForegroundColor White
Write-Host ""
Write-Host "Comandos uteis:" -ForegroundColor Cyan
Write-Host "  Ver logs:" -ForegroundColor Yellow
Write-Host "    ssh root@212.85.0.249 'journalctl -u telegram-webhook -f'" -ForegroundColor Gray
Write-Host "  Ver status:" -ForegroundColor Yellow
Write-Host "    ssh root@212.85.0.249 'systemctl status telegram-webhook'" -ForegroundColor Gray
Write-Host "  Reiniciar:" -ForegroundColor Yellow
Write-Host "    ssh root@212.85.0.249 'systemctl restart telegram-webhook'" -ForegroundColor Gray
Write-Host ""
Write-Host "TESTE AGORA:" -ForegroundColor Yellow
Write-Host "  Envie uma mensagem no grupo do Telegram!" -ForegroundColor White
Write-Host ""
