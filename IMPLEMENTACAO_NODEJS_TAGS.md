# ✅ Implementação Node.js: Tags Nota/Ordem

## 🎯 O que foi implementado

### 1. ✅ Endpoint `/send-message`

**Localização:** `telegram-webhook-server-generalized.js` (linha ~1309)

**Funcionalidades adicionadas:**

1. **Processamento de Tags:**
   - Aceita `ref_type`, `ref_id`, `ref_label` no payload (opcional, para compatibilidade)
   - Se não fornecido no payload, busca da mensagem no banco
   - Valida se `ref_id` existe (se fornecido)
   - Gera `ref_label` automaticamente se não fornecido:
     - Para NOTA: Busca `notas_sap.nota` e gera `NOTA {numero}`
     - Para ORDEM: Busca `ordens.ordem` e gera `ORDEM {numero}`

2. **Formatação de Mensagem Telegram:**
   - Adiciona prefixo baseado no `ref_type`:
     - `GERAL`: `💬 GERAL\n\n`
     - `NOTA`: `📌 NOTA {numero}\n\n`
     - `ORDEM`: `🧾 ORDEM {numero}\n\n`
   - Prefixo é adicionado antes do conteúdo da mensagem
   - Para mídia, prefixo vai no `caption`

3. **Resposta do Endpoint:**
   - Inclui `ref_type`, `ref_id`, `ref_label` na resposta JSON
   - Mantém compatibilidade com versões antigas

### 2. ✅ Função `processMessage` (Telegram → Supabase)

**Localização:** `telegram-webhook-server-generalized.js` (linha ~1885)

**Funcionalidades adicionadas:**

1. **Tags para Mensagens do Telegram:**
   - Sempre define `ref_type = 'GERAL'` para mensagens do Telegram
   - `ref_id = NULL`
   - `ref_label = NULL`
   - Mensagens do Telegram não podem ser vinculadas a Nota/Ordem

## 📝 Código Implementado

### Endpoint `/send-message`

```javascript
// 4. Processar tags Nota/Ordem (se houver)
let refType = mensagem.ref_type || 'GERAL';
let refId = mensagem.ref_id || null;
let refLabel = mensagem.ref_label || null;

// Se ref_type foi fornecido no payload, usar (compatibilidade)
if (req.body.ref_type) {
  refType = req.body.ref_type;
  refId = req.body.ref_id || null;
  refLabel = req.body.ref_label || null;
}

// Validar e gerar ref_label se necessário
if (refType && refType !== 'GERAL' && refId) {
  if (refType === 'NOTA') {
    const { data: nota } = await supabase
      .from('notas_sap')
      .select('id, nota')
      .eq('id', refId)
      .maybeSingle();
    
    if (!nota) {
      refType = 'GERAL';
      refId = null;
      refLabel = null;
    } else if (!refLabel) {
      refLabel = `NOTA ${nota.nota}`;
    }
  } else if (refType === 'ORDEM') {
    const { data: ordem } = await supabase
      .from('ordens')
      .select('id, ordem')
      .eq('id', refId)
      .maybeSingle();
    
    if (!ordem) {
      refType = 'GERAL';
      refId = null;
      refLabel = null;
    } else if (!refLabel) {
      refLabel = `ORDEM ${ordem.ordem}`;
    }
  }
}

// Formatar mensagem com prefixo
let prefixo = '';
if (refType === 'NOTA' && refLabel) {
  prefixo = `📌 ${refLabel}\n\n`;
} else if (refType === 'ORDEM' && refLabel) {
  prefixo = `🧾 ${refLabel}\n\n`;
} else {
  prefixo = `💬 GERAL\n\n`;
}

let text = prefixo + `<b>${mensagem.usuario_nome || 'Usuário'}:</b>\n${mensagem.conteudo}`;
```

### Função `processMessage`

```javascript
const mensagemData = {
  grupo_id: taskMapping.grupo_chat_id,
  usuario_id: identity.user_id,
  usuario_nome: usuarioNome,
  conteudo,
  tipo,
  arquivo_url: arquivoUrl,
  source: 'telegram',
  // Mensagens do Telegram sempre são GERAL
  ref_type: 'GERAL',
  ref_id: null,
  ref_label: null,
  telegram_metadata: { /* ... */ },
};
```

## 🔄 Fluxo Completo

### Flutter → Telegram

1. Flutter envia mensagem com tags via `/send-message`
2. Node.js busca mensagem no banco (já tem tags salvas)
3. Node.js valida `ref_id` se fornecido
4. Node.js gera `ref_label` se não fornecido
5. Node.js formata mensagem com prefixo
6. Node.js envia para Telegram com prefixo formatado
7. Node.js retorna resposta com tags

### Telegram → Flutter

1. Usuário envia mensagem no Telegram
2. Telegram envia webhook para `/telegram-webhook`
3. Node.js processa via `processMessage`
4. Node.js insere no Supabase com `ref_type = 'GERAL'`
5. Flutter recebe via Realtime com tag GERAL

## ✅ Compatibilidade

- ✅ **Backward Compatible:** Endpoint aceita payloads antigos (sem tags)
- ✅ **Forward Compatible:** Se tags não fornecidas, busca da mensagem no banco
- ✅ **Validação Robusta:** Se `ref_id` inválido, usa GERAL automaticamente
- ✅ **Geração Automática:** Gera `ref_label` se não fornecido

## 🧪 Testes Recomendados

1. **Enviar mensagem com tag NOTA:**
   - Verificar se prefixo aparece no Telegram
   - Verificar se resposta inclui tags

2. **Enviar mensagem com tag ORDEM:**
   - Verificar se prefixo aparece no Telegram
   - Verificar se resposta inclui tags

3. **Enviar mensagem GERAL:**
   - Verificar se prefixo "GERAL" aparece
   - Verificar compatibilidade

4. **Enviar mensagem do Telegram:**
   - Verificar se aparece como GERAL no Flutter
   - Verificar se não tem tags vinculadas

5. **Enviar com ref_id inválido:**
   - Verificar se usa GERAL automaticamente
   - Verificar logs de warning

## 📋 Próximos Passos

1. ✅ **Node.js implementado**
2. ⏭️ **Fazer deploy do servidor Node.js**
3. ⏭️ **Testar fluxo completo**
4. ⏭️ **Verificar logs do servidor**

## 🚀 Deploy

Para fazer deploy:

```bash
# No servidor
cd /root/telegram-webhook
# Fazer backup
cp telegram-webhook-server-generalized.js telegram-webhook-server-generalized.js.backup
# Copiar novo arquivo (ou fazer git pull)
# Reiniciar serviço
systemctl restart telegram-webhook
# ou
pm2 restart telegram-webhook
```

## ✅ Status

- ✅ **Flutter**: Implementado
- ✅ **Supabase**: Migração executada
- ✅ **Node.js**: Implementado

**Próximo passo:** Fazer deploy e testar! 🎯
