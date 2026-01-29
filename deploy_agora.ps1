# ============================================
# Script de Deploy Rapido - Windows PowerShell
# ============================================
# Execute este script para fazer deploy
# dos arquivos build/web/ para o servidor

param(
    [switch]$NoBuild
)

# Configuracoes do servidor
$SERVER = "root@212.85.0.249"
$REMOTE_PATH = "/var/www/html/task2026"
$SSH_PORT = 22  # Porta SSH (padrao: 22, altere se necessario)

# Configuracao de autenticacao
# Opcao 1: Use chave SSH (recomendado - mais seguro)
# Nao precisa configurar senha se usar chave SSH

# Opcao 2: Use senha (menos seguro - nao recomendado para producao)
# Descomente a linha abaixo e coloque sua senha:
$PASSWORD = "Elen@264259281091"

# Se usar senha, instale o modulo Posh-SSH primeiro:
# Install-Module -Name Posh-SSH -Scope CurrentUser -Force

Write-Host "==========================================" -ForegroundColor Green
Write-Host "Deploy da Aplicacao para Producao" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Servidor: $SERVER" -ForegroundColor Cyan
Write-Host "Caminho remoto: $REMOTE_PATH" -ForegroundColor Cyan
Write-Host ""

# Verificar se precisa usar autenticacao por senha
$USE_PASSWORD = $false
$SSH_SESSION = $null
if ($PSBoundParameters.ContainsKey('PASSWORD') -or (Get-Variable -Name PASSWORD -ErrorAction SilentlyContinue)) {
    if ($PASSWORD) {
        $USE_PASSWORD = $true
        # Verificar se o modulo Posh-SSH esta instalado
        if (-not (Get-Module -ListAvailable -Name Posh-SSH)) {
            Write-Host "ERRO: Modulo Posh-SSH nao encontrado!" -ForegroundColor Red
            Write-Host "   Instale com: Install-Module -Name Posh-SSH -Scope CurrentUser -Force" -ForegroundColor Yellow
            exit 1
        }
        Import-Module Posh-SSH -Force
        Write-Host "Usando autenticacao por senha" -ForegroundColor Yellow
        
        # Extrair hostname e usuario do SERVER
        if ($SERVER -match '^(.+)@(.+)$') {
            $SSH_USER = $matches[1]
            $SSH_HOST = $matches[2]
        } else {
            $SSH_USER = "root"
            $SSH_HOST = $SERVER
        }
        
        # Testar conectividade basica
        Write-Host "Testando conectividade com $SSH_HOST:$SSH_PORT..." -ForegroundColor Cyan
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        try {
            $connect = $tcpClient.BeginConnect($SSH_HOST, $SSH_PORT, $null, $null)
            $wait = $connect.AsyncWaitHandle.WaitOne(5000, $false)
            if ($wait) {
                $tcpClient.EndConnect($connect)
                Write-Host "   Porta $SSH_PORT esta acessivel" -ForegroundColor Green
                $tcpClient.Close()
            } else {
                Write-Host "   AVISO: Timeout ao testar porta $SSH_PORT" -ForegroundColor Yellow
                Write-Host "   Continuando mesmo assim..." -ForegroundColor Yellow
                $tcpClient.Close()
            }
        } catch {
            Write-Host "   AVISO: Nao foi possivel testar conectividade: $_" -ForegroundColor Yellow
            Write-Host "   Continuando mesmo assim..." -ForegroundColor Yellow
        }
        
        # Criar credenciais e conectar
        Write-Host "Conectando ao servidor $SSH_HOST:$SSH_PORT..." -ForegroundColor Cyan
        $securePassword = ConvertTo-SecureString $PASSWORD -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($SSH_USER, $securePassword)
        
        try {
            # Tentar conectar com timeout aumentado (30 segundos)
            $SSH_SESSION = New-SSHSession -ComputerName $SSH_HOST -Port $SSH_PORT -Credential $credential -AcceptKey -ConnectionTimeout 30
            
            if (-not $SSH_SESSION) {
                Write-Host "ERRO: Falha ao conectar ao servidor!" -ForegroundColor Red
                Write-Host "   Verifique:" -ForegroundColor Yellow
                Write-Host "   - Se o servidor esta acessivel" -ForegroundColor Yellow
                Write-Host "   - Se a porta SSH esta correta (atual: $SSH_PORT)" -ForegroundColor Yellow
                Write-Host "   - Se a senha esta correta" -ForegroundColor Yellow
                exit 1
            }
            Write-Host "Conexao estabelecida com sucesso!" -ForegroundColor Green
        } catch {
            Write-Host "ERRO ao conectar: $_" -ForegroundColor Red
            Write-Host "   Verifique:" -ForegroundColor Yellow
            Write-Host "   - Se o servidor esta acessivel" -ForegroundColor Yellow
            Write-Host "   - Se a porta SSH esta correta (atual: $SSH_PORT)" -ForegroundColor Yellow
            Write-Host "   - Se a senha esta correta" -ForegroundColor Yellow
            Write-Host "   - Se o firewall permite conexoes SSH" -ForegroundColor Yellow
            exit 1
        }
    }
} else {
    Write-Host "Usando autenticacao por chave SSH" -ForegroundColor Green
}
Write-Host ""

# Funcoes auxiliares para SSH e SCP
function Invoke-RemoteCommand {
    param([string]$Command)
    if ($USE_PASSWORD -and $SSH_SESSION) {
        try {
            $result = Invoke-SSHCommand -SessionId $SSH_SESSION.SessionId -Command $Command -TimeOut 60
            if ($result.ExitStatus -ne 0) {
                Write-Host "   AVISO: Comando retornou codigo de erro: $($result.ExitStatus)" -ForegroundColor Yellow
                Write-Host "   Erro: $($result.Error)" -ForegroundColor Yellow
            }
            return $result.Output
        } catch {
            Write-Host "   ERRO ao executar comando remoto: $_" -ForegroundColor Red
            return ""
        }
    } else {
        $output = ssh $SERVER $Command 2>&1
        return $output
    }
}

function Copy-FilesToServer {
    param([string]$LocalPath, [string]$RemotePath)
    if ($USE_PASSWORD -and $SSH_SESSION) {
        Set-SCPFile -SessionId $SSH_SESSION.SessionId -LocalFile $LocalPath -RemotePath $RemotePath
    } else {
        scp -r $LocalPath "${SERVER}:${RemotePath}/"
    }
}

# Verificar se deve fazer build
$DO_BUILD = -not $NoBuild

if ($NoBuild) {
    Write-Host "AVISO: Pulando build (usando build existente)" -ForegroundColor Yellow
    Write-Host ""
}

# Fazer build se necessario
if ($DO_BUILD) {
    Write-Host "Fazendo build da aplicacao..." -ForegroundColor Cyan
    Write-Host ""
    
    # Limpar build anterior
    Write-Host "   Limpando build anterior..." -ForegroundColor Gray
    flutter clean | Out-Null
    
    # Obter dependencias
    Write-Host "   Obtendo dependencias..." -ForegroundColor Gray
    flutter pub get | Out-Null
    
    # Build para web
    Write-Host "   Compilando para web (release)..." -ForegroundColor Gray
    flutter build web --release --base-href="/task2026/"
    
    if (-not (Test-Path "build\web")) {
        Write-Host "ERRO: Build falhou! Diretorio build/web nao encontrado!" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "   Build concluido!" -ForegroundColor Green
    Write-Host ""
}

# Verificar se build/web existe
if (-not (Test-Path "build\web")) {
    Write-Host "ERRO: Diretorio build/web nao encontrado!" -ForegroundColor Red
    Write-Host "   Execute primeiro: flutter build web --release" -ForegroundColor Yellow
    exit 1
}

# Criar arquivo de versao com timestamp
$BUILD_TIMESTAMP = Get-Date -Format "yyyyMMdd_HHmmss"
$VERSION_FILE = "build\web\version.txt"
$BUILD_TIMESTAMP | Out-File -FilePath $VERSION_FILE -NoNewline -Encoding UTF8
Write-Host "Versao do build: $BUILD_TIMESTAMP" -ForegroundColor Cyan

# Aplicar cache-busting no index.html
Write-Host "Aplicando cache-busting em index.html..." -ForegroundColor Cyan
$indexPath = "build\web\index.html"
if (Test-Path $indexPath) {
    $content = Get-Content $indexPath -Raw
    $content = $content -replace 'main\.dart\.js', "main.dart.js?v=$BUILD_TIMESTAMP"
    $content = $content -replace 'flutter\.js', "flutter.js?v=$BUILD_TIMESTAMP"
    $content = $content -replace 'canvaskit\.wasm', "canvaskit.wasm?v=$BUILD_TIMESTAMP"
    $content = $content -replace 'flutter_service_worker\.js', "flutter_service_worker.js?v=$BUILD_TIMESTAMP"
    $content | Out-File -FilePath $indexPath -NoNewline -Encoding UTF8
}

# Desabilitar service worker para evitar cache agressivo
$flutterJsPath = "build\web\flutter.js"
if (Test-Path $flutterJsPath) {
    Write-Host "Desabilitando service worker..." -ForegroundColor Cyan
    $content = Get-Content $flutterJsPath -Raw
    $content = $content -replace 'navigator\.serviceWorker\.register\([^;]*;', ''
    $content | Out-File -FilePath $flutterJsPath -NoNewline -Encoding UTF8
}

# Remover service worker gerado
$swPath = "build\web\flutter_service_worker.js"
if (Test-Path $swPath) {
    "// Service worker desabilitado no deploy" | Out-File -FilePath $swPath -NoNewline -Encoding UTF8
}

# Criar regras de cache (.htaccess)
$htaccessContent = @"
# Forcar nao-cache para HTML e service worker
<FilesMatch "^(index\.html|flutter_service_worker\.js|version\.txt)$">
  Header set Cache-Control "no-store, no-cache, must-revalidate, max-age=0"
</FilesMatch>

# Ativos estaticos podem usar cache longo
<FilesMatch "\.(js|css|json|wasm|png|jpg|jpeg|gif|svg|ico)$">
  Header set Cache-Control "public, max-age=31536000, immutable"
</FilesMatch>
"@
$htaccessContent | Out-File -FilePath "build\web\.htaccess" -NoNewline -Encoding UTF8

Write-Host ""
Write-Host "Arquivos para deploy:" -ForegroundColor Cyan
$size = (Get-ChildItem -Path "build\web" -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
Write-Host "   $([math]::Round($size, 2)) MB" -ForegroundColor Gray
Write-Host ""

# Criar diretorio remoto se nao existir
Write-Host "Criando diretorio remoto (se necessario)..." -ForegroundColor Cyan
Invoke-RemoteCommand "mkdir -p $REMOTE_PATH && chmod 755 $REMOTE_PATH" | Out-Null

# Fazer backup do que ja existe (simplificado)
Write-Host ""
Write-Host "Fazendo backup do conteudo atual..." -ForegroundColor Cyan
$backupCmd = "if [ -d '$REMOTE_PATH' ]; then sudo cp -r '$REMOTE_PATH' '${REMOTE_PATH}_backup_`$(date +%Y%m%d_%H%M%S)'; fi"
Invoke-RemoteCommand $backupCmd | Out-Null

# Transferir arquivos usando SCP
Write-Host ""
Write-Host "Transferindo arquivos..." -ForegroundColor Cyan
Write-Host "   Isso pode levar alguns minutos..." -ForegroundColor Gray
Write-Host ""

# Limpar destino primeiro
Invoke-RemoteCommand "rm -rf $REMOTE_PATH/*" | Out-Null

# Transferir arquivos
Write-Host "   Transferindo arquivos..." -ForegroundColor Gray
$transferSuccess = $false
if ($USE_PASSWORD -and $SSH_SESSION) {
    # Usar SCP do Posh-SSH (transferencia recursiva)
    try {
        $files = Get-ChildItem -Path "build\web" -Recurse -File
        $totalFiles = $files.Count
        $currentFile = 0
        foreach ($file in $files) {
            $currentFile++
            $relativePath = $file.FullName.Substring((Resolve-Path "build\web").Path.Length + 1)
            $remoteFile = "$REMOTE_PATH/$relativePath".Replace('\', '/')
            $remoteDir = Split-Path $remoteFile -Parent
            Invoke-RemoteCommand "mkdir -p `"$remoteDir`"" | Out-Null
            Set-SCPFile -SessionId $SSH_SESSION.SessionId -LocalFile $file.FullName -RemotePath $remoteFile -ErrorAction Stop
            if ($currentFile % 10 -eq 0) {
                Write-Host "   Progresso: $currentFile/$totalFiles arquivos..." -ForegroundColor Gray
            }
        }
        $transferSuccess = $true
    } catch {
        Write-Host "   ERRO na transferencia: $_" -ForegroundColor Red
        $transferSuccess = $false
    }
} else {
    # Usar SCP nativo
    scp -r build\web\* "${SERVER}:${REMOTE_PATH}/"
    $transferSuccess = ($LASTEXITCODE -eq 0)
}

if (-not $transferSuccess) {
    Write-Host ""
    Write-Host "ERRO ao transferir arquivos!" -ForegroundColor Red
    if ($USE_PASSWORD -and $SSH_SESSION) {
        Remove-SSHSession -SessionId $SSH_SESSION.SessionId | Out-Null
    }
    exit 1
}

# Verificar se os arquivos foram transferidos
Write-Host ""
Write-Host "Verificando arquivos transferidos..." -ForegroundColor Cyan
$REMOTE_VERSION = Invoke-RemoteCommand "cat $REMOTE_PATH/version.txt 2>/dev/null || echo 'N/A'"
if ($REMOTE_VERSION -eq $BUILD_TIMESTAMP) {
    Write-Host "   Versao confirmada no servidor: $REMOTE_VERSION" -ForegroundColor Green
} else {
    Write-Host "   AVISO: Versao no servidor: $REMOTE_VERSION (esperado: $BUILD_TIMESTAMP)" -ForegroundColor Yellow
}

# Ajustar permissoes
Write-Host ""
Write-Host "Ajustando permissoes..." -ForegroundColor Cyan
Invoke-RemoteCommand "sudo chown -R www-data:www-data $REMOTE_PATH" | Out-Null
Invoke-RemoteCommand "sudo chmod -R 755 $REMOTE_PATH" | Out-Null

# Fechar sessao SSH se foi aberta
if ($USE_PASSWORD -and $SSH_SESSION) {
    Remove-SSHSession -SessionId $SSH_SESSION.SessionId | Out-Null
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Deploy concluido!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Acesse a aplicacao em:" -ForegroundColor Cyan
Write-Host "   http://212.85.0.249:8080/task2026/" -ForegroundColor Yellow
Write-Host "   ou" -ForegroundColor Gray
Write-Host "   http://taskflowv3.com.br/" -ForegroundColor Yellow
Write-Host ""
Write-Host "Dica: Se a versao nao atualizou no navegador:" -ForegroundColor Cyan
Write-Host "   - Pressione Ctrl+Shift+R para forcar atualizacao" -ForegroundColor Gray
Write-Host "   - Ou limpe o cache do navegador" -ForegroundColor Gray
Write-Host ""
Write-Host "Versao do build: $BUILD_TIMESTAMP" -ForegroundColor Cyan
Write-Host ""
