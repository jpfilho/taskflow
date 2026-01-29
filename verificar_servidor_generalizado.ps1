# ============================================
# VERIFICAR SERVIDOR GENERALIZADO
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================="
Write-Host "VERIFICAR SERVIDOR GENERALIZADO"
Write-Host "==========================================="
Write-Host ""

# Copiar script
Write-Host "Copiando script de verificação..."
scp verificar_servidor_generalizado.sh ${SERVER}:/root/

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Erro ao copiar script!"
    exit 1
}

Write-Host ""
Write-Host "Executando verificação..."
ssh $SERVER "chmod +x /root/verificar_servidor_generalizado.sh && /root/verificar_servidor_generalizado.sh"

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "==========================================="
    Write-Host "VERIFICAÇÃO CONCLUÍDA!"
    Write-Host "==========================================="
} else {
    Write-Host ""
    Write-Host "❌ Erro na verificação!"
    exit 1
}
