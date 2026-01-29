# ✅ Checklist de Testes - Integração Telegram

## 📋 Pré-requisitos

- [ ] Bot criado no Telegram via @BotFather
- [ ] Token do bot obtido e guardado
- [ ] Supabase configurado (project URL e service_role key)
- [ ] Migration executada com sucesso
- [ ] Edge Functions deployed (telegram-webhook e telegram-send)
- [ ] Webhook configurado no Telegram
- [ ] Variáveis de ambiente configuradas no Supabase

---

## 🔗 Testes de Vinculação

### ✅ Vincular Conta

**Passo a passo:**
1. [ ] Abrir app Flutter
2. [ ] Navegar para qualquer chat
3. [ ] Clicar no ícone Telegram (⚡️) no AppBar
4. [ ] Dialog de configuração abre corretamente
5. [ ] Status mostra "Conta não vinculada"
6. [ ] Clicar em "Vincular"
7. [ ] Dialog com link é exibido
8. [ ] Link tem formato correto: `https://t.me/bot?start=link_USERID`
9. [ ] Copiar link (botão "Copiar Link" funciona)
10. [ ] Abrir link no Telegram
11. [ ] Bot responde com mensagem de boas-vindas
12. [ ] Bot confirma vinculação: "✅ Conta vinculada com sucesso!"
13. [ ] Voltar ao app e reabrir dialog
14. [ ] Status agora mostra "Conta vinculada" com @username

**Validar no banco:**
```sql
SELECT * FROM telegram_identities 
WHERE user_id = 'SEU_USER_ID';
```

- [ ] Registro criado
- [ ] `telegram_user_id` correto
- [ ] `telegram_username` correto
- [ ] `last_chat_id` preenchido

### ✅ Desvincular Conta

1. [ ] No Telegram, enviar `/desvincular` ao bot
2. [ ] Bot confirma: "✅ Conta desvinculada"
3. [ ] No app, reabrir dialog Telegram
4. [ ] Status volta a "Conta não vinculada"

---

## 📡 Testes de Subscription

### ✅ Criar Subscription - Grupo com Tópicos

**Preparação:**
1. [ ] Criar supergrupo no Telegram
2. [ ] Adicionar bot como administrador
3. [ ] Habilitar fórum (tópicos) no grupo
4. [ ] Criar um tópico de teste
5. [ ] Obter Chat ID usando @userinfobot
6. [ ] Obter Topic ID (da URL ou bot)

**Teste:**
1. [ ] No app, abrir dialog Telegram de um chat
2. [ ] Clicar em "+" (Adicionar espelhamento)
3. [ ] Selecionar modo: "Grupo com tópicos"
4. [ ] Inserir Chat ID (ex: `-1001234567890`)
5. [ ] Inserir Topic ID (ex: `123`)
6. [ ] Clicar em "Ativar"
7. [ ] Mensagem de sucesso: "Espelhamento ativado com sucesso!"
8. [ ] Lista mostra a subscription criada

**Validar no banco:**
```sql
SELECT * FROM telegram_subscriptions 
WHERE thread_id = 'SEU_GRUPO_ID';
```

- [ ] Registro criado
- [ ] `thread_type` = 'TASK'
- [ ] `mode` = 'group_topic'
- [ ] `telegram_chat_id` correto
- [ ] `telegram_topic_id` correto
- [ ] `active` = true

### ✅ Criar Subscription - Grupo Simples

1. [ ] Criar grupo normal no Telegram
2. [ ] Adicionar bot ao grupo
3. [ ] Obter Chat ID
4. [ ] No app, criar subscription modo "Grupo simples"
5. [ ] Não preencher Topic ID
6. [ ] Verificar criação

### ✅ Criar Subscription - DM

1. [ ] Abrir chat privado com o bot
2. [ ] Enviar `/start` (se ainda não vinculou)
3. [ ] Obter Chat ID (é o próprio user_id positivo)
4. [ ] No app, criar subscription modo "Mensagem direta"
5. [ ] Verificar criação

### ✅ Remover Subscription

1. [ ] Na lista de subscriptions, clicar em ❌ (delete)
2. [ ] Confirmar remoção
3. [ ] Mensagem: "Espelhamento removido"
4. [ ] Subscription desaparece da lista

**Validar no banco:**
```sql
SELECT active FROM telegram_subscriptions WHERE id = 'SUBSCRIPTION_ID';
```

- [ ] `active` = false

---

## 📤 Testes de Envio (App → Telegram)

### ✅ Mensagem de Texto

1. [ ] No app, enviar mensagem de texto simples
2. [ ] Mensagem aparece imediatamente no app (optimistic update)
3. [ ] Verificar no Telegram: mensagem aparece no grupo/tópico correto
4. [ ] Formato: `**Nome do Usuário:**\nTexto da mensagem`

### ✅ Mensagem com Emoji

1. [ ] Enviar mensagem com emojis: "Olá! 👋😊"
2. [ ] Verificar no Telegram: emojis aparecem corretamente

### ✅ Mensagem com Menção

1. [ ] Enviar mensagem com @menção
2. [ ] Verificar no Telegram: menção é preservada

### ✅ Resposta a Mensagem

1. [ ] Responder uma mensagem no app
2. [ ] Verificar no Telegram: resposta é enviada (sem quote ainda)

### ✅ Imagem

1. [ ] Enviar imagem do app
2. [ ] Verificar no Telegram: imagem aparece
3. [ ] Caption (se houver) está correto

### ✅ Vídeo

1. [ ] Enviar vídeo do app
2. [ ] Verificar no Telegram: vídeo aparece

### ✅ Áudio

1. [ ] Enviar/gravar áudio no app
2. [ ] Verificar no Telegram: áudio aparece e é reproduzível

### ✅ Documento

1. [ ] Enviar documento (PDF, Excel, etc.)
2. [ ] Verificar no Telegram: documento aparece com nome correto

### ✅ Localização

1. [ ] Compartilhar localização no app
2. [ ] Verificar no Telegram: localização é enviada
3. [ ] Clicar na localização: abre no mapa

---

## 📥 Testes de Recebimento (Telegram → App)

### ✅ Mensagem de Texto

1. [ ] No Telegram, enviar mensagem de texto no grupo/tópico configurado
2. [ ] No app, abrir o chat correspondente
3. [ ] Mensagem aparece em tempo real
4. [ ] Nome do autor está correto
5. [ ] Timestamp está correto

### ✅ Mensagem com Emoji

1. [ ] No Telegram, enviar: "Teste 🚀🎉"
2. [ ] Verificar no app: emojis aparecem corretamente

### ✅ Imagem

1. [ ] No Telegram, enviar uma imagem
2. [ ] Verificar no app: imagem é exibida
3. [ ] Clicar na imagem: abre em tela cheia

### ✅ Vídeo

1. [ ] No Telegram, enviar vídeo
2. [ ] Verificar no app: preview com botão play
3. [ ] Clicar: abre player

### ✅ Áudio/Voice

1. [ ] No Telegram, enviar áudio ou voice note
2. [ ] Verificar no app: player de áudio aparece
3. [ ] Clicar: reproduz

### ✅ Documento

1. [ ] No Telegram, enviar documento
2. [ ] Verificar no app: aparece com ícone e nome
3. [ ] Clicar: abre/faz download

### ✅ Localização

1. [ ] No Telegram, compartilhar localização
2. [ ] Verificar no app: widget de localização com coordenadas
3. [ ] Clicar "Abrir no mapa": abre Google Maps

### ✅ Edição de Mensagem

1. [ ] No Telegram, enviar mensagem
2. [ ] Esperar aparecer no app
3. [ ] No Telegram, editar a mensagem
4. [ ] Verificar no app: mensagem é atualizada
5. [ ] Label "editado" aparece no app

---

## 🔄 Testes de Bidirecionalidade

### ✅ Conversa Completa

1. [ ] Usuário A envia mensagem no app
2. [ ] Mensagem aparece no Telegram
3. [ ] Usuário B responde no Telegram
4. [ ] Resposta aparece no app
5. [ ] Usuário A responde no app
6. [ ] Mensagem aparece no Telegram
7. [ ] Repetir ciclo várias vezes

### ✅ Múltiplos Usuários

1. [ ] 3+ usuários enviando mensagens simultaneamente
2. [ ] Alguns no app, outros no Telegram
3. [ ] Todas as mensagens chegam corretamente
4. [ ] Ordem cronológica preservada
5. [ ] Nomes dos autores corretos

---

## 🚫 Testes de Segurança

### ✅ Webhook sem Secret Token

1. [ ] Fazer POST para webhook sem header `x-telegram-bot-api-secret-token`
2. [ ] Verificar resposta: 401 Unauthorized
3. [ ] Mensagem não é processada

### ✅ Usuário Não Vinculado

1. [ ] Criar conta Telegram nova (não vinculada)
2. [ ] Enviar mensagem no grupo configurado
3. [ ] Bot responde: "Sua conta Telegram ainda não está vinculada..."
4. [ ] Mensagem não é salva no banco

### ✅ Grupo Sem Subscription

1. [ ] Adicionar bot a um grupo aleatório (sem subscription)
2. [ ] Enviar mensagem nesse grupo
3. [ ] Mensagem é ignorada (não salva no banco)

### ✅ Loop Prevention

1. [ ] Verificar que mensagens com `source="telegram"` não são reenviadas
2. [ ] Verificar logs: não deve haver tentativa de reenvio

---

## ⚙️ Testes de Edge Cases

### ✅ Mensagem Muito Longa

1. [ ] Enviar mensagem com 5000+ caracteres no app
2. [ ] Verificar no Telegram: mensagem é truncada com "..."
3. [ ] Limite do Telegram: 4096 caracteres

### ✅ Arquivo Muito Grande

1. [ ] Tentar enviar arquivo > 50MB
2. [ ] Verificar erro apropriado

### ✅ Múltiplas Subscriptions

1. [ ] Criar 2+ subscriptions para o mesmo chat
2. [ ] Enviar mensagem no app
3. [ ] Verificar: mensagem é enviada para TODOS os destinos

### ✅ Bot Removido do Grupo

1. [ ] Remover bot de um grupo com subscription ativa
2. [ ] Enviar mensagem no app
3. [ ] Verificar logs de entrega: status "failed"
4. [ ] App não apresenta erro (envio é assíncrono)

### ✅ Reconnect

1. [ ] Enviar mensagem no app
2. [ ] Desconectar internet do dispositivo
3. [ ] Reconectar
4. [ ] Verificar: mensagem é sincronizada via Realtime

---

## 📊 Testes de Monitoramento

### ✅ Delivery Logs

1. [ ] Enviar várias mensagens
2. [ ] Consultar delivery logs:
   ```sql
   SELECT * FROM telegram_delivery_logs 
   ORDER BY created_at DESC LIMIT 10;
   ```
3. [ ] Verificar:
   - [ ] `status` = 'sent' para sucessos
   - [ ] `telegram_message_id` preenchido
   - [ ] `sent_at` correto

### ✅ Edge Function Logs

1. [ ] Executar:
   ```bash
   supabase functions logs telegram-webhook --limit 20
   supabase functions logs telegram-send --limit 20
   ```
2. [ ] Verificar:
   - [ ] Logs sem erros críticos
   - [ ] Timestamps corretos
   - [ ] Payloads bem formados

---

## 🎯 Critérios de Aceite

Para considerar a integração **pronta para produção**, todos os itens acima devem estar ✅.

**Críticos (obrigatórios):**
- ✅ Vinculação de conta funciona
- ✅ Envio de texto app → Telegram funciona
- ✅ Recebimento de texto Telegram → app funciona
- ✅ Segurança: webhook validado, usuários autenticados
- ✅ Não há loops de mensagens
- ✅ Imagens funcionam (ambas direções)

**Desejáveis:**
- ✅ Todos os tipos de mídia funcionam
- ✅ Edição de mensagens sincroniza
- ✅ Múltiplas subscriptions funcionam
- ✅ Delivery logs funcionam
- ✅ Erro handling apropriado

---

## 📝 Registro de Testes

**Data:** ___/___/______

**Testador:** _____________________

**Ambiente:** [ ] Dev [ ] Staging [ ] Prod

**Resultados:**
- Total de testes: _____
- Passou: _____
- Falhou: _____
- Bloqueado: _____

**Bugs encontrados:**
1. ___________________________________
2. ___________________________________
3. ___________________________________

**Observações:**
_______________________________________
_______________________________________
_______________________________________
