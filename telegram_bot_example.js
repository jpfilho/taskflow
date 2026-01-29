// =========================================
// EXEMPLO DE BOT TELEGRAM (Node.js)
// =========================================
// Este é um exemplo simples de bot que processa comandos
// como /vincular e /ajuda
// 
// Para usar:
// 1. npm install node-telegram-bot-api
// 2. node telegram_bot_example.js
//
// ⚠️ IMPORTANTE: Este bot é apenas para processar comandos.
// As mensagens de chat são processadas via webhook (telegram-webhook Edge Function)

const TelegramBot = require('node-telegram-bot-api');
const { createClient } = require('@supabase/supabase-js');

// ========== CONFIGURAÇÃO ==========
const BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN;
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!BOT_TOKEN || !SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('❌ Variáveis de ambiente não configuradas!');
  console.error('Configure: TELEGRAM_BOT_TOKEN, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

const bot = new TelegramBot(BOT_TOKEN, { polling: true });
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

console.log('🤖 Bot iniciado! Aguardando comandos...');

// ========== COMANDO /start ==========
// Usado para vincular conta
bot.onText(/\/start(.*)/, async (msg, match) => {
  const chatId = msg.chat.id;
  const userId = msg.from.id;
  const username = msg.from.username;
  const firstName = msg.from.first_name;
  const lastName = msg.from.last_name;
  
  const payload = match[1]?.trim();
  
  console.log(`📨 /start recebido de ${firstName} (@${username})`);
  console.log(`   Payload: ${payload}`);
  
  if (payload && payload.startsWith('link_')) {
    // Extrair user_id do TaskFlow
    const taskflowUserId = payload.substring(5);
    
    try {
      // Verificar se usuário já está vinculado
      const { data: existing } = await supabase
        .from('telegram_identities')
        .select('id')
        .eq('telegram_user_id', userId)
        .single();
      
      if (existing) {
        await bot.sendMessage(chatId, 
          '✅ Sua conta já está vinculada ao TaskFlow!\n\n' +
          'Você pode fechar esta conversa e voltar ao app.'
        );
        return;
      }
      
      // Criar/atualizar identidade
      const { error } = await supabase
        .from('telegram_identities')
        .insert({
          user_id: taskflowUserId,
          telegram_user_id: userId,
          telegram_username: username,
          telegram_first_name: firstName,
          telegram_last_name: lastName,
          last_chat_id: chatId,
          linked_at: new Date().toISOString(),
          last_active_at: new Date().toISOString(),
        });
      
      if (error) {
        console.error('❌ Erro ao vincular conta:', error);
        await bot.sendMessage(chatId,
          '❌ Erro ao vincular conta. Por favor, tente novamente mais tarde.'
        );
        return;
      }
      
      console.log(`✅ Conta vinculada: ${firstName} (Telegram: ${userId} → TaskFlow: ${taskflowUserId})`);
      
      await bot.sendMessage(chatId,
        `✅ *Conta vinculada com sucesso!*\n\n` +
        `Olá, ${firstName}! Sua conta Telegram está agora conectada ao TaskFlow.\n\n` +
        `Você pode:\n` +
        `• Receber notificações dos seus chats\n` +
        `• Enviar mensagens que aparecerão no app\n` +
        `• Usar /ajuda para ver mais comandos\n\n` +
        `Volte ao app para configurar o espelhamento de chats.`,
        { parse_mode: 'Markdown' }
      );
    } catch (error) {
      console.error('❌ Erro ao processar vinculação:', error);
      await bot.sendMessage(chatId,
        '❌ Ocorreu um erro. Por favor, tente novamente.'
      );
    }
  } else {
    // Comando /start sem payload (boas-vindas)
    await bot.sendMessage(chatId,
      '👋 *Bem-vindo ao TaskFlow Bot!*\n\n' +
      'Este bot conecta o TaskFlow com o Telegram.\n\n' +
      '*Para começar:*\n' +
      '1. Abra o app TaskFlow\n' +
      '2. Vá em qualquer chat\n' +
      '3. Clique no ícone Telegram\n' +
      '4. Clique em "Vincular conta"\n' +
      '5. Copie o link e abra aqui no Telegram\n\n' +
      'Use /ajuda para ver mais informações.',
      { parse_mode: 'Markdown' }
    );
  }
});

// ========== COMANDO /ajuda ==========
bot.onText(/\/ajuda/, async (msg) => {
  const chatId = msg.chat.id;
  
  await bot.sendMessage(chatId,
    '📚 *Ajuda do TaskFlow Bot*\n\n' +
    '*Comandos disponíveis:*\n' +
    '/vincular - Vincular sua conta Telegram ao TaskFlow\n' +
    '/desvincular - Desvincular sua conta\n' +
    '/status - Ver status da vinculação\n' +
    '/ajuda - Mostrar esta mensagem\n\n' +
    '*Como funciona:*\n' +
    'Após vincular sua conta, você pode configurar espelhamento ' +
    'de chats no app TaskFlow. As mensagens enviadas aqui ' +
    'aparecerão no app, e vice-versa.\n\n' +
    '*Dúvidas?*\n' +
    'Entre em contato com o suporte.',
    { parse_mode: 'Markdown' }
  );
});

// ========== COMANDO /status ==========
bot.onText(/\/status/, async (msg) => {
  const chatId = msg.chat.id;
  const userId = msg.from.id;
  
  try {
    const { data: identity } = await supabase
      .from('telegram_identities')
      .select('*')
      .eq('telegram_user_id', userId)
      .single();
    
    if (!identity) {
      await bot.sendMessage(chatId,
        '⚠️ *Conta não vinculada*\n\n' +
        'Sua conta Telegram ainda não está conectada ao TaskFlow.\n\n' +
        'Use /vincular para conectar.',
        { parse_mode: 'Markdown' }
      );
      return;
    }
    
    await bot.sendMessage(chatId,
      '✅ *Conta vinculada*\n\n' +
      `*Nome:* ${identity.telegram_first_name}\n` +
      `*Username:* @${identity.telegram_username || 'N/A'}\n` +
      `*Vinculado em:* ${new Date(identity.linked_at).toLocaleDateString('pt-BR')}\n` +
      `*Última atividade:* ${new Date(identity.last_active_at).toLocaleDateString('pt-BR')}`,
      { parse_mode: 'Markdown' }
    );
  } catch (error) {
    console.error('❌ Erro ao buscar status:', error);
    await bot.sendMessage(chatId, '❌ Erro ao buscar informações.');
  }
});

// ========== COMANDO /desvincular ==========
bot.onText(/\/desvincular/, async (msg) => {
  const chatId = msg.chat.id;
  const userId = msg.from.id;
  
  try {
    const { error } = await supabase
      .from('telegram_identities')
      .delete()
      .eq('telegram_user_id', userId);
    
    if (error) {
      console.error('❌ Erro ao desvincular:', error);
      await bot.sendMessage(chatId, '❌ Erro ao desvincular conta.');
      return;
    }
    
    console.log(`🔓 Conta desvinculada: Telegram ${userId}`);
    
    await bot.sendMessage(chatId,
      '✅ *Conta desvinculada*\n\n' +
      'Sua conta Telegram foi desconectada do TaskFlow.\n\n' +
      'Use /vincular se quiser conectar novamente.',
      { parse_mode: 'Markdown' }
    );
  } catch (error) {
    console.error('❌ Erro ao desvincular:', error);
    await bot.sendMessage(chatId, '❌ Ocorreu um erro.');
  }
});

// ========== COMANDO /vincular ==========
bot.onText(/\/vincular/, async (msg) => {
  const chatId = msg.chat.id;
  
  await bot.sendMessage(chatId,
    '🔗 *Vincular Conta*\n\n' +
    'Para vincular sua conta:\n\n' +
    '1. Abra o app TaskFlow\n' +
    '2. Vá em qualquer chat\n' +
    '3. Clique no ícone Telegram (⚡️)\n' +
    '4. Clique em "Vincular conta"\n' +
    '5. Copie o link gerado\n' +
    '6. Abra o link aqui no Telegram\n\n' +
    'O link terá o formato:\n' +
    '`https://t.me/seu_bot?start=link_...`',
    { parse_mode: 'Markdown' }
  );
});

// ========== TRATAMENTO DE ERROS ==========
bot.on('polling_error', (error) => {
  console.error('❌ Erro de polling:', error);
});

bot.on('error', (error) => {
  console.error('❌ Erro do bot:', error);
});

// ========== GRACEFUL SHUTDOWN ==========
process.on('SIGINT', () => {
  console.log('\n🛑 Encerrando bot...');
  bot.stopPolling();
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log('\n🛑 Encerrando bot...');
  bot.stopPolling();
  process.exit(0);
});
