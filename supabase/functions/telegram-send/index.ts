// =========================================
// TELEGRAM SEND - EDGE FUNCTION
// =========================================
// Envia mensagens do Supabase para o Telegram
// Deploy: supabase functions deploy telegram-send

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const TELEGRAM_BOT_TOKEN = Deno.env.get("TELEGRAM_BOT_TOKEN")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

interface SendRequest {
  mensagem_id: string;
  thread_type?: string; // TASK ou COMMUNITY
  thread_id?: string;
}

serve(async (req: Request) => {
  try {
    const { mensagem_id, thread_type, thread_id }: SendRequest = await req.json();

    if (!mensagem_id) {
      return new Response(
        JSON.stringify({ error: "mensagem_id é obrigatório" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    console.log(`📤 Enviando mensagem ${mensagem_id} para Telegram`);

    // 1. Buscar mensagem
    const { data: mensagem, error: msgError } = await supabase
      .from("mensagens")
      .select("*")
      .eq("id", mensagem_id)
      .single();

    if (msgError || !mensagem) {
      throw new Error(`Mensagem não encontrada: ${msgError?.message}`);
    }

    // Ignorar mensagens que vieram do Telegram (evitar loop)
    if (mensagem.source === "telegram") {
      console.log("⏭️ Mensagem veio do Telegram, ignorando");
      return new Response(
        JSON.stringify({ ok: true, skipped: true, reason: "source=telegram" }),
        { headers: { "Content-Type": "application/json" } }
      );
    }

    // 2. Identificar thread_type e thread_id se não fornecidos
    let actualThreadType = thread_type;
    let actualThreadId = thread_id;

    if (!actualThreadType || !actualThreadId) {
      // Buscar grupo da mensagem
      const { data: grupo } = await supabase
        .from("grupos_chat")
        .select("id, comunidade_id")
        .eq("id", mensagem.grupo_id)
        .single();

      if (grupo) {
        actualThreadType = "TASK";
        actualThreadId = grupo.id;
      }
    }

    if (!actualThreadType || !actualThreadId) {
      throw new Error("Não foi possível identificar thread_type e thread_id");
    }

    // 3. Buscar subscriptions ativas para este thread
    const { data: subscriptions } = await supabase
      .from("telegram_subscriptions")
      .select("*")
      .eq("thread_type", actualThreadType)
      .eq("thread_id", actualThreadId)
      .eq("active", true);

    if (!subscriptions || subscriptions.length === 0) {
      console.log("⏭️ Nenhuma subscription ativa para este thread");
      return new Response(
        JSON.stringify({ ok: true, skipped: true, reason: "no_subscriptions" }),
        { headers: { "Content-Type": "application/json" } }
      );
    }

    console.log(`📡 Encontradas ${subscriptions.length} subscription(s) ativa(s)`);

    // 4. Enviar para cada subscription
    const results = [];
    for (const subscription of subscriptions) {
      try {
        const result = await sendToTelegram(mensagem, subscription);
        results.push(result);

        // Registrar log de entrega
        await supabase.from("telegram_delivery_logs").insert({
          mensagem_id: mensagem.id,
          subscription_id: subscription.id,
          status: result.success ? "sent" : "failed",
          telegram_chat_id: subscription.telegram_chat_id,
          telegram_message_id: result.telegram_message_id,
          telegram_topic_id: subscription.telegram_topic_id,
          error_message: result.error,
          sent_at: result.success ? new Date().toISOString() : null,
          failed_at: result.success ? null : new Date().toISOString(),
          response_payload: result.response,
        });
      } catch (error) {
        console.error(`❌ Erro ao enviar para subscription ${subscription.id}:`, error);
        results.push({
          subscription_id: subscription.id,
          success: false,
          error: error.message,
        });
      }
    }

    const successCount = results.filter((r) => r.success).length;
    console.log(`✅ Enviado com sucesso para ${successCount}/${results.length} destino(s)`);

    return new Response(
      JSON.stringify({
        ok: true,
        mensagem_id,
        sent_count: successCount,
        total_count: results.length,
        results,
      }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("❌ Erro ao processar envio:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});

async function sendToTelegram(mensagem: any, subscription: any) {
  const chatId = subscription.telegram_chat_id;
  const topicId = subscription.telegram_topic_id;
  const settings = subscription.settings || {};

  // Montar texto da mensagem
  let text = `<b>${mensagem.usuario_nome || "Usuário"}:</b>\n${mensagem.conteudo}`;

  // Limitar tamanho (Telegram tem limite de 4096 caracteres)
  if (text.length > 4000) {
    text = text.substring(0, 3997) + "...";
  }

  const payload: any = {
    chat_id: chatId,
    parse_mode: "HTML",
  };

  if (topicId) {
    payload.message_thread_id = topicId;
  }

  let response: any = null;
  let telegramMessageId: number | null = null;

  try {
    // Verificar tipo de mensagem
    const tipo = mensagem.tipo || "texto";

    if (tipo === "texto" || !mensagem.arquivo_url) {
      // Mensagem de texto simples
      payload.text = text;
      response = await fetch(
        `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        }
      );
    } else if (tipo === "imagem" && settings.send_attachments !== false) {
      // Enviar foto
      payload.photo = mensagem.arquivo_url;
      payload.caption = mensagem.conteudo || "";
      response = await fetch(
        `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendPhoto`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        }
      );
    } else if (tipo === "video" && settings.send_attachments !== false) {
      // Enviar vídeo
      payload.video = mensagem.arquivo_url;
      payload.caption = mensagem.conteudo || "";
      response = await fetch(
        `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendVideo`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        }
      );
    } else if (tipo === "audio" && settings.send_attachments !== false) {
      // Enviar áudio
      payload.audio = mensagem.arquivo_url;
      payload.caption = mensagem.conteudo || "";
      response = await fetch(
        `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendAudio`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        }
      );
    } else if (tipo === "documento" && settings.send_attachments !== false) {
      // Enviar documento
      payload.document = mensagem.arquivo_url;
      payload.caption = mensagem.conteudo || "";
      response = await fetch(
        `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        }
      );
    } else if (tipo === "localizacao" && settings.send_locations !== false) {
      // Enviar localização
      const loc = mensagem.localizacao;
      if (loc && loc.lat && loc.lng) {
        payload.latitude = loc.lat;
        payload.longitude = loc.lng;
        response = await fetch(
          `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendLocation`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(payload),
          }
        );
      } else {
        // Fallback: enviar como texto
        payload.text = text;
        response = await fetch(
          `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(payload),
          }
        );
      }
    } else {
      // Fallback: enviar como texto
      payload.text = text;
      response = await fetch(
        `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        }
      );
    }

    const data = await response.json();

    if (!data.ok) {
      throw new Error(`Telegram API error: ${data.description}`);
    }

    telegramMessageId = data.result?.message_id;

    // Atualizar mensagem com telegram_metadata (para futura edição/referência)
    if (telegramMessageId) {
      const updatedMetadata = {
        ...(mensagem.telegram_metadata || {}),
        sent_to: [
          ...((mensagem.telegram_metadata?.sent_to || [])),
          {
            chat_id: chatId,
            message_id: telegramMessageId,
            topic_id: topicId,
            sent_at: new Date().toISOString(),
          },
        ],
      };

      await supabase
        .from("mensagens")
        .update({ telegram_metadata: updatedMetadata })
        .eq("id", mensagem.id);
    }

    return {
      subscription_id: subscription.id,
      success: true,
      telegram_message_id: telegramMessageId,
      response: data,
    };
  } catch (error) {
    console.error(`❌ Erro ao enviar para Telegram (chat ${chatId}):`, error);
    return {
      subscription_id: subscription.id,
      success: false,
      error: error.message,
      response: null,
    };
  }
}
