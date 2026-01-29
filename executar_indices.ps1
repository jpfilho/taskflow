# ============================================
# EXECUTAR INDICES HORAS_SAP VIA SSH
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host "===========================================" -ForegroundColor Green
Write-Host "CRIANDO INDICES OTIMIZADOS PARA HORAS_SAP" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green
Write-Host ""
Write-Host "AVISO: Voce precisara digitar a senha do servidor." -ForegroundColor Yellow
Write-Host ""

# Copiar script para o servidor
Write-Host "1. Enviando script para o servidor..." -ForegroundColor Cyan
scp executar_indices_ssh.sh "${SERVER}:/root/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERRO ao copiar arquivo!" -ForegroundColor Red
    exit 1
}

# Dar permissao de execucao
Write-Host ""
Write-Host "2. Dando permissao de execucao..." -ForegroundColor Cyan
ssh $SERVER "chmod +x /root/executar_indices_ssh.sh"

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERRO ao dar permissao!" -ForegroundColor Red
    exit 1
}

# Executar script no servidor
Write-Host ""
Write-Host "3. Executando script no servidor..." -ForegroundColor Cyan
Write-Host "   (Isso pode levar 2-3 minutos...)" -ForegroundColor Gray
ssh $SERVER "/root/executar_indices_ssh.sh"

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "===========================================" -ForegroundColor Green
    Write-Host "INDICES CRIADOS COM SUCESSO!" -ForegroundColor Green
    Write-Host "===========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "PROXIMO PASSO: Testar a tela Horas no Flutter" -ForegroundColor Yellow
    Write-Host "  - Pressione R no terminal do Flutter para Hot Restart" -ForegroundColor Gray
    Write-Host "  - Ou reinicie: flutter run -d windows" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "ERRO ao executar script!" -ForegroundColor Red
    Write-Host "Tente a OPCAO 2: executar um por vez no Supabase Studio" -ForegroundColor Yellow
    Write-Host "Veja o arquivo: EXECUTAR_UM_POR_VEZ.md" -ForegroundColor Yellow
}
