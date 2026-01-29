#!/bin/bash
# Script para obter IDs dos grupos do Telegram onde o bot está como administrador
# Requer: Node.js e token do bot Telegram

BOT_TOKEN="${1:-${TELEGRAM_BOT_TOKEN}}"

if [ -z "$BOT_TOKEN" ]; then
    echo "❌ Erro: Token do bot não fornecido"
    echo ""
    echo "Uso: ./obter_ids_grupos_telegram.sh [SEU_TOKEN]"
    echo ""
    echo "Ou defina a variável de ambiente TELEGRAM_BOT_TOKEN"
    exit 1
fi

echo "🔍 Buscando grupos do Telegram onde o bot está como administrador..."
echo ""

# Criar script Node.js temporário
cat > /tmp/obter_grupos_telegram_$$.js << 'NODE_SCRIPT'
const https = require('https');

const BOT_TOKEN = process.argv[2];

// Função para fazer requisição à API do Telegram
function telegramRequest(method, params = {}) {
    return new Promise((resolve, reject) => {
        const queryString = new URLSearchParams(params).toString();
        const url = `https://api.telegram.org/bot${BOT_TOKEN}/${method}?${queryString}`;
        
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
        console.log('📋 Obtendo informações do bot...');
        const botInfo = await telegramRequest('getMe');
        console.log(`✅ Bot: @${botInfo.username} (${botInfo.first_name})`);
        console.log('');
        
        console.log('📋 Buscando grupos...');
        console.log('⚠️  Nota: A API do Telegram não permite listar todos os grupos diretamente.');
        console.log('    Você precisa usar uma das seguintes opções:');
        console.log('');
        console.log('1️⃣  Enviar uma mensagem no grupo e verificar os logs do webhook');
        console.log('2️⃣  Usar o método abaixo para obter informações de um grupo específico');
        console.log('');
        console.log('Para obter informações de um grupo específico, use:');
        console.log('   node obter_info_grupo.js <CHAT_ID>');
        console.log('');
        console.log('O Chat ID pode ser obtido:');
        console.log('   - Enviando uma mensagem no grupo e verificando os logs');
        console.log('   - Usando bots como @userinfobot ou @getidsbot');
        console.log('   - Adicionando o bot @RawDataBot ao grupo');
        console.log('');
        
        // Tentar obter updates recentes (pode conter informações de grupos)
        console.log('📋 Verificando updates recentes...');
        try {
            const updates = await telegramRequest('getUpdates', { limit: 100 });
            
            const grupos = new Map();
            
            for (const update of updates) {
                if (update.message && update.message.chat) {
                    const chat = update.message.chat;
                    if (chat.type === 'supergroup' || chat.type === 'group') {
                        const chatId = chat.id.toString();
                        if (!grupos.has(chatId)) {
                            grupos.set(chatId, {
                                id: chatId,
                                title: chat.title || 'Sem título',
                                type: chat.type,
                                username: chat.username || null,
                                lastSeen: new Date(update.message.date * 1000).toLocaleString('pt-BR')
                            });
                        }
                    }
                }
            }
            
            if (grupos.size > 0) {
                console.log(`✅ Encontrados ${grupos.size} grupo(s) nos updates recentes:`);
                console.log('');
                for (const [id, info] of grupos) {
                    console.log(`   📌 ${info.title}`);
                    console.log(`      ID: ${info.id}`);
                    console.log(`      Tipo: ${info.type}`);
                    if (info.username) {
                        console.log(`      Username: @${info.username}`);
                    }
                    console.log(`      Última mensagem: ${info.lastSeen}`);
                    console.log('');
                }
            } else {
                console.log('⚠️  Nenhum grupo encontrado nos updates recentes.');
                console.log('');
            }
        } catch (e) {
            console.log(`⚠️  Erro ao obter updates: ${e.message}`);
            console.log('');
        }
        
    } catch (error) {
        console.error('❌ Erro:', error.message);
        process.exit(1);
    }
}

main();
NODE_SCRIPT

node /tmp/obter_grupos_telegram_$$.js "$BOT_TOKEN"
rm -f /tmp/obter_grupos_telegram_$$.js
