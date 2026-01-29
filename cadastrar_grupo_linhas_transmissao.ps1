# ============================================
# CADASTRAR GRUPO NEPTRFMT - LINHAS DE TRANSMISSÃO
# ============================================

param(
    [Parameter(Mandatory=$true)]
    [string]$TelegramChatId
)

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "CADASTRAR GRUPO NEPTRFMT - LINHAS DE TRANSMISSÃO" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Copiar script
Write-Host "Copiando script..." -ForegroundColor Yellow
scp cadastrar_grupo_linhas_transmissao.sh "${SERVER}:/root/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao copiar script!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Executando cadastro..." -ForegroundColor Yellow
ssh $SERVER "chmod +x /root/cadastrar_grupo_linhas_transmissao.sh; /root/cadastrar_grupo_linhas_transmissao.sh '$TelegramChatId'"
