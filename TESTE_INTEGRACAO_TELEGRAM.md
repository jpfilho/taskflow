# 🧪 TESTE DE INTEGRAÇÃO TELEGRAM

## ✅ PRÉ-REQUISITOS CONCLUÍDOS

- [x] Bot criado (@TaskFlow_chat_bot)
- [x] Webhook configurado
- [x] Edge Functions rodando
- [x] Tabelas criadas no banco

---

## 🚀 COMO TESTAR

### **TESTE 1: Verificar se o Bot está Online**

1. Abra o Telegram
2. Procure por: **@TaskFlow_chat_bot**
3. Envie: `/start`

**Resultado esperado:**
- ❌ O bot ainda NÃO vai responder (isso é normal!)
- ✅ A mensagem será recebida pelo webhook

---

### **TESTE 2: Verificar Webhook (logs do servidor)**

Execute no PowerShell:

```powershell
ssh root@212.85.0.249 "cd /root/supabase && docker-compose logs --tail=100 edge-functions | grep telegram"
```

**Procure por:**
- ✅ Mensagens do tipo: `telegram-webhook received update`
- ✅ Ou: `message from user`

---

### **TESTE 3: Testar Edge Function Diretamente**

Execute no PowerShell:

```powershell
curl.exe -k -X POST "https://212.85.0.249/functions/v1/telegram-webhook" `
  -H "Content-Type: application/json" `
  -H "X-Telegram-Bot-Api-Secret-Token: Tg0h00kSecr3t2025fasKFlow" `
  -d '{\"update_id\":1,\"message\":{\"message_id\":1,\"from\":{\"id\":123,\"username\":\"test\"},\"chat\":{\"id\":123,\"type\":\"private\"},\"text\":\"Teste\"}}'
```

**Resultado esperado:**
- Status HTTP 200
- Resposta: `{"ok": true}` ou similar

---

### **TESTE 4: No Flutter - Configurar Telegram para um Chat**

1. **Compile e execute o app Flutter:**
   ```powershell
   flutter run
   ```

2. **No app:**
   - Abra uma **Comunidade** (ex: Divisão X - Segmento Y)
   - Abra um **Grupo/Chat de Tarefa**
   - Clique no ícone **Telegram** no canto superior direito
   - Verá o diálogo de configuração do Telegram

3. **Linkar sua conta:**
   - Clique em "Vincular meu Telegram"
   - Copie o deep link gerado
   - Cole no navegador ou Telegram
   - Fale com o bot

4. **Ativar espelhamento:**
   - No diálogo, ative "Espelhar mensagens"
   - Escolha modo: **DM** (Direct Message)
   - Salve

---

### **TESTE 5: Enviar Mensagem do Flutter → Telegram**

1. No chat do Flutter, **envie uma mensagem de teste**
2. **Verifique no Telegram** se você recebeu a mensagem do bot

**Resultado esperado:**
- ✅ Mensagem aparece no Telegram vinda do @TaskFlow_chat_bot

---

### **TESTE 6: Enviar Mensagem do Telegram → Flutter**

1. No Telegram, **responda a mensagem do bot**
2. **Volte ao Flutter** e veja se a mensagem aparece no chat

**Resultado esperado:**
- ✅ Mensagem aparece no chat do Flutter

---

## 🐛 TROUBLESHOOTING

### Se o bot não responde:

**1. Verificar logs do Edge Function:**
```powershell
ssh root@212.85.0.249 "cd /root/supabase && docker-compose logs --tail=50 edge-functions"
```

**2. Verificar webhook do Telegram:**
```powershell
curl.exe "https://api.telegram.org/bot8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec/getWebhookInfo"
```

**3. Testar conexão com Supabase:**
```sql
-- No SQL Editor do Supabase
SELECT * FROM telegram_identities;
SELECT * FROM telegram_subscriptions;
SELECT * FROM mensagens WHERE source = 'telegram' LIMIT 10;
```

---

## 📊 QUERIES ÚTEIS

**Ver identidades Telegram linkadas:**
```sql
SELECT * FROM telegram_identities;
```

**Ver subscriptions ativas:**
```sql
SELECT * FROM telegram_subscriptions;
```

**Ver mensagens do Telegram:**
```sql
SELECT * FROM mensagens WHERE source = 'telegram' ORDER BY created_at DESC LIMIT 20;
```

**Ver logs de entrega:**
```sql
SELECT * FROM telegram_delivery_logs ORDER BY attempted_at DESC LIMIT 20;
```

---

## ✅ CHECKLIST DE SUCESSO

- [ ] Bot responde no Telegram
- [ ] Webhook recebe updates (ver logs)
- [ ] Mensagem do Flutter chega no Telegram
- [ ] Mensagem do Telegram chega no Flutter
- [ ] Dados aparecem nas tabelas do banco

---

## 🎯 PRÓXIMO PASSO

Após confirmar que está funcionando, podemos:
1. ✅ Adicionar badge "TG" nas listas de chat
2. ✅ Implementar grupos/tópicos (em vez de só DM)
3. ✅ Adicionar mais tipos de mensagem (imagens, vídeos, etc.)
