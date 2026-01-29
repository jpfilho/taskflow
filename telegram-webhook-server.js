const express = require('express');
const { createClient } = require('@supabase/supabase-js');

// ==========================================
// CONFIGURAÇÃO
// ==========================================

const PORT = process.env.PORT || 3001;
const TELEGRAM_BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN || '8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec';
const TELEGRAM_WEBHOOK_SECRET = process.env.TELEGRAM_WEBHOOK_SECRET || 'TgWebhook2026Taskflow_Secret';
const SUPABASE_URL = process.env.SUPABASE_URL || 'http://127.0.0.1:8000';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjU4MTc5ODMsImV4cCI6MjA4MTE3Nzk4M30.MYcuHsPkBgYg_M1WVHKbtO3MQYalYNYOppr0Q3ynUgw';

// Cliente Supabase
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// ==========================================
// EXPRESS APP
// ==========================================

const app = express();

// Middleware CORS - Permitir requisições do Flutter web
app.use((req, res, next) => {
  // Permitir qualquer origem (em produção, especificar domínios permitidos)
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization, x-telegram-bot-api-secret-token');
  
  // Responder ao preflight request
  if (req.method === 'OPTIONS') {
    return res.sendStatus(200);
  }
  
  next();
});

// Middleware para parsing JSON com tratamento de erro
app.use(express.json({ limit: '10mb' }));
app.use((err, req, res, next) => {
  if (err instanceof SyntaxError && err.status === 400 && 'body' in err) {
    console.error('❌ Erro ao fazer parse do JSON:', err.message);
    return res.status(400).json({ error: 'JSON inválido', details: err.message });
  }
  next();
});

// Health check
app.get('/', (req, res) => {
  res.json({ 
    status: 'ok', 
    service: 'TaskFlow Telegram Webhook',
    timestamp: new Date().toISOString()
  });
});

// Webhook do Telegram
app.post('/telegram-webhook', async (req, res) => {
  try {
    // Validar secret token
    const secretToken = req.headers['x-telegram-bot-api-secret-token'];
    if (secretToken !== TELEGRAM_WEBHOOK_SECRET) {
      console.error('❌ Token de segurança inválido');
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const update = req.body;
    console.log('📨 Update recebido:', JSON.stringify(update, null, 2));

    // Processar mensagem
    if (update.message) {
      await processMessage(update.message, false);
    } else if (update.edited_message) {
      await processMessage(update.edited_message, true);
    } else if (update.callback_query) {
      await processCallbackQuery(update.callback_query);
    }

    res.json({ ok: true });
  } catch (error) {
    console.error('❌ Erro ao processar update:', error);
    res.status(500).json({ error: error.message });
  }
});

// Endpoint para enviar mensagem do Flutter para Telegram
app.post('/send-message', async (req, res) => {
  try {
    console.log('📥 Recebida requisição /send-message');
    console.log('   Headers:', JSON.stringify(req.headers, null, 2));
    console.log('   Body:', JSON.stringify(req.body, null, 2));
    
    const { mensagem_id, thread_type, thread_id } = req.body;

    if (!mensagem_id || !thread_type || !thread_id) {
      return res.status(400).json({ error: 'Parâmetros faltando: mensagem_id, thread_type, thread_id' });
    }

    console.log(`📤 Enviando mensagem ${mensagem_id} para Telegram (${thread_type}:${thread_id})`);

    // 1. Buscar mensagem no banco
    const { data: mensagem, error: msgError } = await supabase
      .from('mensagens')
      .select('*')
      .eq('id', mensagem_id)
      .single();

    if (msgError || !mensagem) {
      console.error('❌ Mensagem não encontrada:', msgError);
      return res.status(404).json({ error: 'Mensagem não encontrada' });
    }

    // 2. Buscar subscriptions ativas
    const { data: subscriptions, error: subError } = await supabase
      .from('telegram_subscriptions')
      .select('*')
      .eq('thread_type', thread_type)
      .eq('thread_id', thread_id)
      .eq('active', true);

    if (subError || !subscriptions || subscriptions.length === 0) {
      console.warn(`⚠️ Nenhuma subscription ativa para ${thread_type}:${thread_id}`);
      return res.json({ ok: true, sent: false, reason: 'No active subscriptions' });
    }

    // 3. Enviar para cada subscription
    let sentCount = 0;
    for (const subscription of subscriptions) {
      try {
        const chatId = subscription.telegram_chat_id;
        const topicId = subscription.telegram_topic_id;

        // Formatar mensagem
        let text = '';
        if (mensagem.conteudo) {
          text = `<b>${mensagem.usuario_nome || 'Usuário'}:</b>\n${mensagem.conteudo}`;
        } else {
          text = `<b>${mensagem.usuario_nome || 'Usuário'}</b> enviou uma mídia`;
        }

        // Se tiver arquivo, adicionar link
        if (mensagem.arquivo_url) {
          text += `\n\n📎 <a href="${mensagem.arquivo_url}">Ver anexo</a>`;
        }

        const payload = {
          chat_id: chatId,
          text: text,
          parse_mode: 'HTML',
        };

        if (topicId) {
          payload.message_thread_id = topicId;
        }

        const response = await fetch(
          `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
          }
        );

        const data = await response.json();
        if (data.ok) {
          sentCount++;
          console.log(`✅ Mensagem enviada para Telegram (chat: ${chatId}, topic: ${topicId})`);
        } else {
          console.error(`❌ Erro ao enviar para Telegram:`, data);
        }
      } catch (error) {
        console.error(`❌ Erro ao enviar para subscription ${subscription.id}:`, error);
      }
    }

    res.json({ ok: true, sent: sentCount > 0, sentCount });
  } catch (error) {
    console.error('❌ Erro ao processar send-message:', error);
    res.status(500).json({ error: error.message });
  }
});

// ==========================================
// PROCESSAMENTO DE MENSAGENS
// ==========================================

async function processMessage(message, isEdit) {
  console.log(`📝 Processando mensagem ${isEdit ? '(editada)' : ''} de ${message.from.first_name}`);

  const telegramUserId = message.from.id;
  const chatId = message.chat.id;

  // 1. Buscar usuário vinculado
  const { data: identity } = await supabase
    .from('telegram_identities')
    .select('user_id')
    .eq('telegram_user_id', telegramUserId)
    .single();

  if (!identity) {
    console.warn(`⚠️ Usuário Telegram ${telegramUserId} não vinculado`);
    await sendTelegramMessage(
      chatId,
      '⚠️ Sua conta Telegram ainda não está vinculada ao TaskFlow.\n\n' +
      'Use o botão "Vincular Telegram" no app para conectar sua conta.',
      message.message_thread_id
    );
    return;
  }

  // 2. Atualizar last_active
  await supabase
    .from('telegram_identities')
    .update({
      last_active_at: new Date().toISOString(),
      last_chat_id: chatId,
    })
    .eq('telegram_user_id', telegramUserId);

  // 3. Identificar thread
  const { threadType, threadId, grupoId } = await identifyThread(
    chatId,
    message.message_thread_id,
    identity.user_id
  );

  if (!grupoId) {
    console.warn('⚠️ Não foi possível identificar o grupo');
    await sendTelegramMessage(
      chatId,
      '⚠️ Não foi possível identificar o contexto desta conversa.\n' +
      'Certifique-se de que o chat está configurado corretamente no app.',
      message.message_thread_id
    );
    return;
  }

  // 4. Extrair conteúdo
  const conteudo = message.text || message.caption || '📎 Mídia';
  const tipo = message.photo ? 'imagem' : message.video ? 'video' : 'texto';

  // 5. Buscar nome do executor
  const { data: executor } = await supabase
    .from('executores')
    .select('nome, matricula')
    .eq('id', identity.user_id)
    .single();

  const usuarioNome = executor?.nome || message.from.first_name;

  // 6. Inserir mensagem
  const { data: novaMensagem, error } = await supabase
    .from('mensagens')
    .insert({
      grupo_id: grupoId,
      usuario_id: identity.user_id,
      usuario_nome: usuarioNome,
      conteudo,
      tipo,
      source: 'telegram',
      telegram_metadata: {
        chat_id: chatId,
        message_id: message.message_id,
        from_id: message.from.id,
        username: message.from.username,
        first_name: message.from.first_name,
        topic_id: message.message_thread_id,
        is_edit: isEdit,
      },
    })
    .select()
    .single();

  if (error) {
    console.error('❌ Erro ao inserir mensagem:', error);
    throw error;
  }

  console.log(`✅ Mensagem ${novaMensagem.id} inserida no grupo ${grupoId}`);

  // 7. Atualizar updated_at do grupo
  await supabase
    .from('grupos_chat')
    .update({ updated_at: new Date().toISOString() })
    .eq('id', grupoId);
}

async function identifyThread(chatId, topicId, userId) {
  // Buscar subscription
  let query = supabase
    .from('telegram_subscriptions')
    .select('thread_type, thread_id')
    .eq('telegram_chat_id', chatId)
    .eq('active', true);

  if (topicId) {
    query = query.eq('telegram_topic_id', topicId);
  } else {
    query = query.is('telegram_topic_id', null);
  }

  const { data: subscriptions } = await query;

  if (!subscriptions || subscriptions.length === 0) {
    return { threadType: '', threadId: null, grupoId: null };
  }

  const subscription = subscriptions[0];

  if (subscription.thread_type === 'TASK') {
    return {
      threadType: 'TASK',
      threadId: subscription.thread_id,
      grupoId: subscription.thread_id,
    };
  }

  return { threadType: '', threadId: null, grupoId: null };
}

async function processCallbackQuery(callbackQuery) {
  console.log('🔘 Processando callback query:', callbackQuery.data);
  // TODO: Implementar ações de botões
}

// ==========================================
// FUNÇÕES AUXILIARES
// ==========================================

async function sendTelegramMessage(chatId, text, topicId) {
  const payload = {
    chat_id: chatId,
    text,
    parse_mode: 'HTML',
  };

  if (topicId) {
    payload.message_thread_id = topicId;
  }

  try {
    const response = await fetch(
      `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      }
    );

    const data = await response.json();
    if (!data.ok) {
      console.error('❌ Erro ao enviar mensagem Telegram:', data);
    }
  } catch (error) {
    console.error('❌ Erro ao enviar mensagem:', error);
  }
}

// ==========================================
// INICIAR SERVIDOR
// ==========================================

app.listen(PORT, () => {
  console.log('==========================================');
  console.log('🚀 TaskFlow Telegram Webhook Server');
  console.log('==========================================');
  console.log(`✅ Servidor rodando na porta ${PORT}`);
  console.log(`📡 Webhook: http://localhost:${PORT}/telegram-webhook`);
  console.log(`🔗 Supabase: ${SUPABASE_URL}`);
  console.log('==========================================');
});
