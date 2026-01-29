# Corrigir interpolacao de string - falta o $ antes do v

$file = "lib\services\hora_sap_service.dart"
$content = Get-Content $file -Raw

# Corrigir todas as ocorrencias de 'campo.eq.v' para 'campo.eq.$v'
$content = $content -replace "\.eq\.v'", ".eq.`$v'"

Set-Content $file $content -NoNewline

Write-Host "INTERPOLACAO CORRIGIDA!" -ForegroundColor Green
Write-Host "Todos os .eq.v foram corrigidos para .eq.dollar v" -ForegroundColor Cyan
