# ==============================================================================
# TASKFLOW - SCRIPT POWERSHELL PARA CORREÇÃO DINÂMICA DE ANEXOS EM PRODUÇÃO
# ==============================================================================
# Varre 100% dos anexos existentes no servidor de produção de forma paralela,
# inspeciona os Magic Bytes no Storage e corrige vídeos (MP4), compactados (ZIP)
# e imagens com extensão divergente (.jpg ou .p_g).
# ==============================================================================

[CmdletBinding()]
param (
    [switch]$Aplicar,
    [switch]$DryRun,
    [string]$Nota = "",
    [int]$Workers = 15
)

Clear-Host
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host " TASKFLOW - CORRETOR DINÂMICO DE ANEXOS SAP NO SUPABASE STORAGE (PRODUÇÃO)" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan

# 1. Localiza o interpretador Python
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCmd) {
    $pythonCmd = Get-Command py -ErrorAction SilentlyContinue
}

if (-not $pythonCmd) {
    Write-Host "❌ Python não foi encontrado no PATH deste servidor!" -ForegroundColor Red
    Write-Host "   Instale o Python 3.9+ ou adicione ao PATH." -ForegroundColor Yellow
    exit 1
}

$scriptPy = Join-Path $PSScriptRoot "corrigir_anexos_supabase.py"
if (-not (Test-Path $scriptPy)) {
    Write-Host "❌ Script 'corrigir_anexos_supabase.py' não encontrado na pasta:" -ForegroundColor Red
    Write-Host "   $scriptPy" -ForegroundColor Yellow
    exit 1
}

# 2. Modo Interativo caso nenhum parâmetro tenha sido passado
if (-not $Aplicar -and -not $DryRun) {
    Write-Host ""
    Write-Host "Escolha o modo de execução para rodar em produção:" -ForegroundColor Yellow
    Write-Host "  [1] SIMULAR (Dry-Run) - Varre 100% dos anexos e mostra tudo que precisa ser corrigido sem alterar nada" -ForegroundColor Green
    Write-Host "  [2] APLICAR REAL - Varre e corrige tudo automaticamente no Storage e no Banco de Dados" -ForegroundColor Magenta
    Write-Host "  [3] CANCELAR" -ForegroundColor Gray
    Write-Host ""
    $escolha = Read-Host "Digite a opção desejada (1, 2 ou 3)"

    switch ($escolha) {
        "1" { $DryRun = $true }
        "2" {
            $confirma = Read-Host "⚠️ Confirma a execução em PRODUÇÃO para corrigir os anexos no Supabase? (S/N)"
            if ($confirma.ToUpper() -eq "S") {
                $Aplicar = $true
            } else {
                Write-Host "Operação cancelada pelo usuário." -ForegroundColor Gray
                exit 0
            }
        }
        default {
            Write-Host "Operação cancelada." -ForegroundColor Gray
            exit 0
        }
    }
}

# 3. Monta argumentos
$argsList = @()

if ($Aplicar) {
    $argsList += "--aplicar"
} else {
    $argsList += "--dry-run"
}

if ($Nota -and $Nota.Trim() -ne "") {
    $argsList += "--nota"
    $argsList += $Nota.Trim()
}

if ($Workers -gt 0) {
    $argsList += "--workers"
    $argsList += $Workers.ToString()
}

Write-Host ""
Write-Host "▶️ Iniciando varredura dinâmica no Supabase..." -ForegroundColor Cyan
Write-Host "   Comando: python $scriptPy $($argsList -join ' ')" -ForegroundColor DarkGray
Write-Host ""

# 4. Executa
& $pythonCmd.Source $scriptPy @argsList

Write-Host ""
Write-Host "Execução finalizada!" -ForegroundColor Green
