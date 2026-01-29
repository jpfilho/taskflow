# ============================================
# OBTER CHAT ID DO GRUPO NEPTRFMT - LINHAS DE TRANSMISSÃO
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "OBTER CHAT ID DO GRUPO" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Copiar script
Write-Host "Copiando script..." -ForegroundColor Yellow
scp obter_chat_id_linhas_transmissao.sh "${SERVER}:/root/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao copiar script!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Executando..." -ForegroundColor Yellow
ssh $SERVER 'chmod +x /root/obter_chat_id_linhas_transmissao.sh; /root/obter_chat_id_linhas_transmissao.sh'
