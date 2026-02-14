# build_android.ps1
# Build Android (APK ou App Bundle) - inspirado em deploy-task2026.ps1 e build_ios.sh
# Execute: powershell -ExecutionPolicy Bypass -File .\build_android.ps1
# Opcional: .\build_android.ps1 -NoClean   (pula flutter clean)
# Opcional: .\build_android.ps1 -NoVersion (não incrementa build number)

param(
  [switch]$NoClean,
  [switch]$NoVersion
)

$ErrorActionPreference = "Stop"

# =========================
# Configurações
# =========================
$PUBSPEC = "pubspec.yaml"

Write-Host "=========================================="
Write-Host "Build Android - Task Flow"
Write-Host "=========================================="
Write-Host ""

# =========================
# Ler versão do pubspec.yaml
# =========================
if (-not (Test-Path $PUBSPEC)) {
  throw "Arquivo $PUBSPEC não encontrado!"
}

$versionLine = Get-Content $PUBSPEC | Where-Object { $_ -match "^version:\s*(.+)$" } | Select-Object -First 1
if (-not $versionLine) {
  throw "Não foi possível ler 'version:' em $PUBSPEC"
}

$CURRENT_VERSION = ($versionLine -replace "^\s*version:\s*", "").Trim()
$parts = $CURRENT_VERSION -split "\+"
$VERSION_NUMBER = $parts[0]
$BUILD_NUMBER = if ($parts.Length -gt 1) { $parts[1] } else { "0" }

Write-Host "Versão atual: $CURRENT_VERSION"
Write-Host "  - Versão: $VERSION_NUMBER"
Write-Host "  - Build:  $BUILD_NUMBER"
Write-Host ""

# Incrementar build number (a menos que -NoVersion)
$NEW_BUILD_NUMBER = $BUILD_NUMBER
$NEW_VERSION = $CURRENT_VERSION
if (-not $NoVersion) {
  $NEW_BUILD_NUMBER = [int]$BUILD_NUMBER + 1
  $NEW_VERSION = "${VERSION_NUMBER}+${NEW_BUILD_NUMBER}"
  Write-Host "Incrementando build number -> $NEW_BUILD_NUMBER"
  $content = Get-Content $PUBSPEC -Raw
  $content = $content -replace "(?m)^(\s*version:\s*).*", ('$1' + $NEW_VERSION)
  Set-Content -Path $PUBSPEC -Value $content -NoNewline
  Write-Host "Pubspec atualizado para: $NEW_VERSION"
  Write-Host ""
}

# =========================
# Limpeza (opcional)
# =========================
if (-not $NoClean) {
  Write-Host "Limpando build anterior..."
  try { flutter clean | Out-Null } catch {}
  Write-Host "Limpeza concluída."
  Write-Host ""
} else {
  Write-Host "Pulando limpeza (-NoClean)."
  Write-Host ""
}

# =========================
# Dependências
# =========================
Write-Host "Obtendo dependências..."
flutter pub get | Out-Null
Write-Host "Dependências obtidas."
Write-Host ""

# =========================
# Menu de opções
# =========================
Write-Host "Escolha uma opção:"
Write-Host "  1) APK Debug (testes)"
Write-Host "  2) APK Release (instalação direta)"
Write-Host "  3) App Bundle Release (Play Store / AAB)"
Write-Host "  4) Apenas atualizar versão (sem build)"
Write-Host "  5) Cancelar"
Write-Host ""
$option = Read-Host "Opção (1-5)"

switch ($option) {
  "1" {
    Write-Host ""
    Write-Host "Fazendo build APK Debug..."
    flutter build apk --debug --build-number $NEW_BUILD_NUMBER
    $apkPath = "build\app\outputs\flutter-apk\app-debug.apk"
    if (Test-Path $apkPath) {
      Write-Host "APK Debug gerado: $apkPath"
    }
  }
  "2" {
    Write-Host ""
    Write-Host "Fazendo build APK Release..."
    flutter build apk --release --build-number $NEW_BUILD_NUMBER
    $apkPath = "build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $apkPath) {
      $size = (Get-Item $apkPath).Length / 1MB
      Write-Host "APK Release gerado: $apkPath"
      Write-Host "Tamanho: $([math]::Round($size, 2)) MB"
    }
  }
  "3" {
    Write-Host ""
    Write-Host "Fazendo build App Bundle (AAB) para Play Store..."
    flutter build appbundle --release --build-number $NEW_BUILD_NUMBER
    $aabPath = "build\app\outputs\bundle\release\app-release.aab"
    if (Test-Path $aabPath) {
      $size = (Get-Item $aabPath).Length / 1MB
      Write-Host "App Bundle gerado: $aabPath"
      Write-Host "Tamanho: $([math]::Round($size, 2)) MB"
      Write-Host "Use este arquivo para enviar à Play Store."
    }
  }
  "4" {
    Write-Host ""
    Write-Host "Versão atualizada para: $NEW_VERSION"
    Write-Host "Nenhum build foi executado."
  }
  "5" {
    Write-Host ""
    Write-Host "Operação cancelada."
    if (-not $NoVersion -and $NEW_VERSION -ne $CURRENT_VERSION) {
      $content = Get-Content $PUBSPEC -Raw
      $content = $content -replace "(?m)^(\s*version:\s*).*", ('$1' + $CURRENT_VERSION)
      Set-Content -Path $PUBSPEC -Value $content -NoNewline
      Write-Host "Versão revertida para: $CURRENT_VERSION"
    }
    exit 0
  }
  default {
    Write-Host "Opção inválida!"
    if (-not $NoVersion -and $NEW_VERSION -ne $CURRENT_VERSION) {
      $content = Get-Content $PUBSPEC -Raw
      $content = $content -replace "(?m)^(\s*version:\s*).*", ('$1' + $CURRENT_VERSION)
      Set-Content -Path $PUBSPEC -Value $content -NoNewline
      Write-Host "Versão revertida para: $CURRENT_VERSION"
    }
    exit 1
  }
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Processo concluído!"
Write-Host "=========================================="
Write-Host "Versão do build: $NEW_VERSION (build $NEW_BUILD_NUMBER)"
Write-Host ""
