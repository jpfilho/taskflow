# Script PowerShell para corrigir Kong Error no N8N via SSH (versão corrigida)

$SERVER_IP   = "212.85.0.249"
$SERVER_USER = "root"
$NGINX_FILE  = "/etc/nginx/sites-available/supabase"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Correção: Kong Error no N8N" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Helper: executa bash via SSH (stdin) convertendo CRLF -> LF
function Invoke-RemoteBash {
    param([Parameter(Mandatory=$true)][string]$Script)
    ($Script -replace "`r`n","`n") | ssh "$SERVER_USER@$SERVER_IP" 'bash -s'
}

# 1) Diagnosticar
Write-Host "[1/4] Diagnosticando problema..." -ForegroundColor Yellow
$diagScript = @"
NGINX_FILE="${NGINX_FILE}"

echo "Verificando ordem dos locations (443):"
grep -n "listen 443" "${NGINX_FILE}" `| head -5 || true
echo ""
echo "Primeiros locations após o bloco 443:"
grep -A 200 "listen 443" "${NGINX_FILE}" `| grep -n "location" `| head -10 || true
echo ""

echo "Testando requisição /n8n:"
RESPONSE=`$(curl -k -sS https://api.taskflowv3.com.br/n8n/ 2>&1 `| head -5)
echo "Resposta (primeiras linhas):"
echo `$RESPONSE
echo ""

if echo `$RESPONSE `| grep -qi "Kong Error|kong|Invalid authentication"; then
  echo "❌ PROBLEMA: Resposta veio do Kong/Supabase!"
elif echo `$RESPONSE `| grep -qi "Unauthorized|n8n"; then
  echo "✅ Resposta parece vir do N8N (correto)"
else
  echo "⚠️  Não foi possível concluir só pelo conteúdo, mas o teste rodou."
fi
"@
Invoke-RemoteBash $diagScript

Write-Host ""

# 2) Backup
Write-Host "[2/4] Fazendo backup..." -ForegroundColor Yellow
$backupScript = @"
NGINX_FILE="${NGINX_FILE}"
cp "${NGINX_FILE}" "`${NGINX_FILE}.backup.`$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup criado em: `${NGINX_FILE}.backup.`$(date +%Y%m%d_%H%M%S) (nome pode variar 1s)"
"@
Invoke-RemoteBash $backupScript

Write-Host ""

# 3) Corrigir configuração (envia e executa fix_nginx_n8n.sh)
Write-Host "[3/4] Corrigindo configuração do Nginx..." -ForegroundColor Yellow

Write-Host "   Copiando fix_nginx_n8n.sh para o servidor..." -ForegroundColor Gray
scp .\fix_nginx_n8n.sh "${SERVER_USER}@${SERVER_IP}:/tmp/fix_nginx_n8n.sh"

Write-Host "   Convertendo CRLF->LF e executando..." -ForegroundColor Gray
$runFixScript = @"
set -e
sed -i 's/\r$//' /tmp/fix_nginx_n8n.sh
chmod +x /tmp/fix_nginx_n8n.sh
bash /tmp/fix_nginx_n8n.sh
echo "✅ Script de correção executado"
"@
Invoke-RemoteBash $runFixScript

Write-Host ""

# 4) Testar e recarregar
Write-Host "[4/4] Testando e reiniciando Nginx..." -ForegroundColor Yellow
$testScript = @"
set -e
nginx -t
echo "✅ Configuração válida"
systemctl restart nginx
echo "✅ Nginx reiniciado"
echo ""
echo "Testando acesso /n8n:"
curl -k -sS https://api.taskflowv3.com.br/n8n/ `| head -5
"@
Invoke-RemoteBash $testScript

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "Correção Aplicada!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Teste no navegador:" -ForegroundColor Yellow
Write-Host "  https://api.taskflowv3.com.br/n8n" -ForegroundColor White
Write-Host ""
Write-Host "Deve mostrar login do N8N, NÃO erro do Kong!" -ForegroundColor Green
Write-Host ""
