const axios = require('axios');

const EVENTO_LABELS = {
  SOLICITACAO_CRIADA: {
    categoria: 'SOLICITACAO',
    severidade: 'ATENCAO',
    titulo: 'NOVA SOLICITAÇÃO DE APOIO',
  },
  SOLICITACAO_EM_ANALISE: {
    categoria: 'SOLICITACAO',
    severidade: 'INFO',
    titulo: 'SOLICITAÇÃO EM ANÁLISE',
  },
  SOLICITACAO_ACEITA: {
    categoria: 'DECISAO',
    severidade: 'INFO',
    titulo: 'APOIO ACEITO',
  },
  SOLICITACAO_RECUSADA: {
    categoria: 'DECISAO',
    severidade: 'RISCO',
    titulo: 'APOIO RECUSADO',
  },
  CONTRAPROPOSTA_ENVIADA: {
    categoria: 'NEGOCIACAO',
    severidade: 'ATENCAO',
    titulo: 'CONTRAPROPOSTA DE APOIO',
  },
  CONTRAPROPOSTA_ACEITA: {
    categoria: 'NEGOCIACAO',
    severidade: 'INFO',
    titulo: 'CONTRAPROPOSTA ACEITA',
  },
  SOLICITACAO_CANCELADA: {
    categoria: 'CANCELAMENTO',
    severidade: 'ATENCAO',
    titulo: 'SOLICITAÇÃO CANCELADA',
  },
  ATIVIDADE_APOIO_CRIADA: {
    categoria: 'PROGRAMACAO',
    severidade: 'INFO',
    titulo: 'APOIO PROGRAMADO',
  },
  VINCULO_CRIADO: {
    categoria: 'PROGRAMACAO',
    severidade: 'INFO',
    titulo: 'ATIVIDADE DE APOIO VINCULADA',
  },
  VINCULO_DESATIVADO: {
    categoria: 'PROGRAMACAO',
    severidade: 'ATENCAO',
    titulo: 'VÍNCULO DE APOIO DESATIVADO',
  },
  ATIVIDADE_REPROGRAMADA: {
    categoria: 'ALTERACAO',
    severidade: 'RISCO',
    titulo: 'ATENÇÃO — APOIO OPERACIONAL EM RISCO',
  },
  RECURSO_ATIVIDADE_ALTERADO: {
    categoria: 'ALTERACAO',
    severidade: 'ATENCAO',
    titulo: 'ALTERAÇÃO DE RECURSO NO APOIO',
  },
  ATIVIDADE_CANCELADA: {
    categoria: 'CANCELAMENTO',
    severidade: 'CRITICO',
    titulo: 'ATIVIDADE VINCULADA CANCELADA',
  },
  ATIVIDADE_EXCLUIDA: {
    categoria: 'CANCELAMENTO',
    severidade: 'CRITICO',
    titulo: 'ATIVIDADE VINCULADA EXCLUÍDA',
  },
  APOIO_INICIADO: {
    categoria: 'EXECUCAO',
    severidade: 'INFO',
    titulo: 'APOIO OPERACIONAL INICIADO',
  },
  APOIO_CONCLUIDO: {
    categoria: 'EXECUCAO',
    severidade: 'INFO',
    titulo: 'APOIO OPERACIONAL CONCLUÍDO',
  },
  ALERTA_PRAZO_APOIO: {
    categoria: 'PRAZO',
    severidade: 'ATENCAO',
    titulo: 'ALERTA DE PRAZO — APOIO OPERACIONAL',
  },
};

function formatDateBr(iso) {
  if (!iso) return '-';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return String(iso);
  const dd = String(d.getDate()).padStart(2, '0');
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const hh = String(d.getHours()).padStart(2, '0');
  const mi = String(d.getMinutes()).padStart(2, '0');
  return `${dd}/${mm} ${hh}:${mi}`;
}

async function enqueueOutboxEvent(supabase, {
  modulo = 'APOIOS_OPERACIONAIS',
  eventoTipo,
  entidadeTipo,
  entidadeId,
  solicitacaoId = null,
  taskId = null,
  payload = {},
  idempotencyKey,
}) {
  if (!idempotencyKey) {
    throw new Error('idempotencyKey é obrigatório para enfileirar evento na outbox.');
  }
  const { error } = await supabase
    .from('notificacoes_eventos_outbox')
    .upsert(
      {
        modulo,
        evento_tipo: eventoTipo,
        entidade_tipo: entidadeTipo,
        entidade_id: entidadeId,
        solicitacao_id: solicitacaoId,
        task_id: taskId,
        payload_json: payload,
        idempotency_key: idempotencyKey,
        status: 'PENDENTE',
        proximo_retry_em: new Date().toISOString(),
      },
      { onConflict: 'idempotency_key', ignoreDuplicates: true }
    );
  if (error) {
    console.error('[Outbox] Erro ao enfileirar evento:', error.message);
  }
}

async function resolveDestinatarios(supabase, sol, eventoTipo, payload) {
  const userIds = new Set();
  if (!sol) return [];

  if (sol.solicitante_usuario_id) userIds.add(sol.solicitante_usuario_id);
  if (sol.responsavel_atendimento_id) userIds.add(sol.responsavel_atendimento_id);

  // Unidades alvo conforme natureza do evento (origem + destino com Regional, Divisão e Segmento)
  const incluirOrigem = eventoTipo !== 'SOLICITACAO_CRIADA';
  const unidadesAlvo = [];
  if (incluirOrigem && sol.divisao_solicitante_id) {
    unidadesAlvo.push({
      regionalId: sol.regional_solicitante_id || null,
      divisaoId: sol.divisao_solicitante_id,
      segmentoId: sol.segmento_solicitante_id || null,
    });
  }
  if (sol.divisao_destino_id) {
    unidadesAlvo.push({
      regionalId: sol.regional_destino_id || null,
      divisaoId: sol.divisao_destino_id,
      segmentoId: sol.segmento_destino_id || null,
    });
  }

  if (unidadesAlvo.length > 0) {
    const divAlvos = Array.from(new Set(unidadesAlvo.map((u) => u.divisaoId)));

    // 1. Responsáveis designados para receber solicitações na divisão/segmento
    const { data: resps } = await supabase
      .from('tasks_apoios_unidade_responsaveis')
      .select('usuario_id, regional_id, divisao_id, segmento_id')
      .in('divisao_id', divAlvos)
      .eq('ativo', true);

    const respUserIds = (resps || []).map((r) => r.usuario_id).filter(Boolean);
    const respAtivosSet = new Set();
    if (respUserIds.length > 0) {
      const { data: respAtivos } = await supabase
        .from('usuarios')
        .select('id')
        .in('id', respUserIds)
        .eq('ativo', true);
      for (const u of respAtivos || []) respAtivosSet.add(u.id);
    }

    const divsComResp = new Set();
    for (const r of resps || []) {
      if (!respAtivosSet.has(r.usuario_id)) continue;
      const alvo = unidadesAlvo.find((u) => u.divisaoId === r.divisao_id);
      if (!alvo) continue;
      if (alvo.regionalId && r.regional_id && r.regional_id !== alvo.regionalId) continue;
      if (alvo.segmentoId && r.segmento_id && r.segmento_id !== alvo.segmentoId) continue;
      userIds.add(r.usuario_id);
      divsComResp.add(r.divisao_id);
    }

    // 2. Fallback por perfil exato: Regional + Divisão + Segmento
    for (const alvo of unidadesAlvo) {
      if (divsComResp.has(alvo.divisaoId)) continue;

      const { data: uDivs } = await supabase
        .from('usuarios_divisoes')
        .select('usuario_id')
        .eq('divisao_id', alvo.divisaoId);

      let candidatos = (uDivs || []).map((ud) => ud.usuario_id).filter(Boolean);
      if (candidatos.length === 0) continue;

      if (alvo.regionalId) {
        const { data: uRegs } = await supabase
          .from('usuarios_regionais')
          .select('usuario_id')
          .eq('regional_id', alvo.regionalId)
          .in('usuario_id', candidatos);
        candidatos = (uRegs || []).map((r) => r.usuario_id).filter(Boolean);
      }

      if (alvo.segmentoId && candidatos.length > 0) {
        const { data: uSegs } = await supabase
          .from('usuarios_segmentos')
          .select('usuario_id')
          .eq('segmento_id', alvo.segmentoId)
          .in('usuario_id', candidatos);
        candidatos = (uSegs || []).map((s) => s.usuario_id).filter(Boolean);
      }

      for (const uid of candidatos) {
        userIds.add(uid);
      }
    }
  }

  const ids = Array.from(userIds).filter(Boolean);
  if (ids.length === 0) return [];

  // Filtrar apenas usuários ativos e remover o próprio ator do evento se desejado
  const { data: ativos } = await supabase
    .from('usuarios')
    .select('id')
    .in('id', ids)
    .eq('ativo', true);

  const atorId = payload?.ator_usuario_id;
  return (ativos || [])
    .map((u) => u.id)
    .filter((id) => !atorId || id !== atorId || ids.length === 1);
}

function buildMensagemNotificacao(eventoTipo, sol, payload) {
  const meta = EVENTO_LABELS[eventoTipo] || {
    categoria: 'APOIO',
    severidade: 'INFO',
    titulo: eventoTipo,
  };
  const atividade = sol?.task_solicitante_titulo_snapshot || payload?.tarefa || 'Atividade operacional';
  const necessidade = sol?.descricao || payload?.necessidade || 'Apoio operacional';
  const periodoSol = sol
    ? `${formatDateBr(sol.data_inicio_solicitada)} a ${formatDateBr(sol.data_fim_solicitada)}`
    : `${formatDateBr(payload?.data_inicio_nova)} a ${formatDateBr(payload?.data_fim_nova)}`;

  let corpo = '';
  switch (eventoTipo) {
    case 'SOLICITACAO_CRIADA':
      corpo =
        `Atividade: ${atividade}\n` +
        `Necessidade: ${necessidade}\n` +
        `Período necessário: ${periodoSol}\n` +
        `Criticidade: ${sol?.criticidade || 'ESSENCIAL'}\n` +
        `Situação: Aguardando resposta. Consultar no TaskFlow.`;
      break;
    case 'SOLICITACAO_ACEITA':
      corpo =
        `A unidade prestadora aceitou a solicitação: ${necessidade}.\n` +
        `Período acordado: ${formatDateBr(sol?.data_inicio_acordada || sol?.data_inicio_solicitada)} a ${formatDateBr(sol?.data_fim_acordada || sol?.data_fim_solicitada)}\n` +
        `Situação: Aguardando programação da atividade de apoio.`;
      break;
    case 'SOLICITACAO_RECUSADA':
      corpo =
        `Solicitação recusada: ${necessidade}.\n` +
        `Justificativa: ${sol?.justificativa_decisao || payload?.justificativa || 'Não informada.'}`;
      break;
    case 'CONTRAPROPOSTA_ENVIADA':
      corpo =
        `Nova contraproposta para ${necessidade}.\n` +
        `Período proposto: ${formatDateBr(sol?.contraproposta_inicio)} a ${formatDateBr(sol?.contraproposta_fim)}\n` +
        `Motivo: ${sol?.contraproposta_justificativa || 'Ajuste de disponibilidade.'}`;
      break;
    case 'ATIVIDADE_APOIO_CRIADA':
    case 'VINCULO_CRIADO':
      corpo =
        `Atividade de apoio vinculada para ${necessidade}.\n` +
        `Atividade principal: ${atividade}\n` +
        `Situação: Apoio programado.`;
      break;
    case 'ATIVIDADE_REPROGRAMADA':
      corpo =
        `A atividade "${payload?.tarefa || atividade}" foi alterada para ${formatDateBr(payload?.data_inicio_nova)} a ${formatDateBr(payload?.data_fim_nova)}.\n` +
        `Providência: verificar compatibilidade e reconfirmar o atendimento no TaskFlow.`;
      break;
    case 'ATIVIDADE_CANCELADA':
    case 'ATIVIDADE_EXCLUIDA':
    case 'SOLICITACAO_CANCELADA':
      corpo =
        `Ocorrência de cancelamento/exclusão em "${payload?.tarefa || atividade}" (${necessidade}).\n` +
        `Verifique o impacto nos compromissos vinculados.`;
      break;
    case 'ALERTA_PRAZO_APOIO':
      corpo =
        `${payload?.motivo || 'Solicitação próxima do prazo sem confirmação/programação.'}\n` +
        `Atividade: ${atividade} (${periodoSol}).`;
      break;
    default:
      corpo = `${necessidade} — ${atividade} (${periodoSol}).`;
  }

  return {
    categoria: meta.categoria,
    severidade: meta.severidade,
    titulo: meta.titulo,
    mensagem: corpo,
  };
}

async function enviarTelegramSeguro({ botToken, chatId, topicId, text, telegramApiUrl }) {
  if (!botToken || !chatId) {
    return { sent: false, skipped: true, reason: 'Telegram não configurado para esta unidade.' };
  }
  const base = telegramApiUrl || `https://api.telegram.org/bot${botToken}`;
  const url = telegramApiUrl ? telegramApiUrl : `${base}/sendMessage`;
  const body = {
    chat_id: chatId,
    text,
    ...(topicId ? { message_thread_id: Number(topicId) } : {}),
  };
  const resp = await axios.post(url, body, { timeout: 5000 });
  if (resp.status >= 200 && resp.status < 300) {
    return { sent: true };
  }
  throw new Error(`Telegram HTTP ${resp.status}`);
}

function createApoiosNotificacoesWorker(supabase, options = {}) {
  const telegramBotToken = options.telegramBotToken || process.env.TELEGRAM_BOT_TOKEN || '';
  const telegramApiUrl = options.telegramApiUrl || process.env.APOIOS_TELEGRAM_API_URL || '';
  let inFlightPromise = null;
  let outboxTimer = null;
  let prazoTimer = null;

  async function processSingleOutboxItem(item) {
    let sol = null;
    if (item.solicitacao_id) {
      const { data } = await supabase
        .from('tasks_apoios_solicitacoes')
        .select('*')
        .eq('id', item.solicitacao_id)
        .maybeSingle();
      sol = data;
    }

    const payload = item.payload_json || {};
    const msgSpec = buildMensagemNotificacao(item.evento_tipo, sol, payload);

    // 1. Criar Notificação Interna idempotente
    const { data: notif, error: notifErr } = await supabase
      .from('notificacoes_internas')
      .upsert(
        {
          modulo: item.modulo || 'APOIOS_OPERACIONAIS',
          categoria: msgSpec.categoria,
          evento_tipo: item.evento_tipo,
          severidade: msgSpec.severidade,
          titulo: msgSpec.titulo,
          mensagem: msgSpec.mensagem,
          entidade_tipo: item.entidade_tipo,
          entidade_id: item.entidade_id,
          task_id: item.task_id || sol?.task_solicitante_id || null,
          solicitacao_id: item.solicitacao_id,
          unidade_origem_id: sol?.divisao_solicitante_id || null,
          unidade_destino_id: sol?.divisao_destino_id || null,
          ator_usuario_id: payload.ator_usuario_id || null,
          ator_nome: payload.ator_nome || null,
          metadata_json: payload,
          idempotency_key: `NOTIF:${item.idempotency_key}`,
        },
        { onConflict: 'idempotency_key' }
      )
      .select('*')
      .single();

    if (notifErr) {
      throw new Error(`Falha ao gravar notificacoes_internas: ${notifErr.message}`);
    }

    // 2. Resolver destinatários no backend e respeitar preferências individuais
    const destinatarios = await resolveDestinatarios(supabase, sol, item.evento_tipo, payload);
    if (destinatarios.length > 0) {
      const { data: prefsUser } = await supabase
        .from('notificacoes_preferencias')
        .select('usuario_id, receber_interna, eventos_habilitados')
        .eq('escopo', 'USUARIO')
        .eq('modulo', 'APOIOS_OPERACIONAIS')
        .in('usuario_id', destinatarios);

      const prefMap = new Map((prefsUser || []).map((p) => [p.usuario_id, p]));
      const destRows = [];
      const entregaRows = [];

      for (const uid of destinatarios) {
        const pref = prefMap.get(uid);
        const aceitaInterna = pref ? pref.receber_interna !== false : true;
        if (!aceitaInterna && msgSpec.severidade !== 'CRITICO') {
          entregaRows.push({
            outbox_id: item.id,
            notificacao_id: notif.id,
            canal: 'INTERNO',
            usuario_id: uid,
            status: 'IGNORADO_PREF',
            idempotency_key: `ENT:INT:${item.id}:${uid}`,
          });
          continue;
        }
        destRows.push({
          notificacao_id: notif.id,
          usuario_id: uid,
          lida: false,
        });
        entregaRows.push({
          outbox_id: item.id,
          notificacao_id: notif.id,
          canal: 'INTERNO',
          usuario_id: uid,
          status: 'ENVIADO',
          enviado_em: new Date().toISOString(),
          idempotency_key: `ENT:INT:${item.id}:${uid}`,
        });
      }

      if (destRows.length > 0) {
        await supabase
          .from('notificacoes_destinatarios')
          .upsert(destRows, { onConflict: 'notificacao_id,usuario_id', ignoreDuplicates: true });
      }
      if (entregaRows.length > 0) {
        await supabase
          .from('notificacoes_entregas')
          .upsert(entregaRows, { onConflict: 'idempotency_key', ignoreDuplicates: true });
      }
    }

    // 3. Canal Telegram (configurável por unidade / tópico, isolado para não bloquear operação)
    if (sol && (sol.divisao_destino_id || sol.divisao_solicitante_id)) {
      const unidades = [sol.divisao_destino_id, sol.divisao_solicitante_id].filter(Boolean);
      const { data: prefsUnidade } = await supabase
        .from('notificacoes_preferencias')
        .select('*')
        .eq('escopo', 'UNIDADE')
        .eq('modulo', 'APOIOS_OPERACIONAIS')
        .in('divisao_id', unidades);

      const chatTargets = [];
      for (const pu of prefsUnidade || []) {
        if (pu.receber_telegram && pu.telegram_chat_id_destino) {
          chatTargets.push({ chatId: pu.telegram_chat_id_destino, topicId: null });
        }
      }

      // Reutilizar tópico Telegram existente da tarefa principal, se houver e unidade não tiver desativado
      const algumDesativou = (prefsUnidade || []).some((pu) => pu.receber_telegram === false);
      if (chatTargets.length === 0 && !algumDesativou && sol.task_solicitante_id) {
        const { data: topic } = await supabase
          .from('telegram_task_topics')
          .select('telegram_chat_id, telegram_topic_id')
          .eq('task_id', sol.task_solicitante_id)
          .maybeSingle();
        if (topic?.telegram_chat_id) {
          chatTargets.push({
            chatId: topic.telegram_chat_id,
            topicId: topic.telegram_topic_id,
          });
        }
      }

      for (const target of chatTargets) {
        const entKey = `ENT:TG:${item.id}:${target.chatId}:${target.topicId || '0'}`;
        try {
          const text = `${msgSpec.titulo}\n\n${msgSpec.mensagem}`;
          const resTg = await enviarTelegramSeguro({
            botToken: telegramBotToken,
            chatId: target.chatId,
            topicId: target.topicId,
            text,
            telegramApiUrl,
          });
          await supabase.from('notificacoes_entregas').upsert(
            {
              outbox_id: item.id,
              notificacao_id: notif.id,
              canal: 'TELEGRAM',
              destino_referencia: String(target.chatId),
              status: resTg.sent ? 'ENVIADO' : 'IGNORADO_PREF',
              erro_mensagem: resTg.reason || null,
              enviado_em: resTg.sent ? new Date().toISOString() : null,
              idempotency_key: entKey,
            },
            { onConflict: 'idempotency_key', ignoreDuplicates: true }
          );
        } catch (tgErr) {
          await supabase.from('notificacoes_entregas').upsert(
            {
              outbox_id: item.id,
              notificacao_id: notif.id,
              canal: 'TELEGRAM',
              destino_referencia: String(target.chatId),
              status: 'FALHA_TEMP',
              erro_mensagem: tgErr.message,
              idempotency_key: entKey,
            },
            { onConflict: 'idempotency_key' }
          );
          throw new Error(`Falha Telegram (retry agendado): ${tgErr.message}`);
        }
      }
    }
  }

  async function processOutboxQueue(limit = 30) {
    if (inFlightPromise) {
      return inFlightPromise;
    }
    inFlightPromise = _runOutboxQueue(limit).finally(() => {
      inFlightPromise = null;
    });
    return inFlightPromise;
  }

  async function _runOutboxQueue(limit = 30) {
    let processed = 0;
    let failed = 0;

    try {
      const nowIso = new Date().toISOString();
      const { data: items, error } = await supabase
        .from('notificacoes_eventos_outbox')
        .select('*')
        .in('status', ['PENDENTE', 'ERRO_TEMP'])
        .lte('proximo_retry_em', nowIso)
        .order('created_at', { ascending: true })
        .limit(limit);

      if (error || !items || items.length === 0) {
        return { processed: 0, failed: 0 };
      }

      for (const item of items) {
        await supabase
          .from('notificacoes_eventos_outbox')
          .update({ status: 'PROCESSANDO', updated_at: new Date().toISOString() })
          .eq('id', item.id)
          .in('status', ['PENDENTE', 'ERRO_TEMP']);

        try {
          await processSingleOutboxItem(item);
          await supabase
            .from('notificacoes_eventos_outbox')
            .update({
              status: 'PROCESSADO',
              processado_em: new Date().toISOString(),
              ultimo_erro: null,
              updated_at: new Date().toISOString(),
            })
            .eq('id', item.id);
          processed++;
        } catch (err) {
          const tentativas = (item.tentativas || 0) + 1;
          const maxTent = item.max_tentativas || 5;
          const permanente = tentativas >= maxTent;
          const backoffSec = Math.min(15 * Math.pow(2, tentativas - 1), 900);
          const nextRetry = new Date(Date.now() + backoffSec * 1000).toISOString();

          await supabase
            .from('notificacoes_eventos_outbox')
            .update({
              status: permanente ? 'FALHA_PERMANENTE' : 'ERRO_TEMP',
              tentativas,
              proximo_retry_em: nextRetry,
              ultimo_erro: err.message,
              updated_at: new Date().toISOString(),
            })
            .eq('id', item.id);
          failed++;
        }
      }
      return { processed, failed };
    } catch (e) {
      return { processed, failed, error: e.message };
    }
  }

  async function verificarAlertasDePrazo() {
    const now = new Date();
    const { data: sols } = await supabase
      .from('tasks_apoios_solicitacoes')
      .select('*')
      .eq('ativo', true)
      .in('status', ['PENDENTE', 'EM_ANALISE', 'CONTRAPROPOSTA', 'ACEITA']);

    let gerados = 0;
    for (const sol of sols || []) {
      const inicio = new Date(sol.data_inicio_solicitada);
      const diffDias = Math.ceil((inicio.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
      let motivo = null;
      let bucket = null;

      if (sol.prazo_resposta && new Date(sol.prazo_resposta) < now && sol.status !== 'ACEITA') {
        motivo = 'Prazo de resposta ultrapassado.';
        bucket = 'PRAZO_EXPIRADO';
      } else if (sol.status !== 'ACEITA' && [7, 3, 1, 0].includes(diffDias)) {
        motivo = `Apoio ${sol.criticidade} a ${diffDias} dia(s) da execução ainda sem aceite.`;
        bucket = `SEM_ACEITE_${diffDias}D`;
      } else if (sol.status === 'ACEITA' && [3, 1, 0].includes(diffDias)) {
        const { count } = await supabase
          .from('tasks_apoios_vinculos')
          .select('id', { count: 'exact', head: true })
          .eq('solicitacao_id', sol.id)
          .eq('ativo', true);
        if ((count || 0) === 0) {
          motivo = `Apoio aceito a ${diffDias} dia(s) da execução ainda sem atividade vinculada.`;
          bucket = `ACEITO_SEM_PROG_${diffDias}D`;
        }
      }

      if (motivo && bucket) {
        const diaStr = now.toISOString().slice(0, 10);
        await enqueueOutboxEvent(supabase, {
          eventoTipo: 'ALERTA_PRAZO_APOIO',
          entidadeTipo: 'SOLICITACAO',
          entidadeId: sol.id,
          solicitacaoId: sol.id,
          taskId: sol.task_solicitante_id,
          payload: { motivo, bucket, dias_restantes: diffDias },
          idempotencyKey: `PRAZO:${sol.id}:${bucket}:${diaStr}`,
        });
        gerados++;
      }
    }
    if (gerados > 0) {
      await processOutboxQueue();
    }
    return { gerados };
  }

  function start({ outboxIntervalMs = 15000, prazoIntervalMs = 300000 } = {}) {
    // Recuperação imediata após reinicialização do servidor
    setTimeout(() => {
      processOutboxQueue().catch((e) => console.error('[Outbox] Init:', e.message));
    }, 1000);

    outboxTimer = setInterval(() => {
      processOutboxQueue().catch((e) => console.error('[Outbox] Tick:', e.message));
    }, outboxIntervalMs);

    prazoTimer = setInterval(() => {
      verificarAlertasDePrazo().catch((e) => console.error('[Outbox] Prazo:', e.message));
    }, prazoIntervalMs);
  }

  function stop() {
    if (outboxTimer) clearInterval(outboxTimer);
    if (prazoTimer) clearInterval(prazoTimer);
  }

  return {
    enqueueOutboxEvent,
    processOutboxQueue,
    verificarAlertasDePrazo,
    start,
    stop,
  };
}

module.exports = {
  createApoiosNotificacoesWorker,
  enqueueOutboxEvent,
};
