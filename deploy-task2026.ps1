# deploy-task2026.ps1
# Execute: powershell -ExecutionPolicy Bypass -File .\deploy-task2026.ps1
# Opcional: .\deploy-task2026.ps1 -NoBuild

param(
  [switch]$NoBuild
)

$ErrorActionPreference = "Stop"

# =========================
# Configurações
# =========================
$SERVER      = "root@212.85.0.249"
$REMOTE_PATH = "/var/www/html/task2026"

# Reuso de conexão SSH (Windows: ControlPath melhor em pasta local)
$cmDir = Join-Path $env:USERPROFILE ".ssh\cm"
New-Item -ItemType Directory -Force -Path $cmDir | Out-Null
$ControlPath = (Join-Path $cmDir "cm-%r@%h-%p").Replace("\","/")

$SSH_OPTS = @(
  "-o","ControlMaster=auto",
  "-o","ControlPath=$ControlPath",
  "-o","ControlPersist=300"
)

Write-Host "=========================================="
Write-Host "Deploy da Aplicação para Produção"
Write-Host "=========================================="
Write-Host ""
Write-Host "Servidor: $SERVER"
Write-Host "Caminho remoto: $REMOTE_PATH"
Write-Host ""

# =========================
# Build (opcional)
# =========================
if (-not $NoBuild) {
  Write-Host "🔨 Fazendo build da aplicação..."
  Write-Host ""

  Write-Host "   🧹 Limpando build anterior..."
  try { flutter clean | Out-Null } catch {}

  Write-Host "   📦 Obtendo dependências..."
  flutter pub get | Out-Null

  Write-Host "   ⚙️  Compilando para web (release)..."
  flutter build web --release --base-href="/task2026/"

  if (-not (Test-Path "build\web")) {
    throw "❌ Erro: Build falhou! Diretório build/web não encontrado!"
  }

  Write-Host "   ✅ Build concluído!"
  Write-Host ""
} else {
  Write-Host "⚠️  Pulando build (usando build existente)"
}

# Verificar build/web
if (-not (Test-Path "build\web")) {
  throw "❌ Erro: Diretório build/web não encontrado! Execute: flutter build web --release"
}

# =========================
# Version + cache-busting
# =========================
$BUILD_TIMESTAMP = Get-Date -Format "yyyyMMdd_HHmmss"
$VERSION_FILE = "build\web\version.txt"
Set-Content -Path $VERSION_FILE -Value $BUILD_TIMESTAMP -Encoding ASCII
Write-Host "📝 Versão do build: $BUILD_TIMESTAMP"

function Replace-InFile {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$true)][hashtable]$Replacements
  )
  if (-not (Test-Path $Path)) { return }
  $content = Get-Content $Path -Raw

  foreach ($k in $Replacements.Keys) {
    $content = $content -replace [regex]::Escape($k), $Replacements[$k]
  }

  Set-Content -Path $Path -Value $content -Encoding UTF8
}

Write-Host "🔄 Aplicando cache-busting em index.html e arquivos..."
$repl = @{
  "main.dart.js"               = "main.dart.js?v=$BUILD_TIMESTAMP"
  "flutter.js"                 = "flutter.js?v=$BUILD_TIMESTAMP"
  "canvaskit.wasm"             = "canvaskit.wasm?v=$BUILD_TIMESTAMP"
  "flutter_service_worker.js"  = "flutter_service_worker.js?v=$BUILD_TIMESTAMP"
}
Replace-InFile -Path "build\web\index.html" -Replacements $repl

# Garantir SW com versão também em flutter.js
if (Test-Path "build\web\flutter.js") {
  Replace-InFile -Path "build\web\flutter.js" -Replacements @{
    "flutter_service_worker.js" = "flutter_service_worker.js?v=$BUILD_TIMESTAMP"
  }

  # 🚫 Desabilitar registro do service worker (remove linha(s) com register)
  $flutterJs = Get-Content "build\web\flutter.js" -Raw
  $flutterJs = [regex]::Replace($flutterJs, 'navigator\.serviceWorker\.register\([^;]*;\s*', '')
  Set-Content -Path "build\web\flutter.js" -Value $flutterJs -Encoding UTF8
}

# Opcional: remover SW gerado (evita SW legado)
if (Test-Path "build\web\flutter_service_worker.js") {
  Set-Content -Path "build\web\flutter_service_worker.js" -Value "// Service worker desabilitado no deploy" -Encoding ASCII
}

# Reforçar versionamento do SW no main.dart.js (se existir)
if (Test-Path "build\web\main.dart.js") {
  Replace-InFile -Path "build\web\main.dart.js" -Replacements @{
    "flutter_service_worker.js" = "flutter_service_worker.js?v=$BUILD_TIMESTAMP"
  }
}

# Criar .htaccess
$htaccess = @'
# Forçar não-cache para HTML e service worker
<FilesMatch "^(index\.html|flutter_service_worker\.js|version\.txt)$">
  Header set Cache-Control "no-store, no-cache, must-revalidate, max-age=0"
</FilesMatch>

# Ativos estáticos podem usar cache longo
<FilesMatch "\.(js|css|json|wasm|png|jpg|jpeg|gif|svg|ico)$">
  Header set Cache-Control "public, max-age=31536000, immutable"
</FilesMatch>
'@
Set-Content -Path "build\web\.htaccess" -Value $htaccess -Encoding ASCII

Write-Host ""
Write-Host "📦 Arquivos para deploy:"
$size = (Get-ChildItem "build\web" -Recurse | Measure-Object -Property Length -Sum).Sum
"{0:N2} MB" -f ($size/1MB) | ForEach-Object { Write-Host "   build/web: $_" }
Write-Host ""

# =========================
# Criar diretório remoto
# =========================
Write-Host "📁 Criando diretório remoto (se necessário)..."
Write-Host "   Executando: ssh $SERVER 'mkdir -p $REMOTE_PATH'"
try {
  & ssh @SSH_OPTS $SERVER "mkdir -p '$REMOTE_PATH'; chmod 755 '$REMOTE_PATH'"
} catch {
  Write-Host ""
  Write-Host "⚠️  Não foi possível criar o diretório automaticamente."
  Write-Host "📝 Execute manualmente no servidor:"
  Write-Host "   ssh $SERVER"
  Write-Host "   mkdir -p $REMOTE_PATH"
  Write-Host "   chmod 755 $REMOTE_PATH"
  Write-Host ""
  Read-Host "Pressione Enter após criar o diretório para continuar..."
}

# =========================
# Backup remoto
# =========================
Write-Host ""
Write-Host "💾 Fazendo backup do conteúdo atual..."
try {
  $remoteCmd = @'
if [ -d '$REMOTE_PATH' ] && [ "$(ls -A $REMOTE_PATH 2>/dev/null)" ]; then
  BACKUP_DIR='${REMOTE_PATH}_backup_$(date +%Y%m%d_%H%M%S)'
  sudo cp -r '$REMOTE_PATH' "$BACKUP_DIR"
  echo "✅ Backup criado: $BACKUP_DIR"
fi
'@
  # Substituir variáveis PowerShell no comando remoto
  $remoteCmd = $remoteCmd -replace '\$REMOTE_PATH', $REMOTE_PATH
  & ssh @SSH_OPTS $SERVER $remoteCmd
} catch {
  Write-Host "⚠️  Não foi possível fazer backup (continuando...)"
}

# =========================
# Transferência (rsync -> scp)
# =========================
Write-Host ""
Write-Host "📤 Transferindo arquivos..."

function Has-Command($name) {
  return $null -ne (Get-Command $name -ErrorAction SilentlyContinue)
}

if (Has-Command "rsync") {
  Write-Host "   Usando rsync: -avz --progress --delete --checksum"
  $rsyncTarget = "${SERVER}:${REMOTE_PATH}/"
  & rsync -avz --progress --delete --checksum `
    -e ("ssh " + ($SSH_OPTS -join " ")) `
    --exclude ".DS_Store" `
    --exclude ".git" `
    "build/web/" `
    $rsyncTarget
} else {
  Write-Host "⚠️  rsync não encontrado. Usando scp (mais lento) + limpeza remota..."
  try { & ssh @SSH_OPTS $SERVER "rm -rf '$REMOTE_PATH'/*" } catch {}
  $scpTarget = "${SERVER}:${REMOTE_PATH}/"
  & scp @SSH_OPTS -r "build\web\*" $scpTarget
}

# =========================
# Verificação de versão
# =========================
Write-Host ""
Write-Host "🔍 Verificando arquivos transferidos..."
$REMOTE_VERSION = & ssh @SSH_OPTS $SERVER "cat '$REMOTE_PATH/version.txt' 2>/dev/null || echo 'N/A'"
if ($REMOTE_VERSION.Trim() -eq $BUILD_TIMESTAMP) {
  Write-Host "   ✅ Versão confirmada no servidor: $($REMOTE_VERSION.Trim())"
} else {
  Write-Host "   ⚠️  Versão no servidor: $($REMOTE_VERSION.Trim()) (esperado: $BUILD_TIMESTAMP)"
}

# =========================
# Permissões
# =========================
Write-Host ""
Write-Host "🔐 Ajustando permissões..."
try {
  & ssh @SSH_OPTS $SERVER "sudo chown -R www-data:www-data '$REMOTE_PATH'; sudo chmod -R 755 '$REMOTE_PATH'"
} catch {
  Write-Host "⚠️  Não foi possível ajustar permissões automaticamente. Ajuste manualmente se necessário."
}

Write-Host ""
Write-Host "✅ Deploy concluído!"
Write-Host ""
Write-Host "🌐 Acesse a aplicação em:"
Write-Host "   http://212.85.0.249:8080/task2026/"
Write-Host "   ou"
Write-Host "   http://taskflowv3.com.br/ (redireciona para http://212.85.0.249:8080/task2026/)"
Write-Host ""
Write-Host "📋 Versão do build: $BUILD_TIMESTAMP"
Write-Host ""
