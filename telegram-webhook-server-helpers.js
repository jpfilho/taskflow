// ============================================
// FUNÇÕES AUXILIARES GENERALIZADAS
// ============================================

/**
 * Garante que uma tarefa tem um tópico no Telegram
 * Cria o tópico automaticamente se não existir
 * @param {string} taskId - ID da tarefa (tasks.id)
 * @returns {Promise<{telegram_chat_id: number, telegram_topic_id: number, topic_name: string} | null>}
 */
async function ensureTaskTopic(taskId) {
  try {
    console.log(`🔍 Verificando tópico para tarefa: ${taskId}`);

    // 1. Verificar se já existe tópico
    const { data: existingTopic } = await supabase
      .from('telegram_task_topics')
      .select('*')
      .eq('task_id', taskId)
      .maybeSingle();

    if (existingTopic) {
      console.log(`✅ Tópico já existe: chat=${existingTopic.telegram_chat_id}, topic=${existingTopic.telegram_topic_id}`);
      return {
        telegram_chat_id: existingTopic.telegram_chat_id,
        telegram_topic_id: existingTopic.telegram_topic_id,
        topic_name: existingTopic.topic_name,
      };
    }

    // 2. Buscar grupo_chat e comunidade da tarefa
    const { data: grupoChat } = await supabase
      .from('grupos_chat')
      .select('id, tarefa_id, tarefa_nome, comunidade_id')
      .eq('tarefa_id', taskId)
      .maybeSingle();

    if (!grupoChat) {
      console.warn(`⚠️ Grupo de chat não encontrado para tarefa ${taskId}`);
      return null;
    }

    // 3. Buscar supergrupo Telegram da comunidade
    const { data: telegramCommunity } = await supabase
      .from('telegram_communities')
      .select('telegram_chat_id')
      .eq('community_id', grupoChat.comunidade_id)
      .maybeSingle();

    if (!telegramCommunity) {
      console.warn(`⚠️ Supergrupo Telegram não configurado para comunidade ${grupoChat.comunidade_id}`);
      return null; // Community não tem supergrupo configurado ainda
    }

    const telegramChatId = telegramCommunity.telegram_chat_id;

    // 4. Criar tópico no Telegram
    const topicName = grupoChat.tarefa_nome || `Tarefa ${taskId.substring(0, 8)}`;
    
    console.log(`📝 Criando tópico "${topicName}" no supergrupo ${telegramChatId}...`);
    
    const createTopicResponse = await fetch(
      `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/createForumTopic`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          chat_id: telegramChatId,
          name: topicName,
        }),
      }
    );

    const topicData = await createTopicResponse.json();

    if (!topicData.ok) {
      console.error(`❌ Erro ao criar tópico:`, topicData);
      return null;
    }

    const telegramTopicId = topicData.result.message_thread_id;

    console.log(`✅ Tópico criado: chat=${telegramChatId}, topic=${telegramTopicId}`);

    // 5. Salvar mapeamento no banco
    const { data: newTopic, error: insertError } = await supabase
      .from('telegram_task_topics')
      .insert({
        task_id: taskId,
        grupo_chat_id: grupoChat.id,
        community_id: grupoChat.comunidade_id,
        telegram_chat_id: telegramChatId,
        telegram_topic_id: telegramTopicId,
        topic_name: topicName,
      })
      .select()
      .single();

    if (insertError) {
      console.error(`❌ Erro ao salvar tópico no banco:`, insertError);
      return null;
    }

    return {
      telegram_chat_id: telegramChatId,
      telegram_topic_id: telegramTopicId,
      topic_name: topicName,
    };
  } catch (error) {
    console.error(`❌ Erro em ensureTaskTopic:`, error);
    return null;
  }
}

/**
 * Identifica a tarefa a partir de um tópico do Telegram
 * @param {number} chatId - ID do supergrupo
 * @param {number} topicId - ID do tópico (message_thread_id)
 * @returns {Promise<{task_id: string, grupo_chat_id: string} | null>}
 */
async function identifyTaskFromTopic(chatId, topicId) {
  try {
    const { data: topic } = await supabase
      .from('telegram_task_topics')
      .select('task_id, grupo_chat_id')
      .eq('telegram_chat_id', chatId)
      .eq('telegram_topic_id', topicId)
      .maybeSingle();

    if (!topic) {
      return null;
    }

    return {
      task_id: topic.task_id,
      grupo_chat_id: topic.grupo_chat_id,
    };
  } catch (error) {
    console.error('❌ Erro ao identificar tarefa do tópico:', error);
    return null;
  }
}

/**
 * Obtém o tópico Telegram de uma tarefa
 * @param {string} taskId - ID da tarefa
 * @returns {Promise<{telegram_chat_id: number, telegram_topic_id: number} | null>}
 */
async function getTaskTopic(taskId) {
  try {
    const { data: topic } = await supabase
      .from('telegram_task_topics')
      .select('telegram_chat_id, telegram_topic_id')
      .eq('task_id', taskId)
      .maybeSingle();

    if (!topic) {
      return null;
    }

    return {
      telegram_chat_id: topic.telegram_chat_id,
      telegram_topic_id: topic.telegram_topic_id,
    };
  } catch (error) {
    console.error('❌ Erro ao obter tópico da tarefa:', error);
    return null;
  }
}
