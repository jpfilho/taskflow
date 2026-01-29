# ============================================
# Deploy FINAL - Versao Simples e Robusta
# ============================================
# Nao usa ControlMaster, executa comandos sequencialmente

param(
    [switch]$NoBuild
)

$SERVER = "root@212.85.0.249"
$REMOTE_PATH = "/var/www/html/task2026"
$SSH_PORT = 22  # Porta SSH (padrao: 22, altere se necessario)
$PASSWORD = "Elen@264259281091"

Write-Host "==========================================" -ForegroundColor Green
Write-Host "DEPLOY FINAL - ROBUSTA E SIMPLES" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Servidor: $SERVER" -ForegroundColor Cyan
Write-Host "Porta SSH: $SSH_PORT" -ForegroundColor Cyan
Write-Host "Caminho remoto: $REMOTE_PATH" -ForegroundColor Cyan
Write-Host ""

# PASSO 1: BUILD
if (-not $NoBuild) {
    Write-Host "1. FAZENDO BUILD..." -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "   Limpando..." -ForegroundColor Gray
    flutter clean | Out-Null
    
    Write-Host "   Dependencias..." -ForegroundColor Gray
    flutter pub get | Out-Null
    
    Write-Host "   Compilando..." -ForegroundColor Gray
    flutter build web --release --base-href="/task2026/"
    
    if (-not (Test-Path "build\web")) {
        Write-Host ""
        Write-Host "ERRO: Build falhou!" -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
    Write-Host "   BUILD OK!" -ForegroundColor Green
} else {
    Write-Host "1. Pulando build..." -ForegroundColor Yellow
    if (-not (Test-Path "build\web")) {
        Write-Host "ERRO: build/web nao encontrado!" -ForegroundColor Red
        exit 1
    }
}

# PASSO 2: PREPARAR
Write-Host ""
Write-Host "2. PREPARANDO ARQUIVOS..." -ForegroundColor Cyan

$BUILD_TIMESTAMP = Get-Date -Format "yyyyMMdd_HHmmss"
$BUILD_TIMESTAMP | Out-File -FilePath "build\web\version.txt" -NoNewline -Encoding UTF8

$indexPath = "build\web\index.html"
if (Test-Path $indexPath) {
    $content = Get-Content $indexPath -Raw
    $content = $content -replace 'main\.dart\.js', "main.dart.js?v=$BUILD_TIMESTAMP"
    $content | Out-File -FilePath $indexPath -NoNewline -Encoding UTF8
}

$size = (Get-ChildItem -Path "build\web" -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
Write-Host "   Tamanho: $([math]::Round($size, 2)) MB" -ForegroundColor Gray
Write-Host "   Versao: $BUILD_TIMESTAMP" -ForegroundColor Gray

# PASSO 3: USAR SSHPASS OU PSCP (Instalar WinSCP)
Write-Host ""
Write-Host "3. TRANSFERINDO PARA SERVIDOR..." -ForegroundColor Cyan
Write-Host "   (Digite a senha quando solicitado)" -ForegroundColor Yellow
Write-Host ""

# Testar conectividade antes de tentar SSH
Write-Host "   Testando conectividade..." -ForegroundColor Gray
$hostname = ($SERVER -split '@')[1]
if ($hostname -match ':') {
    $hostname = ($hostname -split ':')[0]
}
$testConnection = Test-NetConnection -ComputerName $hostname -Port $SSH_PORT -WarningAction SilentlyContinue -InformationLevel Quiet
if (-not $testConnection) {
    Write-Host ""
    Write-Host "⚠️  AVISO: Não foi possível conectar na porta $SSH_PORT" -ForegroundColor Yellow
    Write-Host "   Possíveis causas:" -ForegroundColor Yellow
    Write-Host "   1. A porta SSH mudou (não é mais 22)" -ForegroundColor Yellow
    Write-Host "   2. O firewall está bloqueando" -ForegroundColor Yellow
    Write-Host "   3. O IP do servidor mudou" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   Para corrigir:" -ForegroundColor Yellow
    Write-Host "   - Edite a linha 12 do script e altere: `$SSH_PORT = 22" -ForegroundColor Cyan
    Write-Host "   - Exemplo: `$SSH_PORT = 2222" -ForegroundColor Cyan
    Write-Host ""
    $continue = Read-Host "   Continuar mesmo assim? (S/N)"
    if ($continue -ne 'S' -and $continue -ne 's') {
        Write-Host "   Deploy cancelado." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "   ✅ Conectividade OK na porta $SSH_PORT" -ForegroundColor Green
}

# Tentar usar Posh-SSH se disponível (melhor para autenticacao por senha)
$USE_POSH_SSH = $false
if ($PASSWORD) {
    if (Get-Module -ListAvailable -Name Posh-SSH) {
        Import-Module Posh-SSH -Force -ErrorAction SilentlyContinue
        if (Get-Module -Name Posh-SSH) {
            $USE_POSH_SSH = $true
            Write-Host "   Usando Posh-SSH para autenticacao..." -ForegroundColor Gray
        }
    }
}

# Tentar usar Posh-SSH primeiro (se disponivel e senha configurada)
if ($USE_POSH_SSH) {
    Write-Host "   Usando Posh-SSH..." -ForegroundColor Gray
    
    # Extrair hostname e usuario
    $serverParts = $SERVER -split '@'
    $SSH_USER = $serverParts[0]
    $SSH_HOST = $serverParts[1]
    if ($SSH_HOST -match ':') {
        $SSH_HOST = ($SSH_HOST -split ':')[0]
    }
    
    try {
        # Criar credenciais e conectar
        Write-Host "   Conectando ao servidor..." -ForegroundColor Gray
        $securePassword = ConvertTo-SecureString $PASSWORD -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($SSH_USER, $securePassword)
        $SSH_SESSION = New-SSHSession -ComputerName $SSH_HOST -Port $SSH_PORT -Credential $credential -AcceptKey -ConnectionTimeout 60
        
        if ($SSH_SESSION) {
            Write-Host "   ✅ Conectado!" -ForegroundColor Green
            
            # Criar diretorio
            Write-Host "   Criando diretorio..." -ForegroundColor Gray
            $result = Invoke-SSHCommand -SessionId $SSH_SESSION.SessionId -Command "mkdir -p $REMOTE_PATH && rm -rf $REMOTE_PATH/*" -TimeOut 60
            if ($result.ExitStatus -ne 0) {
                Write-Host "   ⚠️  Aviso ao criar/limpar diretorio (continuando...)" -ForegroundColor Yellow
            }
            
            # Transferir arquivos usando SCP
            Write-Host "   Transferindo arquivos (pode demorar)..." -ForegroundColor Gray
            Write-Host "   (Aguarde... isso pode levar alguns minutos)" -ForegroundColor Gray
            
            $files = Get-ChildItem -Path "build\web" -Recurse -File
            $totalFiles = $files.Count
            $currentFile = 0
            
            foreach ($file in $files) {
                $currentFile++
                $relativePath = $file.FullName.Substring((Resolve-Path "build\web").Path.Length + 1)
                $remoteFile = "$REMOTE_PATH/$relativePath".Replace('\', '/')
                $remoteDir = Split-Path $remoteFile -Parent
                
                # Criar diretorio remoto se necessario
                if ($remoteDir -ne $REMOTE_PATH) {
                    Invoke-SSHCommand -SessionId $SSH_SESSION.SessionId -Command "mkdir -p `"$remoteDir`"" -TimeOut 30 | Out-Null
                }
                
                # Transferir arquivo
                Set-SCPFile -ComputerName $SSH_HOST -Port $SSH_PORT -Credential $credential -LocalFile $file.FullName -RemotePath $remoteFile -AcceptKey -ConnectionTimeout 60 | Out-Null
                
                if ($currentFile % 10 -eq 0) {
                    Write-Host "   Progresso: $currentFile/$totalFiles arquivos..." -ForegroundColor Gray
                }
            }
            
            Write-Host "   ✅ Transferencia concluida!" -ForegroundColor Green
            
            # Ajustar permissoes
            Write-Host "   Ajustando permissoes..." -ForegroundColor Gray
            $result = Invoke-SSHCommand -SessionId $SSH_SESSION.SessionId -Command "sudo chown -R www-data:www-data $REMOTE_PATH && sudo chmod -R 755 $REMOTE_PATH" -TimeOut 60
            if ($result.ExitStatus -ne 0) {
                Write-Host "   ⚠️  Aviso ao ajustar permissoes (continuando...)" -ForegroundColor Yellow
            }
            
            # Fechar sessao
            Remove-SSHSession -SessionId $SSH_SESSION.SessionId | Out-Null
        } else {
            Write-Host "   ⚠️  Falha ao conectar com Posh-SSH, tentando outros metodos..." -ForegroundColor Yellow
            $USE_POSH_SSH = $false
        }
    } catch {
        Write-Host "   ⚠️  Erro ao usar Posh-SSH: $_" -ForegroundColor Yellow
        Write-Host "   Tentando outros metodos..." -ForegroundColor Yellow
        $USE_POSH_SSH = $false
    }
}

# Tentar com pscp do PuTTY (se instalado e Posh-SSH nao funcionou)
$pscpPath = "C:\Program Files\PuTTY\pscp.exe"
if (-not $USE_POSH_SSH -and (Test-Path $pscpPath)) {
    Write-Host "   Usando PuTTY pscp..." -ForegroundColor Gray
    
    # Criar diretorio
    Write-Host "   Criando diretorio..." -ForegroundColor Gray
    if ($SSH_PORT -ne 22) {
        & "C:\Program Files\PuTTY\plink.exe" -batch -P $SSH_PORT $SERVER "mkdir -p $REMOTE_PATH && rm -rf $REMOTE_PATH/*"
    } else {
        & "C:\Program Files\PuTTY\plink.exe" -batch $SERVER "mkdir -p $REMOTE_PATH && rm -rf $REMOTE_PATH/*"
    }
    
    # Transferir
    Write-Host "   Transferindo..." -ForegroundColor Gray
    if ($SSH_PORT -ne 22) {
        & $pscpPath -P $SSH_PORT -r build\web\* "${SERVER}:${REMOTE_PATH}/"
    } else {
        & $pscpPath -r build\web\* "${SERVER}:${REMOTE_PATH}/"
    }
    
    # Permissoes
    Write-Host "   Ajustando permissoes..." -ForegroundColor Gray
    if ($SSH_PORT -ne 22) {
        & "C:\Program Files\PuTTY\plink.exe" -batch -P $SSH_PORT $SERVER "sudo chown -R www-data:www-data $REMOTE_PATH && sudo chmod -R 755 $REMOTE_PATH"
    } else {
        & "C:\Program Files\PuTTY\plink.exe" -batch $SERVER "sudo chown -R www-data:www-data $REMOTE_PATH && sudo chmod -R 755 $REMOTE_PATH"
    }
    
}

# Usar SCP normal como ultimo recurso (pede senha varias vezes)
if (-not $USE_POSH_SSH) {
    # Configurar timeout maior para SSH
    $env:SSH_TIMEOUT = "60"
    
    Write-Host "   Criando diretorio..." -ForegroundColor Gray
    # Aumentar timeout para 60 segundos e melhorar opcoes de conexao
    $sshOpts = "-o ConnectTimeout=60 -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o StrictHostKeyChecking=no"
    $scpOpts = "-o ConnectTimeout=60 -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o StrictHostKeyChecking=no"
    
    $sshCmd = if ($SSH_PORT -ne 22) { "ssh -p $SSH_PORT $sshOpts" } else { "ssh $sshOpts" }
    $scpCmd = if ($SSH_PORT -ne 22) { "scp -P $SSH_PORT $scpOpts -r" } else { "scp $scpOpts -r" }
    
    $result = & cmd /c "$sshCmd $SERVER `"mkdir -p $REMOTE_PATH`" 2>&1"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "   ⚠️  Aviso ao criar diretorio (continuando...)" -ForegroundColor Yellow
        if ($result) { Write-Host "   $result" -ForegroundColor Gray }
    }
    
    Write-Host "   Limpando conteudo antigo..." -ForegroundColor Gray
    $result = & cmd /c "$sshCmd $SERVER `"rm -rf $REMOTE_PATH/*`" 2>&1"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "   ⚠️  Aviso ao limpar (continuando...)" -ForegroundColor Yellow
        if ($result) { Write-Host "   $result" -ForegroundColor Gray }
    }
    
    Write-Host "   Transferindo arquivos (pode demorar)..." -ForegroundColor Gray
    Write-Host "   (Aguarde... isso pode levar alguns minutos)" -ForegroundColor Gray
    $result = & cmd /c "$scpCmd build\web\* `"${SERVER}:${REMOTE_PATH}/`" 2>&1"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "ERRO ao transferir!" -ForegroundColor Red
        if ($result) {
            Write-Host "   Detalhes do erro:" -ForegroundColor Red
            $result | ForEach-Object { Write-Host "   $_" -ForegroundColor Red }
        }
        Write-Host ""
        Write-Host "   Dicas para resolver:" -ForegroundColor Yellow
        Write-Host "   1. Teste a conexao manualmente:" -ForegroundColor Yellow
        Write-Host "      ssh $SERVER" -ForegroundColor Cyan
        Write-Host "   2. Verifique se a porta SSH esta correta: $SSH_PORT" -ForegroundColor Yellow
        Write-Host "   3. O Test-NetConnection mostrou que a porta esta acessivel" -ForegroundColor Yellow
        Write-Host "   4. Pode ser problema de autenticacao ou firewall" -ForegroundColor Yellow
        Write-Host "   5. Tente usar chave SSH em vez de senha" -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "   Ajustando permissoes..." -ForegroundColor Gray
    $result = & cmd /c "$sshCmd $SERVER `"sudo chown -R www-data:www-data $REMOTE_PATH`" 2>&1"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "   ⚠️  Aviso ao ajustar owner (continuando...)" -ForegroundColor Yellow
    }
    $result = & cmd /c "$sshCmd $SERVER `"sudo chmod -R 755 $REMOTE_PATH`" 2>&1"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "   ⚠️  Aviso ao ajustar permissoes (continuando...)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "DEPLOY CONCLUIDO!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Acesse: http://212.85.0.249:8080/task2026/" -ForegroundColor Yellow
Write-Host ""
Write-Host "Versao: $BUILD_TIMESTAMP" -ForegroundColor Cyan
Write-Host ""
Write-Host "Pressione Ctrl+Shift+R no navegador!" -ForegroundColor Gray
Write-Host ""
