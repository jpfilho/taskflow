#!/bin/bash
# Script para obter informações detalhadas de um grupo específico do Telegram
# Requer: Node.js, token do bot e Chat ID do grupo

if [ -z "$1" ]; then
    echo "❌ Erro: Chat ID não fornecido"
    echo ""
    echo "Uso: ./obter_info_grupo_telegram.sh <CHAT_ID> [BOT_TOKEN]"
    echo ""
    echo "Exemplo: ./obter_info_grupo_telegram.sh -1001234567890"
    exit 1
fi

CHAT_ID="$1"
BOT_TOKEN="${2:-${TELEGRAM_BOT_TOKEN}}"

if [ -z "$BOT_TOKEN" ]; then
    # Tentar obter do arquivo .env
    if [ -f ".env" ]; then
        BOT_TOKEN=$(grep "TELEGRAM_BOT_TOKEN" .env | cut -d '=' -f2 | tr -d '"' | tr -d "'" | tr -d ' ')
    fi
fi

if [ -z "$BOT_TOKEN" ]; then
    echo "❌ Erro: Token do bot não fornecido"
    echo ""
    echo "Uso: ./obter_info_grupo_telegram.sh <CHAT_ID> [BOT_TOKEN]"
    echo ""
    echo "Ou defina a variável de ambiente TELEGRAM_BOT_TOKEN"
    exit 1
fi

echo "🔍 Obtendo informações do grupo Telegram..."
echo "Chat ID: $CHAT_ID"
echo ""

# Criar script Node.js temporário
cat > /tmp/obter_info_grupo_$$.js << NODE_SCRIPT
const https = require('https');

const BOT_TOKEN = '$BOT_TOKEN';
const CHAT_ID = '$CHAT_ID';

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
NODE_SCRIPT

node /tmp/obter_info_grupo_$$.js
rm -f /tmp/obter_info_grupo_$$.js
