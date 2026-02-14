const express = require('express');
const { createClient } = require('@supabase/supabase-js');
const { Pool } = require('pg');
const FormData = require('form-data');
const axios = require('axios');
const cron = require('node-cron');
const geo = require('./geo_ingestors');

// ==========================================
// CONFIGURAÇÃO
// ==========================================

const PORT = process.env.PORT || 3001;
const TELEGRAM_BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN || '8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec';
const TELEGRAM_WEBHOOK_SECRET = process.env.TELEGRAM_WEBHOOK_SECRET || 'TgWebhook2026Taskflow_Secret';
const GEO_JOB_TOKEN = process.env.GEO_JOB_TOKEN || process.env.ADMIN_TOKEN || 'GeoJobToken';
const GEO_BUFFER_M = Number(process.env.GEO_BUFFER_M || 50);
const GEO_WINDOW_DAYS_DEFAULT = Number(process.env.GEO_WINDOW_DAYS || 7);
const GEO_RAIOS_WINDOW_DAYS = Number(process.env.GEO_RAIOS_WINDOW_DAYS || 1); // descargas recentes
const GEO_CRON_EXPR = process.env.GEO_CRON_EXPR || '15 * * * *'; // a cada hora no minuto 15

// IMPORTANTE: Usar IP público ou domínio público para URLs assinadas
// O Telegram precisa acessar essas URLs externamente
const SUPABASE_URL_INTERNAL = process.env.SUPABASE_URL_INTERNAL || 'http://127.0.0.1:8000'; // Para comunicação interna
const SUPABASE_URL_PUBLIC = process.env.SUPABASE_URL_PUBLIC || 'http://212.85.0.249:8000'; // Para URLs enviadas ao Telegram
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjU4MTc5ODMsImV4cCI6MjA4MTE3Nzk4M30.MYcuHsPkBgYg_M1WVHKbtO3MQYalYNYOppr0Q3ynUgw';
const APP_TRECHO_DEEPLINK = process.env.APP_TRECHO_DEEPLINK || process.env.APP_WEB_URL || '';

// Cliente Supabase (usa URL interna para comunicação)
const supabase = createClient(SUPABASE_URL_INTERNAL, SUPABASE_SERVICE_KEY);

// Pool PostgreSQL para LISTEN/NOTIFY
const DB_CONFIG = {
  host: process.env.DB_HOST || '127.0.0.1',
  port: Number(process.env.DB_PORT || 5433), // conectar direto no Postgres real (supabase-db)
  database: process.env.DB_NAME || 'postgres',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
};

console.log('🔌 Postgres config:', {
  host: DB_CONFIG.host,
  port: DB_CONFIG.port,
  database: DB_CONFIG.database,
  user: DB_CONFIG.user,
});

const pgPool = new Pool(DB_CONFIG);
pgPool.on('error', (err) => {
  console.error('❌ Erro no pool Postgres:', err);
});

// Endpoint de detalhe para um evento de queimada com a feature KMZ mais próxima
app.get('/eventos/queimadas/:id/detalhe', async (req, res) => {
  try {
    const { id } = req.params;

    // Garantir que a view existe
    try {
      await pgPool.query('SELECT 1 FROM vw_kmz_geoms LIMIT 1');
    } catch (e) {
      return res.status(500).json({ ok: false, error: 'vw_kmz_geoms não disponível. Execute a migration.' });
    }

    const sql = `
      WITH evento AS (
        SELECT
          id,
          source,
          acq_time,
          latitude,
          longitude,
          ST_SetSRID(ST_MakePoint(longitude, latitude), 4326) AS geom
        FROM geo_queimadas
        WHERE id = $1
      )
      SELECT
        e.id AS evento_id,
        e.source,
        e.acq_time,
        e.latitude,
        e.longitude,
        k.id AS kmz_feature_id,
        k.nome AS kmz_nome,
        k.is_line,
        ST_Distance(e.geom::geography, k.geom::geography) AS distancia_m
      FROM evento e
      JOIN vw_kmz_geoms k ON TRUE
      WHERE k.geom IS NOT NULL
      ORDER BY e.geom <-> k.geom
      LIMIT 1;
    `;

    const { rows } = await pgPool.query(sql, [id]);
    if (!rows.length) {
      return res.status(404).json({ ok: false, error: 'Evento não encontrado' });
    }

    const r = rows[0];
    res.json({
      ok: true,
      evento: {
        id: r.evento_id,
        fonte: r.source,
        acq_time: r.acq_time,
        latitude: r.latitude,
        longitude: r.longitude,
      },
      mais_proximo: {
        kmz_feature_id: r.kmz_feature_id,
        nome: r.kmz_nome,
        tipo: r.is_line ? 'linha' : 'estrutura',
        distancia_m: r.distancia_m,
      },
    });
  } catch (error) {
    console.error('❌ Erro no detalhe da queimada:', error);
    res.status(500).json({ ok: false, error: error.message });
  }
});

// ==========================================
// EXPRESS APP
// ==========================================

const app = express();

// Middleware CORS - Permitir requisições do Flutter web
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization, x-telegram-bot-api-secret-token');
  
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

// ==========================================
// FUNÇÕES AUXILIARES
// ==========================================

/**
 * Insere log de entrega no banco de forma robusta
 * NOTA: A tabela telegram_delivery_logs NÃO tem coluna task_id, então nunca incluímos esse campo
 */
async function insertDeliveryLog(logData) {
  const { mensagem_id, telegram_chat_id, telegram_topic_id, telegram_message_id, status, error_message, error_code } = logData;
  
  // Construir payload SEM task_id (coluna não existe na tabela)
  const logPayload = {
    mensagem_id,
    telegram_chat_id,
    telegram_topic_id,
    telegram_message_id,
    status,
  };
  
  if (error_message) {
    logPayload.error_message = error_message;
  }
  
  if (error_code) {
    logPayload.error_code = error_code;
  }
  
  try {
    const { data, error } = await supabase
      .from('telegram_delivery_logs')
      .insert(logPayload)
      .select();
    
    if (error) {
      console.error(`❌ [insertDeliveryLog] Erro ao inserir log:`, error);
      return { data: null, error };
    }
    
    return { data, error: null };
  } catch (exception) {
    console.error(`❌ [insertDeliveryLog] Exceção ao inserir log:`, exception);
    return { data: null, error: exception };
  }
}

/**
 * Garante que uma tarefa tem um tópico no Telegram
 */
async function ensureTaskTopic(taskId) {
  try {
    console.log(`🔍 Verificando tópico para tarefa: ${taskId}`);

    // 1. Buscar grupo_chat e comunidade da tarefa PRIMEIRO
    const { data: grupoChat } = await supabase
      .from('grupos_chat')
      .select('id, tarefa_id, tarefa_nome, comunidade_id')
      .eq('tarefa_id', taskId)
      .maybeSingle();

    if (!grupoChat) {
      console.warn(`⚠️ Grupo de chat não encontrado para tarefa ${taskId}`);
      return null;
    }

    // 2. Buscar supergrupo Telegram ATUALIZADO da comunidade
    console.log(`\n🔍 [ensureTaskTopic] ========================================`);
    console.log(`🔍 [ensureTaskTopic] Buscando Chat ID para comunidade: ${grupoChat.comunidade_id}`);
    console.log(`🔍 [ensureTaskTopic] ========================================`);
    
    // DEBUG: Verificar se a comunidade existe e seus dados
    console.log(`🔍 [ensureTaskTopic] DEBUG: Buscando comunidade na tabela 'comunidades'...`);
    console.log(`   - WHERE id = ${grupoChat.comunidade_id}`);
    
    const { data: comunidadeInfo } = await supabase
      .from('comunidades')
      .select('id, regional_id, regional_nome, divisao_id, divisao_nome, segmento_id, segmento_nome')
      .eq('id', grupoChat.comunidade_id)
      .maybeSingle();
    
    if (comunidadeInfo) {
      console.log(`✅ [ensureTaskTopic] DEBUG: Comunidade encontrada na tabela 'comunidades':`);
      console.log(`   - id: ${comunidadeInfo.id}`);
      console.log(`   - regional_id: ${comunidadeInfo.regional_id}`);
      console.log(`   - regional_nome: ${comunidadeInfo.regional_nome}`);
      console.log(`   - divisao_id: ${comunidadeInfo.divisao_id}`);
      console.log(`   - divisao_nome: ${comunidadeInfo.divisao_nome}`);
      console.log(`   - segmento_id: ${comunidadeInfo.segmento_id}`);
      console.log(`   - segmento_nome: ${comunidadeInfo.segmento_nome}`);
      console.log(`   📋 TABELA: comunidades`);
    } else {
      console.warn(`⚠️ [ensureTaskTopic] DEBUG: Comunidade ${grupoChat.comunidade_id} não encontrada na tabela 'comunidades'!`);
    }
    
    // Buscar telegram_chat_id na tabela telegram_communities
    console.log(`🔍 [ensureTaskTopic] DEBUG: Buscando telegram_chat_id na tabela 'telegram_communities'...`);
    console.log(`   - WHERE community_id = ${grupoChat.comunidade_id}`);
    
    const { data: telegramCommunity, error: telegramError } = await supabase
      .from('telegram_communities')
      .select('id, community_id, telegram_chat_id, created_at, updated_at')
      .eq('community_id', grupoChat.comunidade_id)
      .maybeSingle();

    if (telegramError) {
      console.error(`❌ [ensureTaskTopic] DEBUG: Erro ao buscar telegram_communities:`, telegramError);
      return null;
    }

    if (!telegramCommunity) {
      console.warn(`⚠️ [ensureTaskTopic] Supergrupo Telegram não configurado para comunidade ${grupoChat.comunidade_id}`);
      console.warn(`⚠️ [ensureTaskTopic] Verifique se existe um registro em telegram_communities com community_id=${grupoChat.comunidade_id}`);
      console.warn(`⚠️ [ensureTaskTopic] TABELA USADA: telegram_communities`);
      console.warn(`⚠️ [ensureTaskTopic] QUERY: SELECT * FROM telegram_communities WHERE community_id = '${grupoChat.comunidade_id}'`);
      return null;
    }

    const telegramChatId = telegramCommunity.telegram_chat_id;
    console.log(`✅ [ensureTaskTopic] telegram_communities encontrado:`);
    console.log(`   - id: ${telegramCommunity.id}`);
    console.log(`   - community_id: ${telegramCommunity.community_id}`);
    console.log(`   - telegram_chat_id: ${telegramChatId}`);
    console.log(`   - created_at: ${telegramCommunity.created_at}`);
    console.log(`   - updated_at: ${telegramCommunity.updated_at}`);
    console.log(`   📋 TABELA: telegram_communities`);
    console.log(`\n🎯 [ensureTaskTopic] RESULTADO: Usando Telegram Chat ID ${telegramChatId} para comunidade ${grupoChat.comunidade_id}`);
    console.log(`🔍 [ensureTaskTopic] ========================================\n`);

    // 3. Verificar se já existe tópico
    const { data: existingTopic } = await supabase
      .from('telegram_task_topics')
      .select('*')
      .eq('task_id', taskId)
      .maybeSingle();

    // 4. Se existe tópico, verificar se o Chat ID está atualizado
    if (existingTopic) {
      console.log(`🔍 [ensureTaskTopic] Tópico existente encontrado: chat=${existingTopic.telegram_chat_id}, topic=${existingTopic.telegram_topic_id}`);
      console.log(`🔍 [ensureTaskTopic] Comparando Chat IDs: existente=${existingTopic.telegram_chat_id} vs atual=${telegramChatId}`);
      
      // Se o Chat ID mudou, precisamos criar um novo tópico ou atualizar
      if (existingTopic.telegram_chat_id !== telegramChatId) {
        console.log(`⚠️ [ensureTaskTopic] Chat ID mudou! Antigo: ${existingTopic.telegram_chat_id}, Novo: ${telegramChatId}`);
        console.log(`📝 [ensureTaskTopic] Criando novo tópico no grupo correto...`);
        // Não retornar o tópico antigo, continuar para criar novo
      } else {
        // Chat ID está correto, usar tópico existente
        console.log(`✅ [ensureTaskTopic] Tópico já existe e Chat ID está correto: chat=${existingTopic.telegram_chat_id}, topic=${existingTopic.telegram_topic_id}`);
        return {
          telegram_chat_id: existingTopic.telegram_chat_id,
          telegram_topic_id: existingTopic.telegram_topic_id,
          topic_name: existingTopic.topic_name,
        };
      }
    } else {
      console.log(`📝 [ensureTaskTopic] Nenhum tópico existente encontrado, criando novo...`);
    }

    // 5. Criar tópico no Telegram
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

    // 6. Salvar ou atualizar mapeamento no banco
    // Se já existe tópico antigo, atualizar; senão, inserir novo
    if (existingTopic) {
      console.log(`🔄 Atualizando tópico existente com novo Chat ID...`);
      const { data: updatedTopic, error: updateError } = await supabase
        .from('telegram_task_topics')
        .update({
          telegram_chat_id: telegramChatId,
          telegram_topic_id: telegramTopicId,
          topic_name: topicName,
          updated_at: new Date().toISOString(),
        })
        .eq('task_id', taskId)
        .select()
        .single();

      if (updateError) {
        console.error(`❌ Erro ao atualizar tópico no banco:`, updateError);
        return null;
      }

      console.log(`✅ Tópico atualizado com sucesso`);
      return {
        telegram_chat_id: updatedTopic.telegram_chat_id,
        telegram_topic_id: updatedTopic.telegram_topic_id,
        topic_name: updatedTopic.topic_name,
      };
    } else {
      // Inserir novo tópico
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
        telegram_chat_id: newTopic.telegram_chat_id,
        telegram_topic_id: newTopic.telegram_topic_id,
        topic_name: newTopic.topic_name,
      };
    }
  } catch (error) {
    console.error(`❌ Erro em ensureTaskTopic:`, error);
    return null;
  }
}

/**
 * Identifica a tarefa a partir de um tópico do Telegram
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
 * Obtém task_id a partir de grupo_id (grupos_chat.id)
 */
async function getTaskIdFromGrupoId(grupoId) {
  try {
    const { data: grupoChat } = await supabase
      .from('grupos_chat')
      .select('tarefa_id')
      .eq('id', grupoId)
      .maybeSingle();

    if (!grupoChat) {
      return null;
    }

    return grupoChat.tarefa_id;
  } catch (error) {
    console.error('❌ Erro ao obter task_id do grupo:', error);
    return null;
  }
}

/**
 * Cadastra um grupo para uma comunidade específica
 */
async function cadastrarGrupoParaComunidade(chatId, comunidade) {
  try {
    const { data: novoCadastro, error: insertError } = await supabase
      .from('telegram_communities')
      .insert({
        community_id: comunidade.id,
        telegram_chat_id: chatId,
      })
      .select()
      .single();

    if (insertError) {
      console.error(`❌ Erro ao cadastrar grupo:`, insertError);
      await sendTelegramMessage(
        chatId,
        `❌ Erro ao cadastrar grupo. Entre em contato com o administrador.`,
        null
      );
      return false;
    }

    const nomeComunidade = `${comunidade.divisao_nome} - ${comunidade.segmento_nome}`;
    console.log(`✅ Grupo cadastrado para comunidade: ${nomeComunidade}`);

    await sendTelegramMessage(
      chatId,
      `✅ Grupo cadastrado com sucesso!\n\n` +
      `📋 Comunidade: ${nomeComunidade}\n` +
      `💬 Chat ID: ${chatId}\n\n` +
      `⚠️ IMPORTANTE:\n` +
      `1. Certifique-se de que este grupo está configurado como Fórum (Tópicos habilitados)\n` +
      `2. O bot precisa ser administrador com permissão "Manage Topics"\n` +
      `3. Tópicos serão criados automaticamente quando você enviar mensagens de tarefas no Flutter`,
      null
    );

    return true;
  } catch (error) {
    console.error('❌ Erro ao cadastrar grupo:', error);
    return false;
  }
}

/**
 * Detecta quando o bot é adicionado a um novo grupo e tenta cadastrar automaticamente
 * fazendo match pelo nome do grupo com o nome da comunidade
 */
async function handleBotAddedToGroup(message) {
  try {
    const chatId = message.chat.id;
    const chatTitle = message.chat.title || 'Grupo sem nome';
    const chatType = message.chat.type;

    console.log(`🤖 Bot adicionado ao grupo: ${chatTitle} (${chatId}, tipo: ${chatType})`);

    // Verificar se é supergrupo
    if (chatType !== 'supergroup') {
      console.log(`⚠️ Grupo não é supergrupo ainda. Aguardando conversão...`);
      await sendTelegramMessage(
        chatId,
        `👋 Olá! Para usar este grupo com o TaskFlow:\n\n` +
        `⚠️ Este grupo precisa ser configurado:\n\n` +
        `1️⃣ Converta para Supergrupo:\n` +
        `   Configurações → Converter para Supergrupo\n\n` +
        `2️⃣ Habilite Tópicos (Fórum):\n` +
        `   Configurações → Tipo → Fórum\n\n` +
        `3️⃣ Torne o bot administrador:\n` +
        `   Adicione @TaskFlow_chat_bot como admin\n` +
        `   Dê permissão "Manage Topics"\n\n` +
        `Depois disso, envie uma mensagem aqui e o grupo será cadastrado automaticamente!`,
        null
      );
      return;
    }

    // Verificar se tem tópicos habilitados (is_forum)
    const isForum = message.chat.is_forum === true;
    if (!isForum) {
      console.log(`⚠️ Supergrupo não tem tópicos habilitados ainda.`);
      await sendTelegramMessage(
        chatId,
        `⚠️ Este supergrupo precisa ter Tópicos habilitados:\n\n` +
        `1. Vá em Configurações do Grupo\n` +
        `2. Tipo → Fórum\n` +
        `3. Ative os tópicos\n\n` +
        `Depois disso, envie uma mensagem aqui e o grupo será cadastrado automaticamente!`,
        null
      );
      return;
    }

    // Verificar se já está cadastrado
    const { data: existing } = await supabase
      .from('telegram_communities')
      .select('id, community_id')
      .eq('telegram_chat_id', chatId)
      .maybeSingle();

    if (existing) {
      console.log(`✅ Grupo já está cadastrado para comunidade ${existing.community_id}`);
      await sendTelegramMessage(
        chatId,
        `✅ Este grupo já está cadastrado no TaskFlow!`,
        null
      );
      return;
    }

    // Buscar todas as comunidades
    const { data: todasComunidades } = await supabase
      .from('comunidades')
      .select('id, divisao_nome, segmento_nome')
      .order('divisao_nome', { ascending: true });

    if (!todasComunidades || todasComunidades.length === 0) {
      console.log(`⚠️ Nenhuma comunidade encontrada no banco`);
      await sendTelegramMessage(
        chatId,
        `⚠️ Nenhuma comunidade encontrada no sistema. Entre em contato com o administrador.`,
        null
      );
      return;
    }

    // Buscar comunidades que já têm grupo
    const { data: comunidadesComGrupo } = await supabase
      .from('telegram_communities')
      .select('community_id');

    const idsComGrupo = new Set();
    if (comunidadesComGrupo) {
      comunidadesComGrupo.forEach(tc => idsComGrupo.add(tc.community_id));
    }

    // Filtrar comunidades sem grupo
    const comunidadesSemGrupo = todasComunidades.filter(c => !idsComGrupo.has(c.id));

    if (comunidadesSemGrupo.length === 0) {
      console.log(`⚠️ Todas as comunidades já têm grupo cadastrado`);
      await sendTelegramMessage(
        chatId,
        `⚠️ Todas as comunidades já têm grupo cadastrado.\n\n` +
        `Se você quer cadastrar este grupo manualmente, use o script:\n` +
        `.\cadastrar_grupo_comunidade.ps1`,
        null
      );
      return;
    }

    // Tentar fazer match pelo nome do grupo (padrão: DIVISÃO - SEGMENTO)
    const nomeGrupoLower = chatTitle.toLowerCase().trim();
    let comunidadeMatch = null;
    let matches = [];

    // Extrair divisão e segmento do nome do grupo (formato: "DIVISÃO - SEGMENTO")
    const partesNome = chatTitle.split(' - ').map(p => p.trim());
    const divisaoGrupo = partesNome.length > 0 ? partesNome[0].toLowerCase() : '';
    const segmentoGrupo = partesNome.length > 1 ? partesNome[1].toLowerCase() : '';

    console.log(`🔍 Analisando nome do grupo: "${chatTitle}"`);
    console.log(`   Divisão extraída: "${divisaoGrupo}"`);
    console.log(`   Segmento extraído: "${segmentoGrupo}"`);

    for (const comunidade of comunidadesSemGrupo) {
      const nomeComunidade = `${comunidade.divisao_nome} - ${comunidade.segmento_nome}`;
      const nomeComunidadeLower = nomeComunidade.toLowerCase();
      const divisaoComunidade = comunidade.divisao_nome.toLowerCase();
      const segmentoComunidade = comunidade.segmento_nome.toLowerCase();
      
      // Match exato (case insensitive)
      if (nomeGrupoLower === nomeComunidadeLower) {
        console.log(`✅ Match exato encontrado: ${nomeComunidade}`);
        comunidadeMatch = comunidade;
        break;
      }
      
      // Match por divisão E segmento (padrão "DIVISÃO - SEGMENTO")
      if (divisaoGrupo && segmentoGrupo) {
        if (divisaoGrupo === divisaoComunidade && segmentoGrupo === segmentoComunidade) {
          console.log(`✅ Match por divisão e segmento: ${nomeComunidade}`);
          comunidadeMatch = comunidade;
          break;
        }
      }
      
      // Match parcial (nome do grupo contém divisão ou segmento)
      if (nomeGrupoLower.includes(divisaoComunidade) ||
          nomeGrupoLower.includes(segmentoComunidade) ||
          nomeComunidadeLower.includes(nomeGrupoLower)) {
        console.log(`🔍 Match parcial encontrado: ${nomeComunidade}`);
        matches.push(comunidade);
      }
    }

    // Se encontrou match exato, usar ele
    if (comunidadeMatch) {
      await cadastrarGrupoParaComunidade(chatId, comunidadeMatch);
      return;
    }

    // Se encontrou apenas um match parcial, usar ele
    if (matches.length === 1) {
      console.log(`✅ Match parcial encontrado: ${matches[0].divisao_nome} - ${matches[0].segmento_nome}`);
      await cadastrarGrupoParaComunidade(chatId, matches[0]);
      return;
    }

    // Se não encontrou match ou encontrou múltiplos, listar opções
    console.log(`⚠️ Não foi possível identificar a comunidade automaticamente. Nome do grupo: "${chatTitle}"`);
    
    let mensagem = `⚠️ Não foi possível identificar automaticamente qual comunidade corresponde a este grupo.\n\n`;
    mensagem += `📋 Nome do grupo: "${chatTitle}"\n\n`;
    mensagem += `📝 Comunidades disponíveis (sem grupo):\n\n`;

    comunidadesSemGrupo.forEach((c, index) => {
      const nomeComunidade = `${c.divisao_nome} - ${c.segmento_nome}`;
      mensagem += `${index + 1}. ${nomeComunidade}\n`;
      mensagem += `   ID: ${c.id}\n\n`;
    });

    mensagem += `🔧 Para associar este grupo a uma comunidade, use o comando:\n`;
    mensagem += `/associar <ID_DA_COMUNIDADE>\n\n`;
    mensagem += `Exemplo: /associar ${comunidadesSemGrupo[0].id}`;

    await sendTelegramMessage(chatId, mensagem, null);

  } catch (error) {
    console.error('❌ Erro ao processar bot adicionado ao grupo:', error);
  }
}

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
    return data.ok;
  } catch (error) {
    console.error('❌ Erro ao enviar mensagem:', error);
    return false;
  }
}

// ==========================================
// ROUTES
// ==========================================

// Health check
app.get('/', (req, res) => {
  res.json({ 
    status: 'ok', 
    service: 'TaskFlow Telegram Webhook (Generalized)',
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

    // Processar deleção de mensagem (se houver)
    // NOTA: Bot API não recebe updates quando mensagens são deletadas manualmente pelo usuário
    // Mas podemos processar se o bot receber algum evento relacionado
    if (update.message && update.message.delete_chat_photo) {
      console.log('📷 Foto do chat deletada (não processamos)');
    }
    
    // Processar mensagem
    if (update.message) {
      // Verificar se o bot foi adicionado a um novo grupo
      if (update.message.new_chat_members && Array.isArray(update.message.new_chat_members)) {
        const botId = parseInt(TELEGRAM_BOT_TOKEN.split(':')[0]);
        console.log(`🔍 Verificando new_chat_members. Bot ID: ${botId}, Membros:`, update.message.new_chat_members.map(m => `${m.id} (${m.first_name})`).join(', '));
        
        const botWasAdded = update.message.new_chat_members.some(
          member => member.id === botId
        );
        
        if (botWasAdded) {
          console.log(`🤖 Bot detectado como novo membro do grupo: ${update.message.chat.title || 'Sem nome'} (${update.message.chat.id})`);
          await handleBotAddedToGroup(update.message);
          // Não processar a mensagem de "bot adicionado" como mensagem normal
          return res.json({ ok: true });
        }
      }
      
      // Verificar também new_chat_member (singular, formato antigo)
      if (update.message.new_chat_member) {
        const botId = parseInt(TELEGRAM_BOT_TOKEN.split(':')[0]);
        if (update.message.new_chat_member.id === botId) {
          console.log(`🤖 Bot detectado via new_chat_member (formato antigo): ${update.message.chat.title || 'Sem nome'} (${update.message.chat.id})`);
          await handleBotAddedToGroup(update.message);
          return res.json({ ok: true });
        }
      }
      // Verificar se é criação de grupo
      if (update.message.group_chat_created) {
        await handleBotAddedToGroup(update.message);
      }
      
      // IMPORTANTE: Se for uma mensagem em um supergrupo com tópicos e o grupo ainda não está cadastrado,
      // tentar cadastrar automaticamente (para grupos criados antes do bot ser atualizado ou quando o bot já estava no grupo)
      if (update.message.chat && 
          update.message.chat.type === 'supergroup') {
        // Verificar se o grupo está cadastrado
        const { data: existingGroup } = await supabase
          .from('telegram_communities')
          .select('id')
          .eq('telegram_chat_id', update.message.chat.id)
          .maybeSingle();
        
        if (!existingGroup) {
          console.log(`🔍 Supergrupo não cadastrado detectado! Nome: "${update.message.chat.title}", Chat ID: ${update.message.chat.id}, is_forum: ${update.message.chat.is_forum}`);
          
          // Se tem tópicos habilitados, tentar cadastrar automaticamente
          if (update.message.chat.is_forum === true) {
            console.log(`📝 Tentando cadastrar automaticamente pelo padrão "DIVISÃO - SEGMENTO"...`);
            await handleBotAddedToGroup(update.message);
          } else {
            // Se não tem tópicos, avisar
            console.log(`⚠️ Supergrupo sem tópicos habilitados. Aguardando configuração...`);
            if (update.message.text && !update.message.text.startsWith('/')) {
              await sendTelegramMessage(
                update.message.chat.id,
                `⚠️ Este supergrupo precisa ter Tópicos habilitados:\n\n` +
                `1. Vá em Configurações do Grupo\n` +
                `2. Tipo → Fórum\n` +
                `3. Ative os tópicos\n\n` +
                `Depois disso, envie uma mensagem aqui e o grupo será cadastrado automaticamente!`,
                null
              );
            }
          }
        }
      }
      
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

// GeoJSON opcional para queimadas
app.get('/eventos/queimadas.geojson', async (req, res) => {
  try {
    const { bbox, sinceMinutes } = req.query;
    const limit = Math.min(Number(req.query.limit) || 500, 1000);
    const minutes = Number(sinceMinutes || GEO_WINDOW_DAYS_DEFAULT * 1440);

    const geomCheck = await pgPool.query(
      `SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'tbl_queimadas_focos' AND column_name = 'geom'
      )`,
    );
    const hasGeom = geomCheck.rows?.[0]?.exists === true;

    const clauses = [];
    const params = [];
    params.push(minutes);
    clauses.push(`acq_time >= now() - ($${params.length} || ' minutes')::interval`);

    if (bbox) {
      const [minLon, minLat, maxLon, maxLat] = bbox.split(',').map(Number);
      if (hasGeom) {
        params.push(minLon, minLat, maxLon, maxLat);
        clauses.push(
          `geom && ST_MakeEnvelope($${params.length - 3}, $${params.length - 2}, $${params.length - 1}, $${params.length}, 4326)::geography`,
        );
      } else {
        params.push(minLon, minLat, maxLon, maxLat);
        clauses.push(
          `(longitude BETWEEN $${params.length - 3} AND $${params.length - 1} AND latitude BETWEEN $${params.length - 2} AND $${params.length})`,
        );
      }
    }

    const where = clauses.length ? `WHERE ${clauses.join(' AND ')}` : '';
    params.push(limit);
    const sql = `
      SELECT id, source, acq_time, latitude, longitude, raw
      FROM tbl_queimadas_focos
      ${where}
      ORDER BY acq_time DESC
      LIMIT $${params.length}
    `;
    const { rows } = await pgPool.query(sql, params);

    const features = rows.map((r) => ({
      type: 'Feature',
      geometry: {
        type: 'Point',
        coordinates: [r.longitude, r.latitude],
      },
      properties: {
        id: r.id,
        source: r.source,
        acq_time: r.acq_time,
        raw: r.raw,
      },
    }));

    res.json({
      type: 'FeatureCollection',
      features,
    });
  } catch (error) {
    console.error('❌ Erro ao listar queimadas GeoJSON:', error);
    res.json({ type: 'FeatureCollection', features: [], error: error.message });
  }
});

// ==========================================
// FUNÇÕES AUXILIARES PARA DELETE BIDIRECIONAL
// ==========================================

/**
 * Deleta uma mensagem em todas as plataformas (DB, Telegram, Storage)
 * Função centralizada para garantir sincronização completa
 * 
 * @param {string} messageId - ID canônico da mensagem (UUID)
 * @param {string} origin - Origem da deleção: 'flutter' | 'telegram' | userId (UUID)
 * @param {Object} options - Opções adicionais
 * @param {boolean} options.softDelete - Se true, faz soft delete (deleted_at). Se false, deleta fisicamente
 * @returns {Promise<{ok: boolean, deleted: boolean, deletedFromTelegram: number, deletedFromStorage: boolean, errors?: Array}>}
 */
async function deleteMessageEverywhere(messageId, origin = 'flutter', options = { softDelete: true }) {
  try {
    console.log(`🗑️ [deleteMessageEverywhere] Iniciando deleção: messageId=${messageId}, origin=${origin}, softDelete=${options.softDelete}`);
    
    // 1. Buscar mensagem no banco
    const { data: mensagem, error: msgError } = await supabase
      .from('mensagens')
      .select('id, grupo_id, usuario_id, arquivo_url, storage_path, deleted_at, source')
      .eq('id', messageId)
      .maybeSingle();
    
    if (msgError) {
      console.error(`❌ [deleteMessageEverywhere] Erro ao buscar mensagem:`, msgError);
      throw new Error(`Erro ao buscar mensagem: ${msgError.message}`);
    }
    
    if (!mensagem) {
      console.warn(`⚠️ [deleteMessageEverywhere] Mensagem ${messageId} não encontrada`);
      return {
        ok: true,
        deleted: false,
        deletedFromTelegram: 0,
        deletedFromStorage: false,
        reason: 'Message not found',
      };
    }
    
    if (mensagem.deleted_at) {
      console.warn(`⚠️ [deleteMessageEverywhere] Mensagem ${messageId} já foi deletada em ${mensagem.deleted_at}`);
      return {
        ok: true,
        deleted: false,
        deletedFromTelegram: 0,
        deletedFromStorage: false,
        reason: 'Already deleted',
      };
    }
    
    // 2. Buscar deliveries do Telegram
    // Primeiro tentar buscar logs com status 'sent'
    let { data: deliveryLogs, error: logsError } = await supabase
      .from('telegram_delivery_logs')
      .select('id, telegram_chat_id, telegram_topic_id, telegram_message_id, status')
      .eq('mensagem_id', messageId)
      .eq('status', 'sent');
    
    // Se não encontrar logs 'sent', buscar qualquer log (pode ter sido criado com outro status)
    if (!deliveryLogs || deliveryLogs.length === 0) {
      console.log(`📋 [deleteMessageEverywhere] Nenhum log 'sent' encontrado, buscando qualquer log...`);
      const { data: allLogs, error: allLogsError } = await supabase
        .from('telegram_delivery_logs')
        .select('id, telegram_chat_id, telegram_topic_id, telegram_message_id, status')
        .eq('mensagem_id', messageId);
      
      if (!allLogsError && allLogs && allLogs.length > 0) {
        // Filtrar apenas logs que têm telegram_message_id (necessário para deletar)
        deliveryLogs = allLogs.filter(log => log.telegram_message_id != null);
        console.log(`📋 [deleteMessageEverywhere] Encontrados ${deliveryLogs.length} log(s) com telegram_message_id`);
      }
    }
    
    if (logsError) {
      console.error(`❌ [deleteMessageEverywhere] Erro ao buscar delivery logs:`, logsError);
      // Continuar mesmo com erro, pois pode não ter delivery Telegram
    }
    
    const telegramLogs = deliveryLogs || [];
    console.log(`📋 [deleteMessageEverywhere] Encontrados ${telegramLogs.length} log(s) de entrega Telegram`);
    
    // Log detalhado para diagnóstico
    if (telegramLogs.length > 0) {
      telegramLogs.forEach((log, idx) => {
        console.log(`   Log ${idx + 1}: chat=${log.telegram_chat_id}, message_id=${log.telegram_message_id}, status=${log.status}`);
      });
    } else {
      // Tentar buscar qualquer log para diagnóstico
      const { data: anyLogs } = await supabase
        .from('telegram_delivery_logs')
        .select('id, status, telegram_message_id, error_message')
        .eq('mensagem_id', messageId)
        .limit(5);
      
      if (anyLogs && anyLogs.length > 0) {
        console.log(`⚠️ [deleteMessageEverywhere] Encontrados ${anyLogs.length} log(s) mas nenhum com status 'sent' e telegram_message_id:`);
        anyLogs.forEach((log, idx) => {
          console.log(`   Log ${idx + 1}: status=${log.status}, telegram_message_id=${log.telegram_message_id || 'NULL'}, error=${log.error_message || 'N/A'}`);
        });
      }
    }
    
    // Se não há logs, verificar se a mensagem foi criada no Flutter (source='app')
    // Se foi criada no Flutter e não tem log, significa que nunca foi enviada para o Telegram
    // Nesse caso, não é um erro - apenas não precisa deletar no Telegram
    if (telegramLogs.length === 0) {
      const source = mensagem.source || 'app';
      if (source === 'app') {
        console.log(`ℹ️ [deleteMessageEverywhere] Mensagem criada no Flutter sem log de entrega - provavelmente nunca foi enviada para o Telegram`);
        console.log(`ℹ️ [deleteMessageEverywhere] Continuando com soft delete no Supabase apenas`);
      } else if (source === 'telegram') {
        console.warn(`⚠️ [deleteMessageEverywhere] Mensagem criada do Telegram sem log de entrega - pode ser mensagem antiga ou log perdido`);
      }
    }
    
    // 3. Deletar no Telegram (se houver deliveries)
    let deletedFromTelegram = 0;
    const telegramErrors = [];
    
    for (const log of telegramLogs) {
      try {
        if (!log.telegram_chat_id || !log.telegram_message_id) {
          console.warn(`⚠️ [deleteMessageEverywhere] Log incompleto: chat_id=${log.telegram_chat_id}, message_id=${log.telegram_message_id}`);
          continue;
        }
        
        const payload = {
          chat_id: log.telegram_chat_id,
          message_id: log.telegram_message_id,
        };
        
        // message_thread_id não é necessário para deleteMessage, mas logamos para contexto
        if (log.telegram_topic_id) {
          console.log(`📝 [deleteMessageEverywhere] Contexto: message_thread_id=${log.telegram_topic_id} (não necessário para delete)`);
        }
        
        console.log(`🗑️ [deleteMessageEverywhere] Deletando no Telegram: chat=${log.telegram_chat_id}, message_id=${log.telegram_message_id}`);
        
        const deleteResponse = await fetch(
          `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/deleteMessage`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
          }
        );
        
        const deleteData = await deleteResponse.json();
        
        if (deleteData.ok) {
          deletedFromTelegram++;
          console.log(`✅ [deleteMessageEverywhere] Mensagem deletada no Telegram`);
          
          // Atualizar status do log para 'deleted'
          await supabase
            .from('telegram_delivery_logs')
            .update({ 
              status: 'deleted',
              updated_at: new Date().toISOString(),
            })
            .eq('id', log.id);
        } else {
          const errorMsg = deleteData.description || 'Unknown error';
          const errorCode = deleteData.error_code;
          
          // Se a mensagem já foi deletada no Telegram, considerar como sucesso
          if (errorCode === 400 && (
            errorMsg.includes('message to delete not found') ||
            errorMsg.includes('message can\'t be deleted') ||
            errorMsg.includes('message not found') ||
            errorMsg.toLowerCase().includes('bad request: message')
          )) {
            deletedFromTelegram++;
            console.log(`✅ [deleteMessageEverywhere] Mensagem já estava deletada no Telegram (considerando sucesso)`);
            
            // Atualizar status do log para 'deleted' mesmo assim
            await supabase
              .from('telegram_delivery_logs')
              .update({ 
                status: 'deleted',
                updated_at: new Date().toISOString(),
              })
              .eq('id', log.id);
          } else {
            console.error(`❌ [deleteMessageEverywhere] Erro ao deletar no Telegram:`, errorMsg);
            telegramErrors.push({
              chat_id: log.telegram_chat_id,
              message_id: log.telegram_message_id,
              error: errorMsg,
              error_code: errorCode,
            });
          }
        }
      } catch (error) {
        console.error(`❌ [deleteMessageEverywhere] Erro ao processar log Telegram:`, error);
        telegramErrors.push({
          chat_id: log.telegram_chat_id,
          message_id: log.telegram_message_id,
          error: error.message,
        });
      }
    }
    
    // 4. Deletar arquivo do Storage (se existir)
    let deletedFromStorage = false;
    const storagePath = mensagem.storage_path;
    
    if (storagePath) {
      try {
        console.log(`🗑️ [deleteMessageEverywhere] Deletando arquivo do Storage: ${storagePath}`);
        
        // Extrair bucket e path do storage_path
        // Formato esperado: "task_id/timestamp-file.jpg" (já é o path relativo ao bucket)
        const bucketName = 'anexos-tarefas';
        const filePath = storagePath;
        
        const { error: storageError } = await supabase.storage
          .from(bucketName)
          .remove([filePath]);
        
        if (storageError) {
          console.error(`❌ [deleteMessageEverywhere] Erro ao deletar do Storage:`, storageError);
          // Não falhar a deleção completa se o arquivo não existir mais
          if (!storageError.message.includes('not found') && !storageError.message.includes('does not exist')) {
            throw storageError;
          }
        } else {
          deletedFromStorage = true;
          console.log(`✅ [deleteMessageEverywhere] Arquivo deletado do Storage`);
        }
      } catch (storageError) {
        console.error(`❌ [deleteMessageEverywhere] Erro ao deletar do Storage:`, storageError);
        // Continuar mesmo com erro no storage
      }
    } else {
      console.log(`ℹ️ [deleteMessageEverywhere] Nenhum arquivo no Storage para deletar`);
    }
    
    // 5. Marcar como deletado no banco (soft delete ou hard delete)
    if (options.softDelete) {
      // Soft delete: marcar deleted_at e deleted_by
      const { error: updateError } = await supabase
        .from('mensagens')
        .update({
          deleted_at: new Date().toISOString(),
          deleted_by: origin,
        })
        .eq('id', messageId);
      
      if (updateError) {
        console.error(`❌ [deleteMessageEverywhere] Erro ao marcar mensagem como deletada:`, updateError);
        throw updateError;
      }
      
      console.log(`✅ [deleteMessageEverywhere] Mensagem marcada como deletada (soft delete)`);
    } else {
      // Hard delete: deletar fisicamente
      const { error: deleteError } = await supabase
        .from('mensagens')
        .delete()
        .eq('id', messageId);
      
      if (deleteError) {
        console.error(`❌ [deleteMessageEverywhere] Erro ao deletar mensagem:`, deleteError);
        throw deleteError;
      }
      
      console.log(`✅ [deleteMessageEverywhere] Mensagem deletada fisicamente (hard delete)`);
    }
    
    // 6. Retornar resultado
    const result = {
      ok: true,
      deleted: true, // Sempre true se chegou até aqui (mensagem foi deletada do Supabase)
      deletedFromTelegram,
      deletedFromStorage,
      totalTelegramLogs: telegramLogs.length,
    };
    
    // Adicionar informação sobre por que não deletou no Telegram (se aplicável)
    if (telegramLogs.length === 0) {
      const source = mensagem.source || 'app';
      if (source === 'app') {
        result.reason = 'Message was never sent to Telegram (no delivery log)';
        result.info = 'Mensagem criada no Flutter que nunca foi enviada para o Telegram - deletada apenas do Supabase';
      } else {
        result.reason = 'No delivery logs found (message may be old or log was lost)';
        result.warning = 'Mensagem do Telegram sem log de entrega - pode ser mensagem antiga';
      }
    }
    
    if (telegramErrors.length > 0) {
      result.errors = telegramErrors;
    }
    
    console.log(`✅ [deleteMessageEverywhere] Deleção concluída:`, result);
    return result;
    
  } catch (error) {
    console.error(`❌ [deleteMessageEverywhere] Erro geral:`, error);
    return {
      ok: false,
      deleted: false,
      deletedFromTelegram: 0,
      deletedFromStorage: false,
      error: error.message,
    };
  }
}

// ==========================================
// FUNÇÕES AUXILIARES PARA ENVIO DE MÍDIA
// ==========================================

/**
 * Normaliza uma URL do Supabase para usar sempre o host público
 * Substitui http://127.0.0.1:8000 e http://localhost:8000 por SUPABASE_URL_PUBLIC
 * 
 * @param {string} url - URL a ser normalizada
 * @returns {string} URL normalizada com host público
 */
function toPublicSupabaseUrl(url) {
  if (!url || typeof url !== 'string') {
    return url;
  }
  
  try {
    const urlObj = new URL(SUPABASE_URL_PUBLIC);
    const publicHost = urlObj.host; // Ex: "212.85.0.249:8000" ou "api.taskflowv3.com.br"
    const publicProtocol = urlObj.protocol; // "http:" ou "https:"
    
    // Substituir qualquer ocorrência de localhost ou 127.0.0.1 pela URL pública
    let publicUrl = url;
    publicUrl = publicUrl.replace(/https?:\/\/127\.0\.0\.1(:\d+)?/g, `${publicProtocol}//${publicHost}`);
    publicUrl = publicUrl.replace(/https?:\/\/localhost(:\d+)?/g, `${publicProtocol}//${publicHost}`);
    
    return publicUrl;
  } catch (error) {
    console.warn(`⚠️ Erro ao normalizar URL, retornando original: ${error.message}`);
    return url;
  }
}

/**
 * Gera uma URL assinada do Supabase Storage
 * @param {string} bucket - Nome do bucket
 * @param {string} path - Caminho do arquivo no storage
 * @param {number} expiresIn - Tempo de expiração em segundos (padrão: 1 hora)
 * @returns {Promise<string>} URL assinada (sempre com host público)
 */
async function getSignedUrlFromSupabase(bucket, path, expiresIn = 3600) {
  try {
    console.log(`🔗 Gerando URL assinada: bucket=${bucket}, path=${path}, expiresIn=${expiresIn}s`);
    
    const { data, error } = await supabase.storage
      .from(bucket)
      .createSignedUrl(path, expiresIn);
    
    if (error) {
      console.error(`❌ Erro ao gerar URL assinada: ${error.message}`);
      throw error;
    }
    
    if (!data || !data.signedUrl) {
      throw new Error('URL assinada não retornada pelo Supabase');
    }
    
    // CRÍTICO: Normalizar URL para usar host público
    // O Telegram precisa acessar a URL externamente
    const publicUrl = toPublicSupabaseUrl(data.signedUrl);
    
    console.log(`✅ URL assinada gerada (original): ${data.signedUrl.substring(0, 100)}...`);
    console.log(`✅ URL assinada gerada (pública): ${publicUrl.substring(0, 100)}...`);
    
    return publicUrl;
  } catch (error) {
    console.error(`❌ Erro em getSignedUrlFromSupabase: ${error.message}`);
    throw error;
  }
}

/**
 * Envia mídia para o Telegram usando duas estratégias:
 * - Estratégia A (preferida): URL pública do Supabase (sem multipart)
 * - Estratégia B (fallback): Multipart upload com axios + form-data
 * 
 * @param {Object} params
 * @param {string|number} params.chatId - Chat ID do Telegram
 * @param {string|number} params.threadId - Thread ID (tópico) do Telegram (usa message_thread_id)
 * @param {string} params.fileUrl - URL pública do arquivo (já normalizada para host público)
 * @param {string} params.mimeType - Tipo MIME do arquivo
 * @param {string} params.fileName - Nome do arquivo
 * @param {string} [params.caption] - Legenda opcional
 * @returns {Promise<{ok: boolean, status: number, telegramData?: any, error?: string}>}
 */
async function sendMediaToTelegram({ chatId, threadId, fileUrl, mimeType, fileName, caption = '' }) {
  const chatIdStr = String(chatId);
  const threadIdNum = Number(threadId);
  
  // CRÍTICO: Garantir que a URL seja sempre pública (normalizada)
  const publicFileUrl = toPublicSupabaseUrl(fileUrl);
  
  // Determinar método da API baseado no tipo MIME
  let apiMethod;
  let fieldName;
  
  if (mimeType.startsWith('image/')) {
    apiMethod = 'sendPhoto';
    fieldName = 'photo';
  } else if (mimeType.startsWith('video/')) {
    apiMethod = 'sendVideo';
    fieldName = 'video';
  } else if (mimeType.startsWith('audio/')) {
    apiMethod = 'sendAudio';
    fieldName = 'audio';
  } else {
    apiMethod = 'sendDocument';
    fieldName = 'document';
  }
  
  const apiUrl = `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/${apiMethod}`;
  
  console.log(`📤 [sendMediaToTelegram] Iniciando envio:`);
  console.log(`   - chatId: ${chatIdStr}`);
  console.log(`   - threadId: ${threadIdNum}`);
  console.log(`   - fileName: ${fileName}`);
  console.log(`   - mimeType: ${mimeType}`);
  console.log(`   - apiMethod: ${apiMethod}`);
  console.log(`   - fieldName: ${fieldName}`);
  console.log(`   - fileUrl (original): ${fileUrl.substring(0, 100)}...`);
  console.log(`   - fileUrl (pública): ${publicFileUrl.substring(0, 100)}...`);
  
  // ESTRATÉGIA A: Tentar enviar via URL pública (sem multipart)
  try {
    console.log(`🔄 [Estratégia A] Tentando enviar via URL pública...`);
    
    const payload = {
      chat_id: chatIdStr,
      message_thread_id: threadIdNum,
      [fieldName]: publicFileUrl,
    };
    
    if (caption) {
      payload.caption = caption.replace(/<[^>]*>/g, '');
    }
    
    console.log(`📡 [Estratégia A] URL da API: ${apiUrl}`);
    console.log(`📡 [Estratégia A] Payload: ${JSON.stringify({ ...payload, [fieldName]: '[URL]' })}`);
    
    const response = await axios.post(apiUrl, payload, {
      headers: { 'Content-Type': 'application/json' },
      timeout: 30000,
    });
    
    console.log(`✅ [Estratégia A] Sucesso!`);
    console.log(`   - Status: ${response.status}`);
    console.log(`   - Headers: ${JSON.stringify(response.headers)}`);
    console.log(`   - Response: ${JSON.stringify(response.data)}`);
    
    if (response.data && response.data.ok) {
      return {
        ok: true,
        status: response.status,
        telegramData: response.data.result,
      };
    } else {
      throw new Error(`Telegram retornou ok=false: ${JSON.stringify(response.data)}`);
    }
  } catch (strategyAError) {
    console.warn(`⚠️ [Estratégia A] Falhou: ${strategyAError.message}`);
    
    // Log detalhado do erro da Estratégia A
    if (strategyAError.response) {
      console.warn(`   - Status: ${strategyAError.response.status}`);
      console.warn(`   - Headers: ${JSON.stringify(strategyAError.response.headers)}`);
      console.warn(`   - Body: ${JSON.stringify(strategyAError.response.data)}`);
    }
    
    console.warn(`   - Tentando Estratégia B (multipart)...`);
    
    // ESTRATÉGIA B: Fallback para multipart upload
    try {
      console.log(`🔄 [Estratégia B] Baixando arquivo e enviando via FormData...`);
      
      // Para download interno, usar URL interna (127.0.0.1) se necessário
      // Mas a URL pública pode funcionar também se o servidor estiver acessível
      let downloadUrl = publicFileUrl;
      
      // Se a URL pública contém o host público, tentar usar URL interna para download
      // (mais rápido e não depende de acesso externo)
      const urlObj = new URL(publicFileUrl);
      if (urlObj.host === new URL(SUPABASE_URL_PUBLIC).host) {
        // Substituir host público por interno para download
        const internalUrlObj = new URL(SUPABASE_URL_INTERNAL);
        downloadUrl = publicFileUrl.replace(urlObj.host, internalUrlObj.host);
        console.log(`📥 Usando URL interna para download: ${downloadUrl.substring(0, 100)}...`);
      }
      
      console.log(`📥 Baixando de: ${downloadUrl.substring(0, 100)}...`);
      const fileResponse = await fetch(downloadUrl, {
        method: 'GET',
        headers: { 'Accept': '*/*' },
      });
      
      if (!fileResponse.ok) {
        throw new Error(`Erro ao baixar arquivo: ${fileResponse.status} ${fileResponse.statusText}`);
      }
      
      const fileBuffer = await fileResponse.arrayBuffer();
      const fileBytes = Buffer.from(fileBuffer);
      console.log(`✅ Arquivo baixado: ${fileBytes.length} bytes`);
      
      // Criar FormData
      const form = new FormData();
      form.append('chat_id', chatIdStr);
      form.append('message_thread_id', threadIdNum);
      form.append(fieldName, fileBytes, { filename: fileName });
      
      if (caption) {
        form.append('caption', caption.replace(/<[^>]*>/g, ''));
      }
      
      const formHeaders = form.getHeaders();
      console.log(`📡 [Estratégia B] URL da API: ${apiUrl}`);
      console.log(`📡 [Estratégia B] Headers: ${JSON.stringify(formHeaders)}`);
      console.log(`📡 [Estratégia B] FormData: ${fieldName}=${fileName}, size=${fileBytes.length} bytes`);
      
      // Usar axios para enviar FormData (melhor suporte que fetch nativo)
      const response = await axios.post(apiUrl, form, {
        headers: formHeaders,
        timeout: 60000, // 60 segundos para arquivos grandes
        maxContentLength: Infinity,
        maxBodyLength: Infinity,
      });
      
      console.log(`✅ [Estratégia B] Sucesso!`);
      console.log(`   - Status: ${response.status}`);
      console.log(`   - Headers: ${JSON.stringify(response.headers)}`);
      console.log(`   - Response: ${JSON.stringify(response.data)}`);
      
      if (response.data && response.data.ok) {
        return {
          ok: true,
          status: response.status,
          telegramData: response.data.result,
        };
      } else {
        throw new Error(`Telegram retornou ok=false: ${JSON.stringify(response.data)}`);
      }
    } catch (strategyBError) {
      console.error(`❌ [Estratégia B] Falhou: ${strategyBError.message}`);
      
      // Log detalhado do erro
      if (strategyBError.response) {
        console.error(`   - Status: ${strategyBError.response.status}`);
        console.error(`   - Headers: ${JSON.stringify(strategyBError.response.headers)}`);
        console.error(`   - Body: ${JSON.stringify(strategyBError.response.data)}`);
      }
      
      return {
        ok: false,
        status: strategyBError.response?.status || 0,
        error: strategyBError.message,
        telegramData: strategyBError.response?.data,
      };
    }
  }
}

// Endpoint para enviar mensagem do Flutter para Telegram (GENERALIZADO)
app.post('/send-message', async (req, res) => {
  try {
    console.log('📥 Recebida requisição /send-message');
    
    const { mensagem_id, thread_type, thread_id } = req.body;

    if (!mensagem_id || !thread_type || !thread_id) {
      return res.status(400).json({ error: 'Parâmetros faltando: mensagem_id, thread_type, thread_id' });
    }

    // thread_id é o grupo_id (grupos_chat.id)
    const grupoId = thread_id;

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

    // 2. Obter task_id do grupo_id
    const taskId = await getTaskIdFromGrupoId(grupoId);
    if (!taskId) {
      console.warn(`⚠️ Tarefa não encontrada para grupo ${grupoId}`);
      return res.json({ ok: true, sent: false, reason: 'Task not found' });
    }

    console.log(`\n🔍 ========================================`);
    console.log(`🔍 [send-message] DEBUG COMPLETO - INÍCIO`);
    console.log(`🔍 ========================================`);
    console.log(`🔍 [send-message] grupoId (thread_id): ${grupoId}`);
    console.log(`🔍 [send-message] taskId obtido: ${taskId}`);

    // DEBUG: Verificar grupo_chat e comunidade
    const { data: grupoChatDebug } = await supabase
      .from('grupos_chat')
      .select('id, tarefa_id, tarefa_nome, comunidade_id')
      .eq('id', grupoId)
      .maybeSingle();
    
    if (!grupoChatDebug) {
      console.error(`❌ [send-message] DEBUG: grupo_chat não encontrado para id=${grupoId}`);
      return res.json({ ok: true, sent: false, reason: 'Grupo chat not found' });
    }
    
    console.log(`🔍 [send-message] DEBUG: grupo_chat encontrado:`);
    console.log(`   - id: ${grupoChatDebug.id}`);
    console.log(`   - tarefa_id: ${grupoChatDebug.tarefa_id}`);
    console.log(`   - tarefa_nome: ${grupoChatDebug.tarefa_nome}`);
    console.log(`   - comunidade_id: ${grupoChatDebug.comunidade_id}`);
    console.log(`   📋 TABELA: grupos_chat`);
    
    // Verificar comunidade e telegram_chat_id
    const { data: comunidadeDebug } = await supabase
      .from('comunidades')
      .select('id, regional_id, regional_nome, divisao_id, divisao_nome, segmento_id, segmento_nome')
      .eq('id', grupoChatDebug.comunidade_id)
      .maybeSingle();
    
    if (!comunidadeDebug) {
      console.error(`❌ [send-message] DEBUG: comunidade não encontrada para id=${grupoChatDebug.comunidade_id}`);
      return res.json({ ok: true, sent: false, reason: 'Comunidade not found' });
    }
    
    console.log(`🔍 [send-message] DEBUG: comunidade encontrada:`);
    console.log(`   - id: ${comunidadeDebug.id}`);
    console.log(`   - regional_id: ${comunidadeDebug.regional_id}`);
    console.log(`   - regional_nome: ${comunidadeDebug.regional_nome}`);
    console.log(`   - divisao_id: ${comunidadeDebug.divisao_id}`);
    console.log(`   - divisao_nome: ${comunidadeDebug.divisao_nome}`);
    console.log(`   - segmento_id: ${comunidadeDebug.segmento_id}`);
    console.log(`   - segmento_nome: ${comunidadeDebug.segmento_nome}`);
    console.log(`   📋 TABELA: comunidades`);
    
    // Verificar telegram_communities
    console.log(`🔍 [send-message] DEBUG: Buscando telegram_chat_id na tabela telegram_communities...`);
    console.log(`   - WHERE community_id = ${grupoChatDebug.comunidade_id}`);
    
    const { data: telegramCommunityDebug, error: telegramError } = await supabase
      .from('telegram_communities')
      .select('id, community_id, telegram_chat_id, created_at, updated_at')
      .eq('community_id', grupoChatDebug.comunidade_id)
      .maybeSingle();
    
    if (telegramError) {
      console.error(`❌ [send-message] DEBUG: Erro ao buscar telegram_communities:`, telegramError);
    } else if (!telegramCommunityDebug) {
      console.warn(`⚠️ [send-message] DEBUG: Nenhum registro encontrado em telegram_communities`);
      console.warn(`   - community_id procurado: ${grupoChatDebug.comunidade_id}`);
      console.warn(`   - Isso significa que a comunidade não tem um grupo Telegram configurado!`);
    } else {
      console.log(`✅ [send-message] DEBUG: telegram_communities encontrado:`);
      console.log(`   - id: ${telegramCommunityDebug.id}`);
      console.log(`   - community_id: ${telegramCommunityDebug.community_id}`);
      console.log(`   - telegram_chat_id: ${telegramCommunityDebug.telegram_chat_id}`);
      console.log(`   - created_at: ${telegramCommunityDebug.created_at}`);
      console.log(`   - updated_at: ${telegramCommunityDebug.updated_at}`);
      console.log(`   📋 TABELA: telegram_communities`);
      console.log(`\n🎯 [send-message] RESULTADO: A mensagem será enviada para:`);
      console.log(`   - Telegram Chat ID: ${telegramCommunityDebug.telegram_chat_id}`);
      console.log(`   - Comunidade ID: ${grupoChatDebug.comunidade_id}`);
      console.log(`   - Comunidade: ${comunidadeDebug.regional_nome} - ${comunidadeDebug.divisao_nome} - ${comunidadeDebug.segmento_nome}`);
    }
    
    console.log(`🔍 ========================================`);
    console.log(`🔍 [send-message] DEBUG COMPLETO - FIM`);
    console.log(`🔍 ========================================\n`);

    // 3. Garantir que o tópico existe (criar se necessário)
    console.log(`🔍 [send-message] Chamando ensureTaskTopic para taskId: ${taskId}`);
    const topic = await ensureTaskTopic(taskId);
    if (!topic) {
      console.warn(`⚠️ [send-message] Não foi possível obter/criar tópico para tarefa ${taskId}`);
      return res.json({ ok: true, sent: false, reason: 'Topic not available' });
    }

    console.log(`✅ [send-message] Tópico obtido: chat=${topic.telegram_chat_id}, topic=${topic.telegram_topic_id}, name=${topic.topic_name}`);

    // 4. Processar tags Nota/Ordem (se houver)
    let refType = mensagem.ref_type || 'GERAL';
    let refId = mensagem.ref_id || null;
    let refLabel = mensagem.ref_label || null;
    
    // Se ref_type foi fornecido no payload, usar (compatibilidade com versão antiga)
    if (req.body.ref_type) {
      refType = req.body.ref_type;
      refId = req.body.ref_id || null;
      refLabel = req.body.ref_label || null;
    }
    
    // Validar e gerar ref_label se necessário
    if (refType && refType !== 'GERAL' && refId) {
      // Validar se ref_id existe
      if (refType === 'NOTA') {
        const { data: nota, error: notaError } = await supabase
          .from('notas_sap')
          .select('id, nota')
          .eq('id', refId)
          .maybeSingle();
        
        if (notaError || !nota) {
          console.warn(`⚠️ Nota não encontrada: ${refId}, usando GERAL`);
          refType = 'GERAL';
          refId = null;
          refLabel = null;
        } else if (!refLabel) {
          refLabel = `NOTA ${nota.nota}`;
        }
      } else if (refType === 'ORDEM') {
        const { data: ordem, error: ordemError } = await supabase
          .from('ordens')
          .select('id, ordem')
          .eq('id', refId)
          .maybeSingle();
        
        if (ordemError || !ordem) {
          console.warn(`⚠️ Ordem não encontrada: ${refId}, usando GERAL`);
          refType = 'GERAL';
          refId = null;
          refLabel = null;
        } else if (!refLabel) {
          refLabel = `ORDEM ${ordem.ordem}`;
        }
      }
    }
    
    // 5. Formatar mensagem para Telegram com prefixo de tag
    let text = '';
    let prefixo = '';
    
    // Adicionar prefixo baseado no ref_type
    if (refType === 'NOTA' && refLabel) {
      prefixo = `📌 ${refLabel}\n\n`;
    } else if (refType === 'ORDEM' && refLabel) {
      prefixo = `🧾 ${refLabel}\n\n`;
    } else {
      prefixo = `💬 GERAL\n\n`;
    }
    
    // Variável para caption de mídia (será usada mais abaixo)
    let mediaCaption = '';
    
    if (mensagem.conteudo) {
      text = prefixo + `<b>${mensagem.usuario_nome || 'Usuário'}:</b>\n${mensagem.conteudo}`;
      mediaCaption = text; // Para texto, caption = text
    } else if (!mensagem.arquivo_url) {
      text = prefixo + `<b>${mensagem.usuario_nome || 'Usuário'}</b> enviou uma mensagem`;
      mediaCaption = text;
    } else {
      // Para mídia, o prefixo vai no caption
      mediaCaption = prefixo + `<b>${mensagem.usuario_nome || 'Usuário'}</b> enviou uma mídia`;
      text = ''; // Text será vazio para mídia, usar caption
    }

    // Se houver mídia, usar a nova função sendMediaToTelegram
    let response;
    try {
      if (mensagem.arquivo_url && mensagem.tipo) {
        console.log(`📎 Processando mídia: tipo=${mensagem.tipo}, url=${mensagem.arquivo_url}`);
        
        // CRÍTICO: Normalizar URL para sempre usar host público
        let fileUrl = toPublicSupabaseUrl(mensagem.arquivo_url);
        console.log(`📎 URL normalizada (pública): ${fileUrl.substring(0, 100)}...`);
        
        // Extrair nome do arquivo e tipo MIME
        let fileName = 'file';
        let mimeType = 'application/octet-stream';
        
        // Tentar extrair do caminho do storage ou da URL
        const urlMatch = fileUrl.match(/anexos-tarefas\/(.+?)(\?|$)/);
        if (urlMatch && urlMatch[1]) {
          const storagePath = decodeURIComponent(urlMatch[1]);
          console.log(`📁 Caminho do storage extraído: ${storagePath}`);
          
          // Extrair nome do arquivo e tipo MIME do caminho
          const pathParts = storagePath.split('/');
          if (pathParts.length > 0) {
            fileName = pathParts[pathParts.length - 1];
            // Determinar MIME type baseado na extensão
            const ext = fileName.split('.').pop()?.toLowerCase();
            if (ext === 'jpg' || ext === 'jpeg' || ext === 'png' || ext === 'gif' || ext === 'webp') {
              mimeType = `image/${ext === 'jpg' ? 'jpeg' : ext}`;
            } else if (ext === 'mp4' || ext === 'mov' || ext === 'avi') {
              mimeType = `video/${ext === 'mp4' ? 'mp4' : 'quicktime'}`;
            } else if (ext === 'mp3' || ext === 'wav' || ext === 'ogg') {
              mimeType = `audio/${ext === 'mp3' ? 'mpeg' : ext}`;
            }
          }
        } else {
          // Se não conseguir extrair, tentar extrair da URL completa
          try {
            const urlObj = new URL(fileUrl);
            const pathParts = urlObj.pathname.split('/');
            if (pathParts.length > 0) {
              fileName = pathParts[pathParts.length - 1];
            }
          } catch (e) {
            console.warn(`⚠️ Não foi possível extrair nome do arquivo da URL`);
          }
        }
        
        // Usar a nova função sendMediaToTelegram com retry
        let result;
        let retries = 1;
        
        while (retries >= 0) {
          try {
            result = await sendMediaToTelegram({
              chatId: topic.telegram_chat_id,
              threadId: topic.telegram_topic_id,
              fileUrl: fileUrl, // Passar URL pública normalizada
              mimeType: mimeType,
              fileName: fileName,
              caption: mediaCaption || prefixo || '',
            });
            
            if (result.ok) {
              console.log(`✅ Mídia enviada com sucesso para Telegram`);
              break;
            } else {
              throw new Error(result.error || 'Erro desconhecido');
            }
          } catch (error) {
            if (retries > 0) {
              console.warn(`⚠️ Tentativa falhou, tentando novamente... (${retries} tentativa(s) restante(s))`);
              retries--;
              await new Promise(resolve => setTimeout(resolve, 1000)); // Aguardar 1 segundo antes de retry
            } else {
              throw error;
            }
          }
        }
        
        if (!result || !result.ok) {
          throw new Error(result?.error || 'Falha ao enviar mídia após retry');
        }
        
        // Processar resposta de mídia diretamente
        const data = { ok: true, result: result.telegramData };
        
        if (data.ok) {
          const telegramMessageId = data.result?.message_id;
          console.log(`✅ Mensagem enviada para Telegram (chat: ${topic.telegram_chat_id}, topic: ${topic.telegram_topic_id}, message_id: ${telegramMessageId})`);
          
          // Salvar log de entrega usando função helper robusta
          try {
            const { data: logData, error: logError } = await insertDeliveryLog({
              mensagem_id: mensagem_id,
              telegram_chat_id: topic.telegram_chat_id,
              telegram_topic_id: topic.telegram_topic_id,
              telegram_message_id: telegramMessageId,
              status: 'sent',
            });
            
            if (logError) {
              console.error(`❌ [send-message] Erro ao salvar log de entrega (mídia):`, logError);
              console.error(`   Mensagem ID: ${mensagem_id}, Telegram Message ID: ${telegramMessageId}`);
              console.error(`   Chat ID: ${topic.telegram_chat_id}, Topic ID: ${topic.telegram_topic_id}`);
            } else {
              console.log(`✅ [send-message] Log de entrega salvo com sucesso (mídia):`, logData);
              
              // Verificar se o log foi realmente criado
              if (!logData || logData.length === 0) {
                console.warn(`⚠️ [send-message] Insert retornou sucesso mas sem dados (mídia). Verificando...`);
                const { data: verifyLog } = await supabase
                  .from('telegram_delivery_logs')
                  .select('id, telegram_message_id')
                  .eq('mensagem_id', mensagem_id)
                  .eq('telegram_message_id', telegramMessageId)
                  .limit(1);
                
                if (!verifyLog || verifyLog.length === 0) {
                  console.error(`❌ [send-message] CRÍTICO: Log não foi criado no banco (mídia)!`);
                } else {
                  console.log(`✅ [send-message] Log verificado no banco (mídia):`, verifyLog[0]);
                }
              }
            }
          } catch (logException) {
            console.error(`❌ [send-message] Exceção ao salvar log de entrega (mídia):`, logException);
            console.error(`   Stack:`, logException.stack);
          }
      
          return res.json({ 
            ok: true, 
            sent: true, 
            sentCount: 1,
            ref_type: refType,
            ref_id: refId,
            ref_label: refLabel,
          });
        } else {
          console.error(`❌ Erro ao enviar para Telegram:`, data);
          
          // Salvar log de erro
          await insertDeliveryLog({
            mensagem_id: mensagem_id,
            telegram_chat_id: topic.telegram_chat_id,
            telegram_topic_id: topic.telegram_topic_id,
            status: 'failed',
            error_message: data.description || 'Unknown error',
          });
      
          return res.status(500).json({ ok: false, sent: false, error: data.description });
        }
      } else {
        // Enviar mensagem de texto normal
        const payload = {
          chat_id: topic.telegram_chat_id,
          message_thread_id: topic.telegram_topic_id,
          text: text || `<b>${mensagem.usuario_nome || 'Usuário'}</b> enviou uma mensagem`,
          parse_mode: 'HTML',
        };

        response = await fetch(
          `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
          }
        );
      }
    } catch (mediaError) {
      console.error('❌ Erro ao enviar mídia, tentando enviar como mensagem de texto:', mediaError);
      // Fallback: enviar como mensagem de texto com link
      const publicFileUrl = mensagem.arquivo_url ? toPublicSupabaseUrl(mensagem.arquivo_url) : null;
      const payload = {
        chat_id: topic.telegram_chat_id,
        message_thread_id: topic.telegram_topic_id,
        text: text + (publicFileUrl ? `\n\n📎 <a href="${publicFileUrl}">Ver anexo</a>` : ''),
        parse_mode: 'HTML',
      };
      response = await fetch(
        `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload),
        }
      );
    }

    // Processar resposta (pode ser JSON ou texto)
    let data;
    
    // Verificar se a resposta tem conteúdo
    const contentType = response.headers.get('content-type') || '';
    console.log(`📎 Content-Type da resposta: ${contentType}`);
    console.log(`📎 Status da resposta: ${response.status}`);
    
    const responseText = await response.text();
    console.log(`📎 Tamanho da resposta: ${responseText.length} caracteres`);
    console.log(`📎 Primeiros 200 caracteres da resposta: ${responseText.substring(0, 200)}`);
    
    // Se a resposta estiver vazia, tratar como erro
    if (!responseText || responseText.trim().length === 0) {
      console.error('❌ Resposta vazia do Telegram');
      await insertDeliveryLog({
        mensagem_id: mensagem_id,
        telegram_chat_id: topic.telegram_chat_id,
        telegram_topic_id: topic.telegram_topic_id,
        status: 'failed',
        error_message: 'Resposta vazia do Telegram',
      });

      return res.status(500).json({ 
        ok: false, 
        sent: false, 
        error: 'Resposta vazia do Telegram',
        details: 'A resposta do Telegram estava vazia'
      });
    }
    
    try {
      data = JSON.parse(responseText);
      console.log(`📎 Resposta parseada com sucesso: ok=${data.ok}`);
    } catch (parseError) {
      console.error('❌ Erro ao fazer parse da resposta JSON:', parseError);
      console.error('   Resposta recebida (primeiros 500 chars):', responseText.substring(0, 500));
      console.error('   Resposta completa (últimos 500 chars):', responseText.substring(Math.max(0, responseText.length - 500)));
      
      // Se não conseguir fazer parse, tratar como erro
      await insertDeliveryLog({
        mensagem_id: mensagem_id,
        telegram_chat_id: topic.telegram_chat_id,
        telegram_topic_id: topic.telegram_topic_id,
        status: 'failed',
        error_message: `Erro ao processar resposta: ${parseError.message}`,
      });

      return res.status(500).json({ 
        ok: false, 
        sent: false, 
        error: 'Erro ao processar resposta do Telegram',
        details: parseError.message,
        responsePreview: responseText.substring(0, 200)
      });
    }

    if (data.ok) {
      const telegramMessageId = data.result?.message_id;
      console.log(`✅ Mensagem enviada para Telegram (chat: ${topic.telegram_chat_id}, topic: ${topic.telegram_topic_id}, message_id: ${telegramMessageId})`);
      
      // Salvar log de entrega usando função helper robusta
      try {
        const { data: logData, error: logError } = await insertDeliveryLog({
          mensagem_id: mensagem_id,
          task_id: taskId,
          telegram_chat_id: topic.telegram_chat_id,
          telegram_topic_id: topic.telegram_topic_id,
          telegram_message_id: telegramMessageId,
          status: 'sent',
        });
        
        if (logError) {
          console.error(`❌ [send-message] Erro ao salvar log de entrega:`, logError);
          console.error(`   Mensagem ID: ${mensagem_id}, Telegram Message ID: ${telegramMessageId}`);
          console.error(`   Chat ID: ${topic.telegram_chat_id}, Topic ID: ${topic.telegram_topic_id}`);
        } else {
          console.log(`✅ [send-message] Log de entrega salvo com sucesso:`, logData);
          
          // Verificar se o log foi realmente criado
          if (!logData || logData.length === 0) {
            console.warn(`⚠️ [send-message] Insert retornou sucesso mas sem dados. Verificando...`);
            const { data: verifyLog } = await supabase
              .from('telegram_delivery_logs')
              .select('id, telegram_message_id')
              .eq('mensagem_id', mensagem_id)
              .eq('telegram_message_id', telegramMessageId)
              .limit(1);
            
            if (!verifyLog || verifyLog.length === 0) {
              console.error(`❌ [send-message] CRÍTICO: Log não foi criado no banco!`);
            } else {
              console.log(`✅ [send-message] Log verificado no banco:`, verifyLog[0]);
            }
          }
        }
      } catch (logException) {
        console.error(`❌ [send-message] Exceção ao salvar log de entrega:`, logException);
        console.error(`   Stack:`, logException.stack);
      }

      res.json({ 
        ok: true, 
        sent: true, 
        sentCount: 1,
        ref_type: refType,
        ref_id: refId,
        ref_label: refLabel,
      });
    } else {
      console.error(`❌ Erro ao enviar para Telegram:`, data);
      
      // Salvar log de erro
      await insertDeliveryLog({
        mensagem_id: mensagem_id,
        telegram_chat_id: topic.telegram_chat_id,
        telegram_topic_id: topic.telegram_topic_id,
        status: 'failed',
        error_message: data.description || 'Unknown error',
      });

      res.json({ ok: true, sent: false, error: data.description });
    }
  } catch (error) {
    console.error('❌ Erro ao processar send-message:', error);
    res.status(500).json({ error: error.message });
  }
});

// Endpoint RESTful para deletar mensagem (DELETE /messages/:id)
app.delete('/messages/:id', async (req, res) => {
  try {
    const messageId = req.params.id;
    const { softDelete = true } = req.query; // Por padrão, soft delete
    
    console.log(`🗑️ [DELETE /messages/:id] Recebida requisição para deletar mensagem: ${messageId}`);
    
    if (!messageId) {
      return res.status(400).json({ error: 'ID da mensagem é obrigatório' });
    }
    
    // TODO: Validar permissão do usuário (verificar se pode deletar)
    // Por enquanto, permitir deleção (em produção, adicionar autenticação/autorização)
    
    // Usar função centralizada
    const result = await deleteMessageEverywhere(
      messageId,
      'flutter', // Origem da deleção
      { softDelete: softDelete === 'true' || softDelete === true }
    );
    
    if (!result.ok) {
      return res.status(500).json(result);
    }
    
    if (!result.deleted) {
      return res.status(404).json(result);
    }
    
    res.json(result);
  } catch (error) {
    console.error('❌ Erro ao processar DELETE /messages/:id:', error);
    res.status(500).json({ error: error.message });
  }
});

// Endpoint legado para compatibilidade (POST /delete-message)
app.post('/delete-message', async (req, res) => {
  try {
    console.log('🗑️ Recebida requisição /delete-message (legado)');
    
    const { mensagem_id } = req.body;

    if (!mensagem_id) {
      return res.status(400).json({ error: 'mensagem_id é obrigatório' });
    }

    // Usar função centralizada
    const result = await deleteMessageEverywhere(mensagem_id, 'flutter', { softDelete: true });
    
    if (!result.ok) {
      return res.status(500).json(result);
    }
    
    res.json({
      ok: true,
      deleted: result.deleted, // Sempre true se mensagem foi deletada do Supabase
      deletedCount: result.deletedFromTelegram,
      totalLogs: result.totalTelegramLogs || 0,
      reason: result.reason,
      info: result.info,
      warning: result.warning,
      errors: result.errors,
    });
  } catch (error) {
    console.error('❌ Erro ao processar delete-message:', error);
    res.status(500).json({ error: error.message });
  }
});

// Endpoint para processar exclusão de mensagem detectada no Telegram
// NOTA: Bot API não recebe updates quando mensagens são deletadas manualmente pelo usuário
// Este endpoint pode ser usado se implementarmos MTProto/userbot no futuro
// ou se recebermos notificações de deleção por outros meios
app.post('/telegram-message-deleted', async (req, res) => {
  try {
    console.log('🗑️ Recebida notificação de mensagem deletada no Telegram');
    
    const { chat_id, message_id, message_thread_id } = req.body;

    if (!chat_id || !message_id) {
      return res.status(400).json({ error: 'chat_id e message_id são obrigatórios' });
    }

    console.log(`🔍 [telegram-message-deleted] Buscando mensagem: chat_id=${chat_id}, message_id=${message_id}, message_thread_id=${message_thread_id || 'N/A'}`);

    // Buscar mensagem no Supabase através dos logs de entrega
    let query = supabase
      .from('telegram_delivery_logs')
      .select('id, mensagem_id, telegram_chat_id, telegram_message_id, telegram_topic_id')
      .eq('telegram_message_id', message_id)
      .eq('telegram_chat_id', chat_id)
      .eq('status', 'sent');

    // Se tiver message_thread_id, usar para filtrar (opcional, mas ajuda)
    if (message_thread_id) {
      query = query.eq('telegram_topic_id', message_thread_id);
    }

    const { data: deliveryLog, error: logError } = await query.maybeSingle();

    if (logError) {
      console.error('❌ Erro ao buscar log:', logError);
      return res.status(500).json({ error: 'Erro ao buscar log de entrega' });
    }

    if (!deliveryLog || !deliveryLog.mensagem_id) {
      console.warn(`⚠️ [telegram-message-deleted] Nenhum log encontrado para message_id=${message_id}`);
      return res.json({ ok: true, deleted: false, reason: 'No delivery log found' });
    }

    console.log(`✅ [telegram-message-deleted] Log encontrado: mensagem_id=${deliveryLog.mensagem_id}`);

    // Usar função centralizada para deletar
    const result = await deleteMessageEverywhere(
      deliveryLog.mensagem_id,
      'telegram', // Origem da deleção
      { softDelete: true }
    );

    if (!result.ok) {
      return res.status(500).json(result);
    }

    res.json({
      ok: true,
      deleted: result.deleted,
      mensagem_id: deliveryLog.mensagem_id,
      deletedFromStorage: result.deletedFromStorage,
    });
  } catch (error) {
    console.error('❌ Erro ao processar mensagem deletada:', error);
    res.status(500).json({ error: error.message });
  }
});

// ==========================================
// PROCESSAMENTO DE MENSAGENS TELEGRAM -> SUPABASE
// ==========================================

async function processMessage(message, isEdit) {
  console.log(`📝 Processando mensagem ${isEdit ? '(editada)' : ''} de ${message.from.first_name}`);

  const telegramUserId = message.from.id;
  const chatId = message.chat.id;
  const topicId = message.message_thread_id;
  const messageText = message.text || '';

  // 0. Processar comando /start (vinculação)
  if (messageText.startsWith('/start')) {
    console.log(`🔗 Comando /start recebido de ${telegramUserId}`);
    
    // Extrair payload do /start (ex: /start link_<user_id>)
    const parts = messageText.split(' ');
    const payload = parts.length > 1 ? parts[1] : null;
    
    if (payload && payload.startsWith('link_')) {
      // Extrair user_id do payload
      const userId = payload.replace('link_', '');
      console.log(`🔗 Tentando vincular Telegram ${telegramUserId} ao usuário ${userId}`);
      
      // Verificar se o usuário existe (pode ser de 'usuarios' ou 'executores')
      let executor = null;
      let executorId = null;
      
      // Primeiro, tentar buscar em 'executores'
      const { data: executorData } = await supabase
        .from('executores')
        .select('id, nome')
        .eq('id', userId)
        .maybeSingle();
      
      if (executorData) {
        executor = executorData;
        executorId = executorData.id;
      } else {
        // Se não encontrou em 'executores', tentar buscar em 'usuarios' e depois mapear para 'executores'
        const { data: usuarioData } = await supabase
          .from('usuarios')
          .select('id, email, nome')
          .eq('id', userId)
          .maybeSingle();
        
        if (usuarioData) {
          console.log(`🔍 Buscando executor para usuario: email=${usuarioData.email}`);
          
          // Tentar encontrar executor pelo login (que geralmente é o email)
          let executorEncontrado = null;
          
          if (usuarioData.email) {
            const { data: executorByLogin } = await supabase
              .from('executores')
              .select('id, nome, telefone')
              .eq('login', usuarioData.email)
              .maybeSingle();
            
            if (executorByLogin) {
              executorEncontrado = executorByLogin;
              console.log(`✅ Executor encontrado por login: ${executorByLogin.nome}`);
            }
          }
          
          // Se não encontrou por login, tentar buscar todos os executores e verificar telefone
          // (isso é mais lento, mas pode ser necessário se o login não estiver preenchido)
          if (!executorEncontrado) {
            console.log(`⚠️ Executor não encontrado por login, tentando buscar todos...`);
            // Por enquanto, vamos retornar erro pedindo vinculação manual
            // pois buscar todos os executores seria muito lento
          }
          
          if (executorEncontrado) {
            executor = executorEncontrado;
            executorId = executorEncontrado.id;
          } else {
            // Não encontrou executor correspondente
            console.error(`❌ Executor não encontrado para usuario ${userId} (email: ${usuarioData.email})`);
            await sendTelegramMessage(
              chatId,
              '❌ Não foi possível encontrar seu executor correspondente.\n\n' +
              'Por favor, entre em contato com o administrador para vincular manualmente, ou use o script de vinculação manual.',
              null
            );
            return;
          }
        }
      }
      
      if (!executor || !executorId) {
        console.error(`❌ Usuário não encontrado: ${userId}`);
        await sendTelegramMessage(
          chatId,
          '❌ Usuário não encontrado. Por favor, use o botão "Vincular Telegram" no app Flutter.',
          null
        );
        return;
      }
      
      // Vincular Telegram ao usuário (usar executorId, não userId original)
      const { error: linkError } = await supabase
        .from('telegram_identities')
        .upsert({
          user_id: executorId, // Usar o ID do executor encontrado
          telegram_user_id: telegramUserId,
          telegram_username: message.from.username || null,
          telegram_first_name: message.from.first_name || null,
          linked_at: new Date().toISOString(),
          last_active_at: new Date().toISOString(),
          last_chat_id: chatId,
        }, {
          onConflict: 'telegram_user_id'
        });
      
      if (linkError) {
        console.error('❌ Erro ao vincular:', linkError);
        await sendTelegramMessage(
          chatId,
          '❌ Erro ao vincular conta. Tente novamente.',
          null
        );
        return;
      }
      
      console.log(`✅ Telegram ${telegramUserId} vinculado ao usuário ${executor.nome} (${executorId})`);
      await sendTelegramMessage(
        chatId,
        `✅ Conta vinculada com sucesso!\n\nOlá, ${executor.nome}! Sua conta Telegram está agora conectada ao TaskFlow.\n\nVocê pode enviar mensagens nos tópicos das tarefas e elas aparecerão no app Flutter.`,
        null
      );
      return;
    } else {
      // /start sem payload - mostrar instruções
      await sendTelegramMessage(
        chatId,
        '👋 Olá! Para vincular sua conta Telegram ao TaskFlow:\n\n1. Abra o app Flutter\n2. Vá até um chat de tarefa\n3. Clique no ícone de Telegram\n4. Clique em "Vincular meu Telegram"\n\nIsso abrirá um link especial que conecta sua conta automaticamente.',
        null
      );
      return;
    }
  }

  // 0.1. Processar comando /associar (associar grupo a comunidade)
  if (messageText.startsWith('/associar')) {
    console.log(`🔗 Comando /associar recebido de ${telegramUserId} no grupo ${chatId}`);
    
    // Só funciona em grupos/supergrupos
    if (message.chat.type !== 'supergroup' && message.chat.type !== 'group') {
      await sendTelegramMessage(
        chatId,
        '⚠️ Este comando só funciona em grupos.',
        null
      );
      return;
    }

    // Verificar se já está cadastrado
    const { data: existing } = await supabase
      .from('telegram_communities')
      .select('id, community_id')
      .eq('telegram_chat_id', chatId)
      .maybeSingle();

    if (existing) {
      await sendTelegramMessage(
        chatId,
        '⚠️ Este grupo já está cadastrado para uma comunidade. Use o script de atualização se precisar alterar.',
        null
      );
      return;
    }

    // Extrair ID da comunidade do comando
    const parts = messageText.split(' ');
    if (parts.length < 2) {
      // Listar comunidades disponíveis
      const { data: todasComunidades } = await supabase
        .from('comunidades')
        .select('id, divisao_nome, segmento_nome')
        .order('divisao_nome', { ascending: true });

      const { data: comunidadesComGrupo } = await supabase
        .from('telegram_communities')
        .select('community_id');

      const idsComGrupo = new Set();
      if (comunidadesComGrupo) {
        comunidadesComGrupo.forEach(tc => idsComGrupo.add(tc.community_id));
      }

      const comunidadesSemGrupo = todasComunidades.filter(c => !idsComGrupo.has(c.id));

      if (comunidadesSemGrupo.length === 0) {
        await sendTelegramMessage(
          chatId,
          '⚠️ Todas as comunidades já têm grupo cadastrado.',
          null
        );
        return;
      }

      let mensagem = '📋 Comunidades disponíveis (sem grupo):\n\n';
      comunidadesSemGrupo.forEach((c, index) => {
        const nomeComunidade = `${c.divisao_nome} - ${c.segmento_nome}`;
        mensagem += `${index + 1}. ${nomeComunidade}\n`;
        mensagem += `   ID: ${c.id}\n\n`;
      });
      mensagem += `🔧 Use: /associar <ID_DA_COMUNIDADE>`;

      await sendTelegramMessage(chatId, mensagem, null);
      return;
    }

    const communityId = parts[1].trim();

    // Verificar se a comunidade existe
    const { data: comunidade } = await supabase
      .from('comunidades')
      .select('id, divisao_nome, segmento_nome')
      .eq('id', communityId)
      .maybeSingle();

    if (!comunidade) {
      await sendTelegramMessage(
        chatId,
        `❌ Comunidade não encontrada com ID: ${communityId}`,
        null
      );
      return;
    }

    // Verificar se a comunidade já tem grupo
    const { data: comunidadeComGrupo } = await supabase
      .from('telegram_communities')
      .select('id')
      .eq('community_id', communityId)
      .maybeSingle();

    if (comunidadeComGrupo) {
      await sendTelegramMessage(
        chatId,
        `⚠️ Esta comunidade já tem um grupo cadastrado.`,
        null
      );
      return;
    }

    // Cadastrar grupo para a comunidade
    const nomeComunidade = `${comunidade.divisao_nome} - ${comunidade.segmento_nome}`;
    const sucesso = await cadastrarGrupoParaComunidade(chatId, comunidade);

    if (sucesso) {
      console.log(`✅ Grupo ${chatId} associado manualmente à comunidade ${nomeComunidade}`);
    }

    return;
  }

  // 1. Buscar usuário vinculado
  const { data: identity } = await supabase
    .from('telegram_identities')
    .select('user_id')
    .eq('telegram_user_id', telegramUserId)
    .maybeSingle();

  if (!identity) {
    console.warn(`⚠️ Usuário Telegram ${telegramUserId} não vinculado`);
    await sendTelegramMessage(
      chatId,
      '⚠️ Sua conta Telegram ainda não está vinculada ao TaskFlow.\n\n' +
      'Use o botão "Vincular Telegram" no app para conectar sua conta.',
      topicId
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

  // 3. Identificar tarefa a partir do tópico
  if (!topicId) {
    console.warn('⚠️ Mensagem não está em um tópico');
    await sendTelegramMessage(
      chatId,
      '⚠️ Por favor, envie mensagens dentro dos tópicos das tarefas.',
      null
    );
    return;
  }

  const taskMapping = await identifyTaskFromTopic(chatId, topicId);
  if (!taskMapping) {
    console.warn(`⚠️ Tópico não mapeado: chat=${chatId}, topic=${topicId}`);
    await sendTelegramMessage(
      chatId,
      '⚠️ Este tópico não está vinculado a uma tarefa. Entre em contato com o administrador.',
      topicId
    );
    return;
  }

  // 4. TODO: Validar permissão do usuário na tarefa
  // Por enquanto, permitir se estiver vinculado

  // 4.5. Detectar tags Nota/Ordem no texto do Telegram (ANTES de processar mídia)
  let refType = 'GERAL';
  let refId = null;
  let refLabel = null;
  let conteudoOriginal = message.text || message.caption || '📎 Mídia';
  let conteudo = conteudoOriginal;
  
  // Detectar tags usando diferentes formatos:
  // 1. Comandos: /nota 12345 ou /ordem 67890
  // 2. Hashtags: #nota12345 ou #ordem67890
  // 3. Formato especial: @nota:12345 ou @ordem:67890
  
  const notaCommandMatch = conteudo.match(/^\/(?:nota|n)\s+(\d+)/i);
  const ordemCommandMatch = conteudo.match(/^\/(?:ordem|o)\s+(\d+)/i);
  const notaHashtagMatch = conteudo.match(/#(?:nota|n)(\d+)/i);
  const ordemHashtagMatch = conteudo.match(/#(?:ordem|o)(\d+)/i);
  const notaAtMatch = conteudo.match(/@(?:nota|n):(\d+)/i);
  const ordemAtMatch = conteudo.match(/@(?:ordem|o):(\d+)/i);
  
  let notaNumero = null;
  let ordemNumero = null;
  
  if (notaCommandMatch) {
    notaNumero = notaCommandMatch[1];
    // Remover comando do conteúdo
    conteudo = conteudo.replace(/^\/(?:nota|n)\s+\d+\s*/i, '').trim();
  } else if (notaHashtagMatch) {
    notaNumero = notaHashtagMatch[1];
    // Remover hashtag do conteúdo
    conteudo = conteudo.replace(/#(?:nota|n)\d+/i, '').trim();
  } else if (notaAtMatch) {
    notaNumero = notaAtMatch[1];
    // Remover @nota: do conteúdo
    conteudo = conteudo.replace(/@(?:nota|n):\d+/i, '').trim();
  }
  
  if (ordemCommandMatch) {
    ordemNumero = ordemCommandMatch[1];
    // Remover comando do conteúdo
    conteudo = conteudo.replace(/^\/(?:ordem|o)\s+\d+\s*/i, '').trim();
  } else if (ordemHashtagMatch) {
    ordemNumero = ordemHashtagMatch[1];
    // Remover hashtag do conteúdo
    conteudo = conteudo.replace(/#(?:ordem|o)\d+/i, '').trim();
  } else if (ordemAtMatch) {
    ordemNumero = ordemAtMatch[1];
    // Remover @ordem: do conteúdo
    conteudo = conteudo.replace(/@(?:ordem|o):\d+/i, '').trim();
  }
  
  // Se encontrou nota ou ordem, buscar no banco
  // taskMapping já foi obtido acima, vamos usar
  if (notaNumero && taskMapping && taskMapping.task_id) {
    console.log(`📌 [Telegram] Tag NOTA detectada: ${notaNumero}`);
    
    // Buscar todas as notas da tarefa e filtrar pelo número
    const { data: notasRel, error: notasRelError } = await supabase
      .from('tasks_notas_sap')
      .select('nota_sap_id, notas_sap(id, nota)')
      .eq('task_id', taskMapping.task_id);
    
    if (!notasRelError && notasRel) {
      // Filtrar no código pela nota específica
      const notaEncontrada = notasRel.find(rel => 
        rel.notas_sap && rel.notas_sap.nota === notaNumero
      );
      
      if (notaEncontrada) {
        refType = 'NOTA';
        refId = notaEncontrada.nota_sap_id;
        refLabel = `NOTA ${notaNumero}`;
        console.log(`✅ [Telegram] Nota encontrada e vinculada: ${refLabel}`);
      } else {
        console.warn(`⚠️ [Telegram] Nota ${notaNumero} não encontrada para esta tarefa`);
        await sendTelegramMessage(
          chatId,
          `⚠️ Nota ${notaNumero} não encontrada para esta tarefa.`,
          topicId
        );
      }
    } else {
      console.warn(`⚠️ [Telegram] Erro ao buscar notas: ${notasRelError?.message}`);
    }
  } else if (ordemNumero && taskMapping && taskMapping.task_id) {
    console.log(`🧾 [Telegram] Tag ORDEM detectada: ${ordemNumero}`);
    
    // Buscar todas as ordens da tarefa e filtrar pelo número
    const { data: ordensRel, error: ordensRelError } = await supabase
      .from('tasks_ordens')
      .select('ordem_id, ordens(id, ordem)')
      .eq('task_id', taskMapping.task_id);
    
    if (!ordensRelError && ordensRel) {
      // Filtrar no código pela ordem específica
      const ordemEncontrada = ordensRel.find(rel => 
        rel.ordens && rel.ordens.ordem === ordemNumero
      );
      
      if (ordemEncontrada) {
        refType = 'ORDEM';
        refId = ordemEncontrada.ordem_id;
        refLabel = `ORDEM ${ordemNumero}`;
        console.log(`✅ [Telegram] Ordem encontrada e vinculada: ${refLabel}`);
      } else {
        console.warn(`⚠️ [Telegram] Ordem ${ordemNumero} não encontrada para esta tarefa`);
        await sendTelegramMessage(
          chatId,
          `⚠️ Ordem ${ordemNumero} não encontrada para esta tarefa.`,
          topicId
        );
      }
    } else {
      console.warn(`⚠️ [Telegram] Erro ao buscar ordens: ${ordensRelError?.message}`);
    }
  }
  
  // Se não encontrou conteúdo após remover tags, usar texto padrão
  if (!conteudo || conteudo.trim() === '') {
    conteudo = refType === 'NOTA' || refType === 'ORDEM' 
        ? `Mensagem vinculada a ${refLabel}` 
        : '📎 Mídia';
  }

  // 5. Extrair conteúdo e processar mídia
  let tipo = message.photo ? 'imagem' : message.video ? 'video' : message.audio ? 'audio' : message.document ? 'documento' : 'texto';
  
  // Processar mídia: baixar do Telegram e fazer upload para Supabase Storage
  let arquivoUrl = null;
  let storagePath = null; // CRÍTICO: Armazenar para permitir deleção posterior
  if (message.photo || message.video || message.audio || message.document || message.voice) {
    try {
      console.log(`📎 Processando mídia do Telegram: tipo=${tipo}`);
      
      // Obter file_id da mídia
      let fileId = null;
      let fileName = null;
      let mimeType = null;
      
      if (message.photo && message.photo.length > 0) {
        // Para fotos, pegar a maior resolução (última do array)
        fileId = message.photo[message.photo.length - 1].file_id;
        fileName = `photo_${message.message_id}.jpg`;
        mimeType = 'image/jpeg';
        tipo = 'imagem';
      } else if (message.video) {
        fileId = message.video.file_id;
        fileName = message.video.file_name || `video_${message.message_id}.mp4`;
        mimeType = message.video.mime_type || 'video/mp4';
        tipo = 'video';
      } else if (message.audio) {
        fileId = message.audio.file_id;
        fileName = message.audio.file_name || `audio_${message.message_id}.mp3`;
        mimeType = message.audio.mime_type || 'audio/mpeg';
        tipo = 'audio';
      } else if (message.voice) {
        fileId = message.voice.file_id;
        fileName = `voice_${message.message_id}.ogg`;
        mimeType = 'audio/ogg';
        tipo = 'audio';
      } else if (message.document) {
        fileId = message.document.file_id;
        fileName = message.document.file_name || `document_${message.message_id}`;
        mimeType = message.document.mime_type || 'application/octet-stream';
        tipo = 'documento';
      }
      
      if (fileId) {
        console.log(`📥 Baixando arquivo do Telegram: file_id=${fileId}, nome=${fileName}`);
        
        // 1. Obter informações do arquivo
        const fileInfoResponse = await fetch(
          `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getFile?file_id=${fileId}`
        );
        const fileInfo = await fileInfoResponse.json();
        
        if (!fileInfo.ok) {
          throw new Error(`Erro ao obter informações do arquivo: ${fileInfo.description}`);
        }
        
        const filePath = fileInfo.result.file_path;
        console.log(`📥 Caminho do arquivo no Telegram: ${filePath}`);
        
        // 2. Baixar arquivo do Telegram
        const fileUrl = `https://api.telegram.org/file/bot${TELEGRAM_BOT_TOKEN}/${filePath}`;
        const fileResponse = await fetch(fileUrl);
        
        if (!fileResponse.ok) {
          throw new Error(`Erro ao baixar arquivo: ${fileResponse.statusText}`);
        }
        
        const fileBuffer = await fileResponse.arrayBuffer();
        const fileBytes = Buffer.from(fileBuffer);
        
        console.log(`✅ Arquivo baixado: ${fileBytes.length} bytes`);
        
        // 3. Fazer upload para Supabase Storage
        const bucketName = 'anexos-tarefas';
        const timestamp = Date.now();
        const sanitizedFileName = fileName.replace(/[^a-zA-Z0-9._-]/g, '_');
        const storagePath = `${taskMapping.task_id}/${timestamp}-${sanitizedFileName}`;
        
        console.log(`📤 Fazendo upload para Supabase Storage: ${storagePath}`);
        
        const { data: uploadData, error: uploadError } = await supabase.storage
          .from(bucketName)
          .upload(storagePath, fileBytes, {
            contentType: mimeType,
            upsert: false,
          });
        
        if (uploadError) {
          console.error('❌ Erro ao fazer upload para Supabase Storage:', uploadError);
          throw uploadError;
        }
        
        console.log(`✅ Upload concluído: ${storagePath}`);
        
        // CRÍTICO: Armazenar storage_path para permitir deleção posterior
        // arquivoUrl será gerado abaixo, mas storage_path é necessário para delete
        
        // 4. Obter URL assinada usando a função que corrige para URL pública
        // URL assinada válida por 1 ano (31536000 segundos)
        try {
          arquivoUrl = await getSignedUrlFromSupabase(bucketName, storagePath, 31536000); // 1 ano
          // getSignedUrlFromSupabase já retorna URL normalizada, mas garantir
          arquivoUrl = toPublicSupabaseUrl(arquivoUrl);
          console.log(`✅ URL do arquivo gerada (pública): ${arquivoUrl.substring(0, 150)}...`);
        } catch (signedUrlError) {
          console.error('❌ Erro ao criar URL assinada:', signedUrlError);
          // Fallback: tentar URL pública direta
          const { data: urlData } = supabase.storage
            .from(bucketName)
            .getPublicUrl(storagePath);
          arquivoUrl = urlData.publicUrl;
          
          // CRÍTICO: Normalizar URL para sempre usar host público
          arquivoUrl = toPublicSupabaseUrl(arquivoUrl);
          
          console.log(`✅ URL do arquivo gerada (fallback público): ${arquivoUrl.substring(0, 150)}...`);
        }
        console.log(`📋 Resumo da mídia processada:`);
        console.log(`   - Tipo: ${tipo}`);
        console.log(`   - Nome: ${fileName}`);
        console.log(`   - Tamanho: ${fileBytes.length} bytes`);
        console.log(`   - MIME: ${mimeType}`);
        console.log(`   - Storage Path: ${storagePath}`);
        console.log(`   - URL: ${arquivoUrl.substring(0, 100)}...`);
        
        // 5. Salvar metadados na tabela anexos (opcional, mas útil)
        try {
          const { data: anexoData, error: anexoError } = await supabase.from('anexos').insert({
            task_id: taskMapping.task_id,
            nome_arquivo: fileName,
            tipo_arquivo: tipo,
            caminho_arquivo: storagePath,
            tamanho_bytes: fileBytes.length,
            mime_type: mimeType,
          }).select().single();
          
          if (anexoError) {
            console.warn('⚠️ Erro ao salvar metadados do anexo (não crítico):', anexoError);
          } else {
            console.log(`✅ Metadados do anexo salvos: id=${anexoData?.id}`);
          }
        } catch (anexoError) {
          console.warn('⚠️ Erro ao salvar metadados do anexo (não crítico):', anexoError);
        }
      } else {
        console.warn('⚠️ fileId não encontrado na mensagem');
      }
    } catch (mediaError) {
      console.error('❌ Erro ao processar mídia do Telegram:', mediaError);
      console.error('❌ Mensagem do erro:', mediaError.message);
      console.error('❌ Stack trace:', mediaError.stack);
      // Continuar mesmo se falhar o processamento de mídia
      // Mas registrar o erro para debug
      console.warn('⚠️ Continuando sem salvar mídia no storage devido ao erro acima');
      // Não definir arquivoUrl como null aqui, deixar como está (null)
    }
  }

  // 6. Buscar nome do executor
  const { data: executor } = await supabase
    .from('executores')
    .select('nome, matricula')
    .eq('id', identity.user_id)
    .maybeSingle();

  const usuarioNome = executor?.nome || message.from.first_name;

  // 7. Inserir mensagem
  console.log(`📝 Inserindo mensagem no banco:`);
  console.log(`   - grupo_id: ${taskMapping.grupo_chat_id}`);
  console.log(`   - usuario_id: ${identity.user_id}`);
  console.log(`   - usuario_nome: ${usuarioNome}`);
  console.log(`   - conteudo: ${conteudo.substring(0, 100)}...`);
  console.log(`   - tipo: ${tipo}`);
  console.log(`   - arquivo_url: ${arquivoUrl ? arquivoUrl.substring(0, 100) + '...' : 'null'}`);
  console.log(`   - source: telegram`);
  console.log(`   - ref_type: ${refType}`);
  console.log(`   - ref_label: ${refLabel || 'null'}`);
  
  // Preparar dados para inserção
  const mensagemData = {
    grupo_id: taskMapping.grupo_chat_id,
    usuario_id: identity.user_id,
    usuario_nome: usuarioNome,
    conteudo,
    tipo,
    arquivo_url: arquivoUrl,
    source: 'telegram',
    // Tags detectadas do texto do Telegram (ou GERAL se não detectar)
    ref_type: refType,
    ref_id: refId,
    ref_label: refLabel,
    telegram_metadata: {
      chat_id: chatId,
      message_id: message.message_id,
      from_id: message.from.id,
      username: message.from.username,
      first_name: message.from.first_name,
      topic_id: topicId,
      is_edit: isEdit,
      original_text: conteudoOriginal, // Guardar texto original com tags
    },
  };
  
  // Adicionar storage_path se existir (para permitir deleção posterior)
  if (storagePath) {
    mensagemData.storage_path = storagePath;
  }
  
  const { data: novaMensagem, error } = await supabase
    .from('mensagens')
    .insert(mensagemData)
    .select()
    .single();

  if (error) {
    console.error('❌ Erro ao inserir mensagem:', error);
    console.error('   - Código:', error.code);
    console.error('   - Mensagem:', error.message);
    console.error('   - Detalhes:', error.details);
    throw error;
  }

  console.log(`✅ Mensagem ${novaMensagem.id} inserida no grupo ${taskMapping.grupo_chat_id}`);
  console.log(`   - arquivo_url salvo: ${novaMensagem.arquivo_url ? novaMensagem.arquivo_url.substring(0, 100) + '...' : 'null'}`);

  // 8. Salvar log de entrega (para rastrear mensagens do Telegram e permitir exclusão bidirecional)
  try {
    await insertDeliveryLog({
      mensagem_id: novaMensagem.id,
      telegram_chat_id: chatId,
      telegram_topic_id: topicId,
      telegram_message_id: message.message_id,
      status: 'sent',
    });
    console.log(`✅ Log de entrega salvo para mensagem ${novaMensagem.id} (telegram_message_id: ${message.message_id})`);
  } catch (logError) {
    console.warn('⚠️ Erro ao salvar log de entrega (não crítico):', logError);
  }

  // 9. Atualizar updated_at do grupo
  await supabase
    .from('grupos_chat')
    .update({ updated_at: new Date().toISOString() })
    .eq('id', taskMapping.grupo_chat_id);

  // 10. Se não detectou tag, enviar botões inline para seleção
  if (refType === 'GERAL' && taskMapping && taskMapping.task_id) {
    // Enviar mensagem com botões (não podemos editar mensagem sem reply_markup)
    await enviarBotoesSelecaoTag(chatId, message.message_id, topicId, taskMapping.task_id, novaMensagem.id);
  }
}

/**
 * Envia botões inline para selecionar Nota/Ordem vinculadas à tarefa
 */
async function enviarBotoesSelecaoTag(chatId, originalMessageId, topicId, taskId, mensagemId) {
  try {
    // Buscar notas vinculadas à tarefa
    const { data: notasRel, error: notasError } = await supabase
      .from('tasks_notas_sap')
      .select('nota_sap_id, notas_sap(id, nota, descricao)')
      .eq('task_id', taskId)
      .order('notas_sap(nota)', { ascending: true });
    
    // Buscar ordens vinculadas à tarefa
    const { data: ordensRel, error: ordensError } = await supabase
      .from('tasks_ordens')
      .select('ordem_id, ordens(id, ordem, texto_breve)')
      .eq('task_id', taskId)
      .order('ordens(ordem)', { ascending: true });
    
    const notas = (notasRel || []).filter(rel => rel.notas_sap).map(rel => ({
      id: rel.nota_sap_id,
      numero: rel.notas_sap.nota,
      descricao: rel.notas_sap.descricao || '',
    }));
    
    const ordens = (ordensRel || []).filter(rel => rel.ordens).map(rel => ({
      id: rel.ordem_id,
      numero: rel.ordens.ordem,
      descricao: rel.ordens.texto_breve || '',
    }));
    
    // Se não houver notas nem ordens, não enviar botões
    if (notas.length === 0 && ordens.length === 0) {
      return;
    }
    
    // Criar botões inline
    const inlineKeyboard = [];
    
    // Botões de Notas (máximo 3 por linha)
    if (notas.length > 0) {
      inlineKeyboard.push([{ text: '📌 Notas:', callback_data: 'tag_header_notas' }]);
      
      for (let i = 0; i < notas.length; i += 3) {
        const linha = notas.slice(i, i + 3).map(nota => ({
          text: `📌 ${nota.numero}`,
          callback_data: `tag_nota_${nota.id}`,
        }));
        inlineKeyboard.push(linha);
      }
    }
    
    // Botões de Ordens (máximo 3 por linha)
    if (ordens.length > 0) {
      inlineKeyboard.push([{ text: '🧾 Ordens:', callback_data: 'tag_header_ordens' }]);
      
      for (let i = 0; i < ordens.length; i += 3) {
        const linha = ordens.slice(i, i + 3).map(ordem => ({
          text: `🧾 ${ordem.numero}`,
          callback_data: `tag_ordem_${ordem.id}`,
        }));
        inlineKeyboard.push(linha);
      }
    }
    
    // Botões de ação (Geral e Cancelar)
    inlineKeyboard.push([
      { text: '📋 Geral', callback_data: 'tag_geral' },
      { text: '❌ Cancelar', callback_data: 'tag_cancel' },
    ]);
    
    // Enviar mensagem com botões (respondendo à mensagem original)
    const response = await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        chat_id: chatId,
        message_thread_id: topicId,
        text: '🏷️ Vincular mensagem a:',
        reply_to_message_id: originalMessageId,
        reply_markup: {
          inline_keyboard: inlineKeyboard,
        },
      }),
    });
    
    const responseData = await response.json();
    if (responseData.ok) {
      // Salvar ID da mensagem de botões no metadata da mensagem original
      await supabase
        .from('mensagens')
        .update({
          telegram_metadata: {
            ...((await supabase.from('mensagens').select('telegram_metadata').eq('id', mensagemId).single()).data?.telegram_metadata || {}),
            buttons_message_id: responseData.result.message_id,
          },
        })
        .eq('id', mensagemId);
      
      console.log(`✅ Botões de seleção enviados para mensagem ${originalMessageId} (${notas.length} notas, ${ordens.length} ordens)`);
    } else {
      console.error('❌ Erro ao enviar botões:', responseData);
    }
    
  } catch (error) {
    console.error('❌ Erro ao enviar botões de seleção:', error);
    // Não falhar o processamento da mensagem se os botões falharem
  }
}

async function processCallbackQuery(callbackQuery) {
  const chatId = callbackQuery.message.chat.id;
  const buttonsMessageId = callbackQuery.message.message_id; // ID da mensagem com botões
  const topicId = callbackQuery.message.message_thread_id;
  const userId = callbackQuery.from.id;
  const callbackData = callbackQuery.data;
  
  console.log('🔘 Processando callback query:', callbackData);
  
  // Buscar mensagem original (reply_to_message)
  const originalMessageId = callbackQuery.message.reply_to_message?.message_id;
  
  if (!originalMessageId) {
    console.warn('⚠️ Mensagem original não encontrada no callback');
    await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/answerCallbackQuery`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        callback_query_id: callbackQuery.id,
        text: '❌ Mensagem original não encontrada',
        show_alert: true,
      }),
    });
    return;
  }
  
  try {
    // Formato do callback_data: "tag_nota_<nota_sap_id>" ou "tag_ordem_<ordem_id>"
    if (callbackData.startsWith('tag_nota_')) {
      const notaSapId = callbackData.replace('tag_nota_', '');
      await vincularTagMensagem(chatId, originalMessageId, buttonsMessageId, topicId, userId, 'NOTA', notaSapId);
      
      // Responder ao callback (remove loading)
      await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/answerCallbackQuery`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          callback_query_id: callbackQuery.id,
          text: '✅ Mensagem vinculada à Nota',
          show_alert: false,
        }),
      });
      
    } else if (callbackData.startsWith('tag_ordem_')) {
      const ordemId = callbackData.replace('tag_ordem_', '');
      await vincularTagMensagem(chatId, originalMessageId, buttonsMessageId, topicId, userId, 'ORDEM', ordemId);
      
      // Responder ao callback (remove loading)
      await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/answerCallbackQuery`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          callback_query_id: callbackQuery.id,
          text: '✅ Mensagem vinculada à Ordem',
          show_alert: false,
        }),
      });
      
    } else if (callbackData === 'tag_geral') {
      await vincularTagMensagem(chatId, originalMessageId, buttonsMessageId, topicId, userId, 'GERAL', null);
      
      // Responder ao callback
      await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/answerCallbackQuery`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          callback_query_id: callbackQuery.id,
          text: '✅ Mensagem marcada como Geral',
          show_alert: false,
        }),
      });
      
    } else if (callbackData === 'tag_cancel') {
      // Remover botões da mensagem
      await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/editMessageText`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          chat_id: chatId,
          message_id: buttonsMessageId,
          text: '❌ Seleção cancelada',
          reply_markup: { inline_keyboard: [] },
        }),
      });
      
      await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/answerCallbackQuery`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          callback_query_id: callbackQuery.id,
        }),
      });
    } else if (callbackData === 'tag_header_notas' || callbackData === 'tag_header_ordens') {
      // Headers não fazem nada, apenas respondem
      await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/answerCallbackQuery`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          callback_query_id: callbackQuery.id,
        }),
      });
    }
  } catch (error) {
    console.error('❌ Erro ao processar callback query:', error);
    
    // Responder com erro
    await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/answerCallbackQuery`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        callback_query_id: callbackQuery.id,
        text: '❌ Erro ao vincular tag',
        show_alert: true,
      }),
    });
  }
}

/**
 * Vincula uma tag (Nota/Ordem) a uma mensagem existente
 */
async function vincularTagMensagem(chatId, originalMessageId, buttonsMessageId, topicId, userId, refType, refId) {
  try {
    // 1. Buscar identidade do usuário
    const { data: identity } = await supabase
      .from('telegram_identities')
      .select('user_id')
      .eq('telegram_user_id', userId)
      .maybeSingle();
    
    if (!identity) {
      console.warn(`⚠️ Usuário Telegram ${userId} não vinculado`);
      return;
    }
    
    // 2. Identificar tarefa do tópico
    const taskMapping = await identifyTaskFromTopic(chatId, topicId);
    if (!taskMapping) {
      console.warn(`⚠️ Tópico não mapeado: chat=${chatId}, topic=${topicId}`);
      return;
    }
    
    // 3. Buscar mensagem no banco pelo telegram_message_id (mensagem original)
    const { data: mensagens, error: mensagemError } = await supabase
      .from('mensagens')
      .select('id, conteudo')
      .eq('grupo_id', taskMapping.grupo_chat_id)
      .eq('usuario_id', identity.user_id)
      .contains('telegram_metadata', { message_id: originalMessageId })
      .maybeSingle();
    
    if (mensagemError || !mensagens) {
      console.warn(`⚠️ Mensagem não encontrada no banco: message_id=${originalMessageId}`);
      return;
    }
    
    // 4. Preparar dados de atualização
    let refLabel = null;
    
    if (refType === 'NOTA' && refId) {
      // Buscar número da nota
      const { data: nota } = await supabase
        .from('notas_sap')
        .select('nota')
        .eq('id', refId)
        .maybeSingle();
      
      if (nota) {
        refLabel = `NOTA ${nota.nota}`;
      }
    } else if (refType === 'ORDEM' && refId) {
      // Buscar número da ordem
      const { data: ordem } = await supabase
        .from('ordens')
        .select('ordem')
        .eq('id', refId)
        .maybeSingle();
      
      if (ordem) {
        refLabel = `ORDEM ${ordem.ordem}`;
      }
    }
    
    // 5. Atualizar mensagem no banco
    const updateData = {
      ref_type: refType,
      ref_id: refType === 'GERAL' ? null : refId,
      ref_label: refLabel,
      updated_at: new Date().toISOString(),
    };
    
    const { error: updateError } = await supabase
      .from('mensagens')
      .update(updateData)
      .eq('id', mensagens.id);
    
    if (updateError) {
      console.error('❌ Erro ao atualizar mensagem:', updateError);
      throw updateError;
    }
    
    console.log(`✅ Mensagem ${mensagens.id} atualizada com tag: ${refType} ${refLabel || ''}`);
    
    // 6. Atualizar mensagem de botões no Telegram
    await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/editMessageText`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        chat_id: chatId,
        message_id: buttonsMessageId,
        text: `✅ Mensagem vinculada a ${refLabel || refType}`,
        reply_markup: { inline_keyboard: [] }, // Remove botões
      }),
    });
    
  } catch (error) {
    console.error('❌ Erro ao vincular tag:', error);
    throw error;
  }
}

/**
 * Processa mensagem deletada no Telegram e deleta no Supabase
 * NOTA: Bot API não recebe updates quando mensagens são deletadas manualmente pelo usuário.
 * Este método será chamado se implementarmos MTProto/userbot no futuro ou se recebermos
 * notificações de deleção por outros meios.
 * 
 * @param {Object} deletedMessage - Objeto com message_id, chat.id, message_thread_id
 */
async function processDeletedMessage(deletedMessage) {
  try {
    console.log('🗑️ [processDeletedMessage] Processando mensagem deletada no Telegram');
    
    if (!deletedMessage || !deletedMessage.message_id) {
      console.warn('⚠️ [processDeletedMessage] Mensagem deletada sem message_id');
      return;
    }

    const telegramMessageId = deletedMessage.message_id;
    const chatId = deletedMessage.chat?.id;
    const topicId = deletedMessage.message_thread_id;

    console.log(`🔍 [processDeletedMessage] Buscando mensagem: telegram_message_id=${telegramMessageId}, chat_id=${chatId}, topic_id=${topicId || 'N/A'}`);

    // Buscar mensagem no Supabase através dos logs de entrega
    let query = supabase
      .from('telegram_delivery_logs')
      .select('id, mensagem_id, telegram_chat_id, telegram_message_id, telegram_topic_id')
      .eq('telegram_message_id', telegramMessageId)
      .eq('telegram_chat_id', chatId)
      .eq('status', 'sent');

    if (topicId) {
      query = query.eq('telegram_topic_id', topicId);
    }

    const { data: deliveryLog, error: logError } = await query.maybeSingle();

    if (logError) {
      console.error('❌ [processDeletedMessage] Erro ao buscar log de entrega:', logError);
      return;
    }

    if (!deliveryLog || !deliveryLog.mensagem_id) {
      console.warn(`⚠️ [processDeletedMessage] Nenhum log de entrega encontrado para message_id=${telegramMessageId}`);
      return;
    }

    console.log(`✅ [processDeletedMessage] Log encontrado: mensagem_id=${deliveryLog.mensagem_id}`);

    // Usar função centralizada para deletar
    const result = await deleteMessageEverywhere(
      deliveryLog.mensagem_id,
      'telegram', // Origem da deleção
      { softDelete: true }
    );

    if (result.ok && result.deleted) {
      console.log(`✅ [processDeletedMessage] Mensagem ${deliveryLog.mensagem_id} deletada com sucesso`);
      console.log(`   - Deletado do Telegram: ${result.deletedFromTelegram} de ${result.totalTelegramLogs}`);
      console.log(`   - Deletado do Storage: ${result.deletedFromStorage}`);
    } else {
      console.warn(`⚠️ [processDeletedMessage] Não foi possível deletar mensagem:`, result.error || result.reason);
    }
  } catch (error) {
    console.error('❌ [processDeletedMessage] Erro ao processar mensagem deletada:', error);
  }
}

// ==========================================
// ENDPOINTS ADMIN
// ==========================================

// Cadastrar supergrupo Telegram para uma comunidade
app.post('/admin/communities/:id/telegram-chat', async (req, res) => {
  try {
    const { id: communityId } = req.params;
    const { telegram_chat_id } = req.body;

    if (!telegram_chat_id) {
      return res.status(400).json({ error: 'telegram_chat_id é obrigatório' });
    }

    // Verificar se já existe
    const { data: existing } = await supabase
      .from('telegram_communities')
      .select('id')
      .eq('community_id', communityId)
      .maybeSingle();

    let result;
    if (existing) {
      // Atualizar
      const { data, error } = await supabase
        .from('telegram_communities')
        .update({ telegram_chat_id, updated_at: new Date().toISOString() })
        .eq('id', existing.id)
        .select()
        .single();
      
      result = data;
      if (error) throw error;
    } else {
      // Criar
      const { data, error } = await supabase
        .from('telegram_communities')
        .insert({
          community_id: communityId,
          telegram_chat_id,
        })
        .select()
        .single();
      
      result = data;
      if (error) throw error;
    }

    res.json({ ok: true, data: result });
  } catch (error) {
    console.error('❌ Erro ao cadastrar community:', error);
    res.status(500).json({ error: error.message });
  }
});

// Garantir tópico para uma tarefa (manual)
app.post('/tasks/:id/ensure-topic', async (req, res) => {
  try {
    const { id: taskId } = req.params;
    const topic = await ensureTaskTopic(taskId);
    
    if (!topic) {
      return res.status(404).json({ error: 'Não foi possível criar/obter tópico' });
    }

    res.json({ ok: true, data: topic });
  } catch (error) {
    console.error('❌ Erro ao garantir tópico:', error);
    res.status(500).json({ error: error.message });
  }
});

async function notifyTelegramForTrechoAlerts(trechoGeomId, resumoCustom) {
  try {
    const { data: trecho } = await supabase
      .from('trechos_geoms')
      .select('id, ref_type, ref_id, nome')
      .eq('id', trechoGeomId)
      .maybeSingle();

    if (!trecho) {
      return { ok: false, reason: 'Trecho não encontrado' };
    }

    const { data: agregados } = await supabase
      .from('eventos_agregados_trecho')
      .select('*')
      .eq('trecho_geom_id', trechoGeomId);

    const pendentes = (agregados || []).filter(
      (a) => a.ultimo_evento && (!a.last_notified_at || new Date(a.ultimo_evento) > new Date(a.last_notified_at || 0)),
    );

    if (pendentes.length === 0) {
      return { ok: true, sent: false, reason: 'Sem novidades' };
    }

    let destino = null;
    if (trecho.ref_type === 'TASK') {
      destino = await ensureTaskTopic(trecho.ref_id);
    }

    if (!destino) {
      // fallback: subscription direta
      const { data: subscription } = await supabase
        .from('telegram_subscriptions')
        .select('telegram_chat_id, telegram_topic_id')
        .eq('thread_id', trecho.ref_id)
        .eq('active', true)
        .maybeSingle();
      if (subscription) {
        destino = {
          telegram_chat_id: subscription.telegram_chat_id,
          telegram_topic_id: subscription.telegram_topic_id,
        };
      }
    }

    if (!destino) {
      return { ok: false, reason: 'Sem destino Telegram configurado' };
    }

    const title = trecho.nome || `Trecho ${trecho.ref_id}`;
    const linhas = [];
    for (const a of pendentes) {
      const icon = a.tipo_evento === 'queimada' ? '🔥' : '⚡';
      const dist = a.distancia_min_m ? `${Math.round(a.distancia_min_m)} m` : 's/ dist';
      const dt = a.ultimo_evento ? new Date(a.ultimo_evento).toLocaleString('pt-BR') : '';
      linhas.push(`${icon} ${a.window_days}d: ${a.total} (último ${dt}, dist ${dist})`);
    }

    let mensagem = resumoCustom || `🚨 Alertas no trecho ${title}\n${linhas.join('\n')}`;
    if (APP_TRECHO_DEEPLINK) {
      const link = APP_TRECHO_DEEPLINK.replace('{trechoId}', trecho.ref_id).replace('{id}', trecho.ref_id);
      mensagem += `\n\n🔗 Abrir no app: ${link}`;
    }

    const sent = await sendTelegramMessage(destino.telegram_chat_id, mensagem, destino.telegram_topic_id);

    if (sent) {
      await supabase
        .from('eventos_agregados_trecho')
        .update({ last_notified_at: new Date().toISOString() })
        .eq('trecho_geom_id', trechoGeomId)
        .in(
          'tipo_evento',
          pendentes.map((p) => p.tipo_evento),
        );
    }

    return { ok: sent, sent, destino };
  } catch (error) {
    console.error('❌ Erro ao notificar Telegram para trecho:', error);
    return { ok: false, error: error.message };
  }
}

async function notifyPendingTrechoAlerts() {
  const client = await pgPool.connect();
  try {
    const { rows } = await client.query(
      `SELECT DISTINCT trecho_geom_id
       FROM eventos_agregados_trecho
       WHERE ultimo_evento IS NOT NULL
         AND (last_notified_at IS NULL OR ultimo_evento > last_notified_at)`,
    );
    const results = [];
    for (const row of rows) {
      const resp = await notifyTelegramForTrechoAlerts(row.trecho_geom_id);
      results.push({ trecho_geom_id: row.trecho_geom_id, ...resp });
    }
    return results;
  } finally {
    client.release();
  }
}

// ==========================================
// GEOEVENTOS (QUEIMADAS / RAIOS / ALERTAS)
// ==========================================

function getJobToken(req) {
  const header = req.headers.authorization || req.headers['x-api-token'] || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : header;
  return token;
}

function ensureJobAuth(req, res) {
  const token = getJobToken(req);
  if (!token || token !== GEO_JOB_TOKEN) {
    res.status(401).json({ error: 'Unauthorized' });
    return false;
  }
  return true;
}

async function refreshAgregadosMultiWindow({ windows = [7, 30], bufferM = GEO_BUFFER_M }) {
  const results = [];
  for (const w of windows) {
    const r = await geo.refreshAgregados({ pgPool, windowDays: w, bufferM });
    results.push({ window: w, ...r });
  }
  return results;
}

app.post('/jobs/run', async (req, res) => {
  try {
    if (!ensureJobAuth(req, res)) return;
    const { source = 'all', start, end, bufferM = GEO_BUFFER_M } = req.body || {};

    const runQueimadas = source === 'all' || source === 'queimadas';
    const runRaios = source === 'all' || source === 'raios';

    const results = {};
    if (runQueimadas) {
      results.queimadas = await geo.ingestQueimadas({ pgPool });
    }
    if (runRaios) {
    results.raios = await geo.ingestRaios({ pgPool });
    }

    results.agregados = await refreshAgregadosMultiWindow({
      windows: [GEO_WINDOW_DAYS_DEFAULT, 30, GEO_RAIOS_WINDOW_DAYS].filter((v, idx, arr) => arr.indexOf(v) === idx),
      bufferM,
    });

    results.notificacoes = await notifyPendingTrechoAlerts();

    res.json({ ok: true, results });
  } catch (error) {
    console.error('❌ Erro ao rodar job geoeventos:', error);
    res.status(500).json({ error: error.message });
  }
});

app.get('/eventos/queimadas', async (req, res) => {
  try {
    const { bbox, sinceMinutes } = req.query;
    const limit = Math.min(Number(req.query.limit) || 200, 500);
    const offset = Number(req.query.offset) || 0;
    const minutes = Number(sinceMinutes || GEO_WINDOW_DAYS_DEFAULT * 1440);

    // Verificar se temos view kmz_features_geom
    let hasKmzGeom = true;
    try {
      await pgPool.query('SELECT 1 FROM kmz_features_geom LIMIT 1');
    } catch (e) {
      hasKmzGeom = false;
    }

    const clauses = [];
    const params = [];
    params.push(minutes);
    clauses.push(`q.acq_time >= now() - ($${params.length} || ' minutes')::interval`);

    if (bbox) {
      const [minLon, minLat, maxLon, maxLat] = bbox.split(',').map(Number);
      params.push(minLon, minLat, maxLon, maxLat);
      clauses.push(
        `q.geom && ST_MakeEnvelope($${params.length - 3}, $${params.length - 2}, $${params.length - 1}, $${params.length}, 4326)::geography`,
      );
    }

    const where = clauses.length ? `WHERE ${clauses.join(' AND ')}` : '';
    params.push(limit, offset);

    let sql = `
      SELECT
        q.id, q.source, q.acq_time, q.latitude, q.longitude, q.satellite, q.raw
        ${hasKmzGeom ? `,
        nf.feature_id,
        nf.nome as feature_nome,
        nf.is_line as feature_is_line,
        nf.dist_m as feature_dist_m,
        nf.nearest_lat,
        nf.nearest_lon
        ` : ''}
      FROM geo_queimadas q
      ${hasKmzGeom ? `
      LEFT JOIN LATERAL (
        SELECT
          k.id as feature_id,
          k.nome,
          k.is_line,
          ST_Distance(q.geom, k.geom)::double precision as dist_m,
          ST_Y(ST_ClosestPoint(k.geom::geometry, q.geom::geometry)) as nearest_lat,
          ST_X(ST_ClosestPoint(k.geom::geometry, q.geom::geometry)) as nearest_lon
        FROM kmz_features_geom k
        WHERE k.geom IS NOT NULL
        ORDER BY q.geom <-> k.geom
        LIMIT 1
      ) nf ON TRUE
      ` : ''}
      ${where}
      ORDER BY q.acq_time DESC
      LIMIT $${params.length - 1} OFFSET $${params.length}
    `;

    const { rows } = await pgPool.query(sql, params);
    const data = rows.map((r) => ({
      id: r.id,
      source: r.source,
      acq_time: r.acq_time,
      latitude: r.latitude,
      longitude: r.longitude,
      satellite: r.satellite,
      raw: r.raw,
      nearest_feature: hasKmzGeom
        ? {
            feature_id: r.feature_id,
            nome: r.feature_nome,
            is_line: r.feature_is_line,
            distancia_m: r.feature_dist_m,
            nearest_point: r.nearest_lat && r.nearest_lon ? { lat: r.nearest_lat, lon: r.nearest_lon } : null,
          }
        : null,
    }));

    res.json({ ok: true, data, count: data.length });
  } catch (error) {
    console.error('❌ Erro ao listar queimadas:', error);
    res.json({ ok: false, data: [], error: error.message });
  }
});

app.get('/eventos/raios', async (req, res) => {
  try {
    const { bbox, sinceMinutes } = req.query;
    const limit = Math.min(Number(req.query.limit) || 200, 500);
    const offset = Number(req.query.offset) || 0;
    const minutes = Number(sinceMinutes || GEO_WINDOW_DAYS_DEFAULT * 1440);

    // Verificar se temos view kmz_features_geom
    let hasKmzGeom = true;
    try {
      await pgPool.query('SELECT 1 FROM kmz_features_geom LIMIT 1');
    } catch (e) {
      hasKmzGeom = false;
    }

    const clauses = [];
    const params = [];
    params.push(minutes);
    clauses.push(`r.strike_time >= now() - ($${params.length} || ' minutes')::interval`);

    if (bbox) {
      const [minLon, minLat, maxLon, maxLat] = bbox.split(',').map(Number);
      params.push(minLon, minLat, maxLon, maxLat);
      clauses.push(
        `r.geom && ST_MakeEnvelope($${params.length - 3}, $${params.length - 2}, $${params.length - 1}, $${params.length}, 4326)::geography`,
      );
    }

    const where = clauses.length ? `WHERE ${clauses.join(' AND ')}` : '';
    params.push(limit, offset);

    let sql = `
      SELECT
        r.id, r.source, r.strike_time, r.latitude, r.longitude, r.raw
        ${hasKmzGeom ? `,
        nf.feature_id,
        nf.nome as feature_nome,
        nf.is_line as feature_is_line,
        nf.dist_m as feature_dist_m,
        nf.nearest_lat,
        nf.nearest_lon
        ` : ''}
      FROM geo_raios r
      ${hasKmzGeom ? `
      LEFT JOIN LATERAL (
        SELECT
          k.id as feature_id,
          k.nome,
          k.is_line,
          ST_Distance(r.geom, k.geom)::double precision as dist_m,
          ST_Y(ST_ClosestPoint(k.geom::geometry, r.geom::geometry)) as nearest_lat,
          ST_X(ST_ClosestPoint(k.geom::geometry, r.geom::geometry)) as nearest_lon
        FROM kmz_features_geom k
        WHERE k.geom IS NOT NULL
        ORDER BY r.geom <-> k.geom
        LIMIT 1
      ) nf ON TRUE
      ` : ''}
      ${where}
      ORDER BY r.strike_time DESC
      LIMIT $${params.length - 1} OFFSET $${params.length}
    `;

    const { rows } = await pgPool.query(sql, params);
    const data = rows.map((r) => ({
      id: r.id,
      source: r.source,
      strike_time: r.strike_time,
      latitude: r.latitude,
      longitude: r.longitude,
      raw: r.raw,
      nearest_feature: hasKmzGeom
        ? {
            feature_id: r.feature_id,
            nome: r.feature_nome,
            is_line: r.feature_is_line,
            distancia_m: r.feature_dist_m,
            nearest_point: r.nearest_lat && r.nearest_lon ? { lat: r.nearest_lat, lon: r.nearest_lon } : null,
          }
        : null,
    }));

    res.json({ ok: true, data, count: data.length });
  } catch (error) {
    console.error('❌ Erro ao listar raios:', error);
    res.json({ ok: false, data: [], error: error.message });
  }
});

app.get('/trechos/:id/alertas', async (req, res) => {
  try {
    const { id } = req.params; // trecho_geom_id ou ref_id
    const { refId } = req.query;
    let trechoId = id;
    if (refId) {
      const { data: trecho } = await supabase
        .from('trechos_geoms')
        .select('id')
        .eq('ref_id', refId)
        .order('updated_at', { ascending: false })
        .maybeSingle();
      if (trecho?.id) {
        trechoId = trecho.id;
      }
    }

    const alertas = await geo.getTrechoAlertas({ pgPool, trechoId });
    res.json({ ok: true, data: alertas });
  } catch (error) {
    console.error('❌ Erro ao buscar alertas do trecho:', error);
    res.status(500).json({ error: error.message });
  }
});

app.post('/trechos/:id/refresh-alertas', async (req, res) => {
  try {
    if (!ensureJobAuth(req, res)) return;
    const bufferM = Number(req.body?.bufferM || GEO_BUFFER_M);
    const windows = req.body?.windows || [GEO_WINDOW_DAYS_DEFAULT, 30, GEO_RAIOS_WINDOW_DAYS];
    const results = await refreshAgregadosMultiWindow({
      windows: windows.filter((v, idx, arr) => arr.indexOf(v) === idx),
      bufferM,
    });
    res.json({ ok: true, results });
  } catch (error) {
    console.error('❌ Erro ao recalcular alertas do trecho:', error);
    res.status(500).json({ error: error.message });
  }
});

app.post('/trechos/:id/notify', async (req, res) => {
  try {
    if (!ensureJobAuth(req, res)) return;
    const { id } = req.params;
    const resp = await notifyTelegramForTrechoAlerts(id, req.body?.mensagem);
    res.json({ ok: resp.ok, data: resp });
  } catch (error) {
    console.error('❌ Erro ao notificar trecho:', error);
    res.status(500).json({ error: error.message });
  }
});

// Ingestão manual de raios (upload JSON) - útil se não houver feed público
app.post('/eventos/raios/upload', async (req, res) => {
  try {
    if (!ensureJobAuth(req, res)) return;
    const items = Array.isArray(req.body?.items) ? req.body.items : [];
    const result = await geo.ingestRaios({ pgPool, fallbackItems: items });
    res.json({ ok: true, result });
  } catch (error) {
    console.error('❌ Erro no upload de raios:', error);
    res.status(500).json({ error: error.message });
  }
});

// ==========================================
// CRON PARA INGESTÃO AUTOMÁTICA
// ==========================================
if (GEO_CRON_EXPR) {
  cron.schedule(GEO_CRON_EXPR, async () => {
    try {
      console.log(`⏰ Rodando cron geoeventos (${GEO_CRON_EXPR})`);
      await geo.ingestQueimadas({ pgPool });
      await geo.ingestRaios({ pgPool });
      await refreshAgregadosMultiWindow({
        windows: [GEO_WINDOW_DAYS_DEFAULT, 30, GEO_RAIOS_WINDOW_DAYS].filter(
          (v, idx, arr) => arr.indexOf(v) === idx,
        ),
      });
      await notifyPendingTrechoAlerts();
      console.log('✅ Cron geoeventos finalizado');
    } catch (error) {
      console.error('❌ Erro no cron geoeventos:', error);
    }
  });
  console.log(`✅ GEO cron agendado: ${GEO_CRON_EXPR}`);
}

// ==========================================
// LISTEN/NOTIFY (Opcional - para processar em tempo real)
// ==========================================

async function setupListenNotify() {
  try {
    const client = await pgPool.connect();
    
    client.on('notification', async (msg) => {
      if (msg.channel === 'new_message') {
        try {
          const payload = JSON.parse(msg.payload);
          console.log('📨 Nova mensagem detectada via NOTIFY:', payload.id);
          
          // Obter grupo_id e task_id
          const { data: mensagem } = await supabase
            .from('mensagens')
            .select('grupo_id')
            .eq('id', payload.id)
            .single();

          if (mensagem) {
            const taskId = await getTaskIdFromGrupoId(mensagem.grupo_id);
            if (taskId) {
              const topic = await ensureTaskTopic(taskId);
              if (topic) {
                // Enviar para Telegram (mesma lógica do /send-message)
                // TODO: Reutilizar código
              }
            }
          }
        } catch (error) {
          console.error('❌ Erro ao processar NOTIFY:', error);
        }
      }
    });

    await client.query('LISTEN new_message');
    console.log('✅ LISTEN/NOTIFY configurado');
  } catch (error) {
    console.error('❌ Erro ao configurar LISTEN/NOTIFY:', error);
    // Continuar sem LISTEN/NOTIFY (usar polling se necessário)
  }
}

// ==========================================
// INICIAR SERVIDOR
// ==========================================

app.listen(PORT, async () => {
  console.log('==========================================');
  console.log('🚀 TaskFlow Telegram Webhook Server (Generalized)');
  console.log('==========================================');
  console.log(`✅ Servidor rodando na porta ${PORT}`);
  console.log(`📡 Webhook: http://localhost:${PORT}/telegram-webhook`);
    console.log(`🔗 Supabase (interno): ${SUPABASE_URL_INTERNAL}`);
    console.log(`🔗 Supabase (público): ${SUPABASE_URL_PUBLIC}`);
  console.log('==========================================');
  
  // Configurar LISTEN/NOTIFY (opcional)
  // await setupListenNotify();
});
