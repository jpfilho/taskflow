# ============================================
# CADASTRAR GRUPO NEPTRFMT - LINHAS DE TRANSMISSÃO
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "CADASTRAR GRUPO NEPTRFMT - LINHAS DE TRANSMISSÃO" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Copiar script
Write-Host "Copiando script..." -ForegroundColor Yellow
scp cadastrar_grupo_neptrfmt.sh "${SERVER}:/root/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao copiar script!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Executando..." -ForegroundColor Yellow
Write-Host "NOTA: Se o Chat ID não for encontrado automaticamente, você precisará fornecê-lo" -ForegroundColor Yellow
Write-Host ""
ssh $SERVER 'chmod +x /root/cadastrar_grupo_neptrfmt.sh; /root/cadastrar_grupo_neptrfmt.sh'
