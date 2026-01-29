# ============================================
# ver_chat_id_logs_telegram.ps1
# Puxa o chat_id (grupo/supergrupo/canal) direto dos logs do webhook no servidor
# ============================================

param(
    [string]$Server = 'root@212.85.0.249',
    [int]$Lines = 200,
    [string]$Since = '2 hours ago',
    [string]$Match = ''
)

function Try-SetClipboard([string]$text) {
    try {
        Set-Clipboard -Value $text
        Write-Host ('[OK] Copiado para a área de transferência: ' + $text) -ForegroundColor Green
    } catch {
        Write-Host '[AVISO] Não consegui copiar para a área de transferência.' -ForegroundColor Yellow
    }
}

Write-Host ''
Write-Host '==========================================' -ForegroundColor Cyan
Write-Host 'BUSCAR CHAT ID NOS LOGS DO WEBHOOK (TELEGRAM)' -ForegroundColor Cyan
Write-Host '==========================================' -ForegroundColor Cyan
Write-Host ('Servidor: ' + $Server) -ForegroundColor Gray
Write-Host ('Período:  ' + $Since) -ForegroundColor Gray
Write-Host ('Linhas:   ' + $Lines) -ForegroundColor Gray
if ($Match) { Write-Host ('Filtro:   ' + $Match) -ForegroundColor Gray }
Write-Host ''

$remote = "journalctl -u telegram-webhook.service --since '$Since' -n $Lines --no-pager -o cat"
if ($Match) {
    $remote = $remote + " | (grep -i -- '$Match' || true)"
}

Write-Host 'Lendo logs...' -ForegroundColor Yellow
$log = ssh $Server $remote 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host '[ERRO] Falha ao ler logs via SSH.' -ForegroundColor Red
    Write-Host $log -ForegroundColor Red
    exit 1
}

$patterns = @(
    '(?i)"chat"\s*:\s*\{[^}]*"id"\s*:\s*(-?\d+)',
    '(?i)"chat_id"\s*:\s*(-?\d+)',
    '(?i)\bchat\.id\b\s*[:=]\s*(-?\d+)',
    '(?i)\bchat_id\b\s*[:=]\s*(-?\d+)'
)

$ids = New-Object System.Collections.Generic.HashSet[string]
foreach ($p in $patterns) {
    foreach ($m in [regex]::Matches($log, $p)) {
        $null = $ids.Add($m.Groups[1].Value)
    }
}

Write-Host ''
Write-Host '==========================================' -ForegroundColor Cyan
Write-Host 'RESULTADOS' -ForegroundColor Cyan
Write-Host '==========================================' -ForegroundColor Cyan
Write-Host ''

if ($ids.Count -eq 0) {
    Write-Host '[AVISO] Nenhum chat_id encontrado.' -ForegroundColor Yellow
    exit 0
}

$idsSorted = $ids | Sort-Object {[long]$_}
$i = 1
foreach ($id in $idsSorted) {
    Write-Host ("[{0}] {1}" -f $i, $id) -ForegroundColor Green
    $i++
}

$choice = Read-Host 'Digite o número para copiar (ou Enter para sair)'
if ($choice -match '^\d+$') {
    $idx = [int]$choice
    if ($idx -ge 1 -and $idx -le $idsSorted.Count) {
        Try-SetClipboard $idsSorted[$idx-1]
    }
}

Write-Host 'Concluído.' -ForegroundColor Gray
