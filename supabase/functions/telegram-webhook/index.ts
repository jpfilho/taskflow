// =========================================
// TELEGRAM WEBHOOK - EDGE FUNCTION
// =========================================
// Recebe updates do Telegram e persiste no Supabase
// Deploy: supabase functions deploy telegram-webhook

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const TELEGRAM_BOT_TOKEN = Deno.env.get("TELEGRAM_BOT_TOKEN")!;
const TELEGRAM_WEBHOOK_SECRET = Deno.env.get("TELEGRAM_WEBHOOK_SECRET")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Cliente Supabase com service_role (bypass RLS)
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

interface TelegramMessage {
  message_id: number;
  from: {
    id: number;
    username?: string;
    first_name: string;
    last_name?: string;
  };
  chat: {
    id: number;
    type: string;
  };
  text?: string;
  caption?: string;
  message_thread_id?: number; // ID do tópico (se for forum)
  is_topic_message?: boolean;
  photo?: any[];
  video?: any;
  document?: any;
  audio?: any;
  voice?: any;
  location?: any;
}

interface TelegramUpdate {
  update_id: number;
  message?: TelegramMessage;
  edited_message?: TelegramMessage;
  callback_query?: any;
}

serve(async (req: Request) => {
  try {
    // Validar header de segurança
    const secretToken = req.headers.get("x-telegram-bot-api-secret-token");
    if (secretToken !== TELEGRAM_WEBHOOK_SECRET) {
      console.error("❌ Token de segurança inválido");
      return new Response("Unauthorized", { status: 401 });
    }

    // Parse do body
    const update: TelegramUpdate = await req.json();
    console.log("📨 Update recebido:", JSON.stringify(update, null, 2));

    // Processar mensagem
    const message = update.message || update.edited_message;
    if (message) {
      await processMessage(message, update.edited_message != null);
    }

    // Processar callback_query (botões inline)
    if (update.callback_query) {
      await processCallbackQuery(update.callback_query);
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("❌ Erro ao processar update:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});

async function processMessage(message: TelegramMessage, isEdit: boolean) {
  console.log(`📝 Processando mensagem ${isEdit ? "(editada)" : ""} de ${message.from.first_name}`);

  // 1. Verificar/criar identidade do usuário
  const telegramUserId = message.from.id;
  const chatId = message.chat.id;
  
  // Buscar usuário vinculado
  const { data: identity } = await supabase
    .from("telegram_identities")
    .select("user_id")
    .eq("telegram_user_id", telegramUserId)
    .single();

  if (!identity) {
    console.warn(`⚠️ Usuário Telegram ${telegramUserId} não vinculado ao sistema`);
    // Enviar mensagem instruindo vincular conta
    await sendTelegramMessage(
      chatId,
      "⚠️ Sua conta Telegram ainda não está vinculada ao TaskFlow.\n\n" +
      "Use o comando /vincular no app para conectar sua conta.",
      message.message_thread_id
    );
    return;
  }

  // Atualizar last_active e last_chat_id
  await supabase
    .from("telegram_identities")
    .update({
      last_active_at: new Date().toISOString(),
      last_chat_id: chatId,
    })
    .eq("telegram_user_id", telegramUserId);

  // 2. Identificar thread (comunidade ou tarefa)
  const { threadType, threadId, grupoId } = await identifyThread(
    chatId,
    message.message_thread_id,
    identity.user_id
  );

  if (!threadId || !grupoId) {
    console.warn("⚠️ Não foi possível identificar o thread da mensagem");
    await sendTelegramMessage(
      chatId,
      "⚠️ Não foi possível identificar o contexto desta conversa.\n" +
      "Certifique-se de que o chat está configurado corretamente.",
      message.message_thread_id
    );
    return;
  }

  // 3. Extrair conteúdo da mensagem
  const { conteudo, tipo, arquivoUrl, localizacao } = await extractMessageContent(message);

  // 4. Buscar nome do usuário do sistema
  const { data: usuario } = await supabase
    .from("usuarios")
    .select("nome")
    .eq("id", identity.user_id)
    .single();

  const usuarioNome = usuario?.nome || message.from.first_name;

  // 5. Inserir mensagem no banco (ou atualizar se for edição)
  const telegramMetadata = {
    chat_id: chatId,
    message_id: message.message_id,
    from_id: message.from.id,
    username: message.from.username,
    first_name: message.from.first_name,
    last_name: message.from.last_name,
    topic_id: message.message_thread_id,
    is_edit: isEdit,
  };

  if (isEdit) {
    // Buscar mensagem existente pelo telegram_message_id
    const { data: existingMsg } = await supabase
      .from("mensagens")
      .select("id")
      .eq("telegram_metadata->message_id", message.message_id)
      .eq("telegram_metadata->chat_id", chatId)
      .single();

    if (existingMsg) {
      await supabase
        .from("mensagens")
        .update({
          conteudo,
          updated_at: new Date().toISOString(),
          telegram_metadata: telegramMetadata,
        })
        .eq("id", existingMsg.id);
      
      console.log(`✅ Mensagem ${existingMsg.id} atualizada`);
    }
  } else {
    // Nova mensagem
    const { data: novaMensagem, error } = await supabase
      .from("mensagens")
      .insert({
        grupo_id: grupoId,
        usuario_id: identity.user_id,
        usuario_nome: usuarioNome,
        conteudo,
        tipo,
        arquivo_url: arquivoUrl,
        localizacao,
        source: "telegram",
        telegram_metadata: telegramMetadata,
      })
      .select()
      .single();

    if (error) {
      console.error("❌ Erro ao inserir mensagem:", error);
      throw error;
    }

    console.log(`✅ Mensagem ${novaMensagem.id} inserida no grupo ${grupoId}`);

    // Atualizar updated_at do grupo
    await supabase
      .from("grupos_chat")
      .update({ updated_at: new Date().toISOString() })
      .eq("id", grupoId);
  }
}

async function identifyThread(
  chatId: number,
  topicId: number | undefined,
  userId: string
): Promise<{ threadType: string; threadId: string | null; grupoId: string | null }> {
  // Buscar subscription que corresponde ao chat/topic
  let query = supabase
    .from("telegram_subscriptions")
    .select("thread_type, thread_id")
    .eq("telegram_chat_id", chatId)
    .eq("active", true);

  if (topicId) {
    query = query.eq("telegram_topic_id", topicId);
  } else {
    query = query.is("telegram_topic_id", null);
  }

  const { data: subscriptions } = await query;

  if (!subscriptions || subscriptions.length === 0) {
    // Se não encontrou, tentar usar contexto do usuário (último grupo acessado)
    // Por enquanto, retornar null
    return { threadType: "", threadId: null, grupoId: null };
  }

  const subscription = subscriptions[0];
  
  if (subscription.thread_type === "TASK") {
    // thread_id é o ID do grupo_chat
    return {
      threadType: "TASK",
      threadId: subscription.thread_id,
      grupoId: subscription.thread_id,
    };
  } else if (subscription.thread_type === "COMMUNITY") {
    // Para COMMUNITY, precisamos de um grupo específico
    // Por enquanto, retornar o primeiro grupo da comunidade
    const { data: grupos } = await supabase
      .from("grupos_chat")
      .select("id")
      .eq("comunidade_id", subscription.thread_id)
      .limit(1);

    if (grupos && grupos.length > 0) {
      return {
        threadType: "COMMUNITY",
        threadId: subscription.thread_id,
        grupoId: grupos[0].id,
      };
    }
  }

  return { threadType: "", threadId: null, grupoId: null };
}

async function extractMessageContent(message: TelegramMessage): Promise<{
  conteudo: string;
  tipo: string;
  arquivoUrl: string | null;
  localizacao: any | null;
}> {
  let conteudo = message.text || message.caption || "";
  let tipo = "texto";
  let arquivoUrl: string | null = null;
  let localizacao: any | null = null;

  // Localização
  if (message.location) {
    tipo = "localizacao";
    localizacao = {
      lat: message.location.latitude,
      lng: message.location.longitude,
      endereco: `${message.location.latitude}, ${message.location.longitude}`,
    };
    conteudo = "📍 Localização";
  }

  // Foto
  if (message.photo && message.photo.length > 0) {
    tipo = "imagem";
    const photo = message.photo[message.photo.length - 1]; // Maior resolução
    arquivoUrl = await getTelegramFileUrl(photo.file_id);
    if (!conteudo) conteudo = "📷 Foto";
  }

  // Vídeo
  if (message.video) {
    tipo = "video";
    arquivoUrl = await getTelegramFileUrl(message.video.file_id);
    if (!conteudo) conteudo = "🎥 Vídeo";
  }

  // Documento
  if (message.document) {
    tipo = "documento";
    arquivoUrl = await getTelegramFileUrl(message.document.file_id);
    if (!conteudo) conteudo = message.document.file_name || "📎 Documento";
  }

  // Áudio
  if (message.audio || message.voice) {
    tipo = "audio";
    const fileId = message.audio?.file_id || message.voice?.file_id;
    arquivoUrl = await getTelegramFileUrl(fileId!);
    if (!conteudo) conteudo = "🎤 Áudio";
  }

  return { conteudo, tipo, arquivoUrl, localizacao };
}

async function getTelegramFileUrl(fileId: string): Promise<string> {
  try {
    const response = await fetch(
      `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getFile?file_id=${fileId}`
    );
    const data = await response.json();
    
    if (data.ok && data.result.file_path) {
      return `https://api.telegram.org/file/bot${TELEGRAM_BOT_TOKEN}/${data.result.file_path}`;
    }
  } catch (error) {
    console.error("❌ Erro ao obter URL do arquivo:", error);
  }
  return "";
}

async function processCallbackQuery(callbackQuery: any) {
  console.log("🔘 Processando callback query:", callbackQuery.data);
  
  // TODO: Implementar ações de botões (ex: marcar tarefa como concluída)
  // Por enquanto, apenas confirmar recebimento
  
  await fetch(
    `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/answerCallbackQuery`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        callback_query_id: callbackQuery.id,
        text: "Ação registrada!",
      }),
    }
  );
}

async function sendTelegramMessage(
  chatId: number,
  text: string,
  topicId?: number
) {
  const payload: any = {
    chat_id: chatId,
    text,
    parse_mode: "HTML",
  };

  if (topicId) {
    payload.message_thread_id = topicId;
  }

  await fetch(
    `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    }
  );
}
