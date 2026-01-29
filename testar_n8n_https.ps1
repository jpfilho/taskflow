# Script para testar acesso ao N8N via HTTPS

$url = "https://api.taskflowv3.com.br/n8n/"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Testando acesso ao N8N via HTTPS" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "URL: $url" -ForegroundColor Yellow
Write-Host ""

try {
    # Ignorar erros de certificado SSL (equivalente ao -k do curl)
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    
    Write-Host "Enviando requisição..." -ForegroundColor Gray
    $response = Invoke-WebRequest -Uri $url -Method Get -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    
    Write-Host "✅ Resposta recebida!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Status Code: $($response.StatusCode)" -ForegroundColor White
    Write-Host ""
    Write-Host "Conteúdo (primeiros 200 caracteres):" -ForegroundColor Yellow
    Write-Host $response.Content.Substring(0, [Math]::Min(200, $response.Content.Length)) -ForegroundColor Gray
    
    # Verificar se é resposta do N8N ou Kong
    if ($response.Content -match '"message".*"Unauthorized"') {
        Write-Host ""
        Write-Host "✅ Resposta do N8N detectada!" -ForegroundColor Green
        Write-Host "   O Nginx está roteando corretamente para o N8N." -ForegroundColor Gray
    } elseif ($response.Content -match "Kong Error" -or $response.Content -match "kong") {
        Write-Host ""
        Write-Host "❌ Resposta do Kong detectada!" -ForegroundColor Red
        Write-Host "   O Nginx ainda está enviando para o Supabase/Kong." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   Verifique:" -ForegroundColor Yellow
        Write-Host "   1. Se proxy_pass tem barra no final: http://127.0.0.1:5678/;" -ForegroundColor White
        Write-Host "   2. Se location /n8n está ANTES de location /" -ForegroundColor White
    } else {
        Write-Host ""
        Write-Host "⚠️  Resposta não reconhecida" -ForegroundColor Yellow
        Write-Host "   Conteúdo completo:" -ForegroundColor Gray
        Write-Host $response.Content -ForegroundColor Gray
    }
    
} catch {
    Write-Host "❌ Erro ao acessar:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "Teste diretamente no servidor:" -ForegroundColor Yellow
    Write-Host "  ssh root@212.85.0.249 'curl -k https://api.taskflowv3.com.br/n8n/'" -ForegroundColor White
}

# Restaurar validação de certificado
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null

Write-Host ""
