# Script para obter informações detalhadas de um grupo específico do Telegram
# Requer: Node.js, token do bot e Chat ID do grupo

param(
    [Parameter(Mandatory=$true)]
    [string]$ChatId,
    
    [string]$BotToken = ""
)

if ([string]::IsNullOrEmpty($BotToken)) {
    # Tentar obter do arquivo .env ou variável de ambiente
    if (Test-Path ".env") {
        $envContent = Get-Content ".env" | Where-Object { $_ -match "TELEGRAM_BOT_TOKEN" }
        if ($envContent) {
            $BotToken = ($envContent -split "=")[1].Trim().Trim('"').Trim("'")
        }
    }
    
    if ([string]::IsNullOrEmpty($BotToken)) {
        $BotToken = $env:TELEGRAM_BOT_TOKEN
    }
}

if ([string]::IsNullOrEmpty($BotToken)) {
    Write-Host "❌ Erro: Token do bot não fornecido" -ForegroundColor Red
    Write-Host ""
    Write-Host "Uso: .\obter_info_grupo_telegram.ps1 -ChatId '-1001234567890' [-BotToken 'SEU_TOKEN']" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Ou defina a variável de ambiente TELEGRAM_BOT_TOKEN" -ForegroundColor Yellow
    exit 1
}

Write-Host "🔍 Obtendo informações do grupo Telegram..." -ForegroundColor Cyan
Write-Host "Chat ID: $ChatId" -ForegroundColor Yellow
Write-Host ""

# Criar script Node.js temporário
$nodeScript = @"
const https = require('https');

const BOT_TOKEN = '$BotToken';
const CHAT_ID = '$ChatId';

// Função para fazer requisição à API do Telegram
function telegramRequest(method, params = {}) {
    return new Promise((resolve, reject) => {
        const queryString = new URLSearchParams(params).toString();
        const url = \`https://api.telegram.org/bot\${BOT_TOKEN}/\${method}?\${queryString}\`;
        
        https.get(url, (res) => {
            let data = '';
            res.on('data', (chunk) => { data += chunk; });
            res.on('end', () => {
                try {
                    const json = JSON.parse(data);
                    if (json.ok) {
                        resolve(json.result);
                    } else {
                        reject(new Error(json.description || 'Erro na API do Telegram'));
                    }
                } catch (e) {
                    reject(e);
                }
            });
        }).on('error', (err) => {
            reject(err);
        });
    });
}

async function main() {
    try {
        console.log('📋 Obtendo informações do grupo...');
        const chat = await telegramRequest('getChat', { chat_id: CHAT_ID });
        
        console.log('');
        console.log('✅ Informações do Grupo:');
        console.log('');
        console.log(\`   📌 Título: \${chat.title || 'N/A'}\`);
        console.log(\`   🆔 Chat ID: \${chat.id}\`);
        console.log(\`   📝 Tipo: \${chat.type}\`);
        
        if (chat.username) {
            console.log(\`   👤 Username: @\${chat.username}\`);
        }
        
        if (chat.description) {
            console.log(\`   📄 Descrição: \${chat.description}\`);
        }
        
        if (chat.invite_link) {
            console.log(\`   🔗 Link de convite: \${chat.invite_link}\`);
        }
        
        // Verificar se é um fórum (suporta tópicos)
        if (chat.is_forum !== undefined) {
            console.log(\`   💬 É Fórum (suporta tópicos): \${chat.is_forum ? 'Sim' : 'Não'}\`);
        }
        
        // Obter membros do bot (verificar se é administrador)
        try {
            console.log('');
            console.log('📋 Verificando status do bot no grupo...');
            const botMember = await telegramRequest('getChatMember', {
                chat_id: CHAT_ID,
                user_id: (await telegramRequest('getMe')).id
            });
            
            console.log(\`   👤 Status: \${botMember.status}\`);
            if (botMember.status === 'administrator') {
                console.log(\`   ✅ Bot é administrador!\`);
                if (botMember.can_manage_topics !== undefined) {
                    console.log(\`   📌 Pode gerenciar tópicos: \${botMember.can_manage_topics ? 'Sim' : 'Não'}\`);
                }
            } else {
                console.log(\`   ⚠️  Bot NÃO é administrador\`);
            }
        } catch (e) {
            console.log(\`   ⚠️  Não foi possível verificar status: \${e.message}\`);
        }
        
        console.log('');
        console.log('💡 Para usar este Chat ID no formulário de divisão:');
        console.log(\`   Copie o ID: \${chat.id}\`);
        console.log('');
        
    } catch (error) {
        console.error('❌ Erro:', error.message);
        if (error.message.includes('chat not found')) {
            console.error('');
            console.error('💡 Possíveis causas:');
            console.error('   1. O bot não está no grupo');
            console.error('   2. O Chat ID está incorreto');
            console.error('   3. O bot não tem permissões para acessar o grupo');
        }
        process.exit(1);
    }
}

main();
"@

$scriptPath = Join-Path $env:TEMP "obter_info_grupo_$(Get-Date -Format 'yyyyMMddHHmmss').js"
$nodeScript | Out-File -FilePath $scriptPath -Encoding UTF8

try {
    node $scriptPath
} catch {
    Write-Host "❌ Erro ao executar script: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Certifique-se de que o Node.js está instalado e no PATH" -ForegroundColor Yellow
} finally {
    if (Test-Path $scriptPath) {
        Remove-Item $scriptPath -Force
    }
}
