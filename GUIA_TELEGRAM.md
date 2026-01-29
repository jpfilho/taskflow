# 🤖 GUIA: Integração Telegram - Passo a Passo

## 📋 CHECKLIST GERAL

- [ ] Configurar SSL (Let's Encrypt)
- [ ] Configurar webhook do Telegram
- [ ] Configurar variáveis de ambiente
- [ ] Testar Edge Functions (ou criar alternativa)
- [ ] Testar integração completa

---

## PASSO 1: Configurar SSL (HTTPS) ✅

O Telegram **exige HTTPS** para webhooks.

### 1.1. Editar o email no script

Abra o arquivo `configurar_ssl_telegram.sh` e altere:

```bash
EMAIL="seu-email@exemplo.com"  # ALTERAR PARA SEU EMAIL REAL
```

### 1.2. Executar configuração

```powershell
.\executar_ssl.ps1
```

Este script vai:
- Instalar certbot
- Obter certificado Let's Encrypt para `api.taskflowv3.com.br`
- Configurar Nginx para HTTPS
- Configurar renovação automática

### 1.3. Testar

Abra no navegador:
- https://api.taskflowv3.com.br/

Deve mostrar a página do Supabase com **cadeado verde** 🔒

---

## PASSO 2: Configurar Webhook do Telegram 🔗

### 2.1. Obter informações necessárias

Você precisa de:

1. **BOT_TOKEN** - Do BotFather (você já tem)
2. **WEBHOOK_SECRET** - Crie uma senha segura (ex: `TgW3bh00k2026Secure`)
3. **CHAT_ID** - ID do grupo onde o bot está

Para obter o CHAT_ID:
- Adicione o bot no grupo
- Envie uma mensagem no grupo
- Acesse: `https://api.telegram.org/bot<SEU_BOT_TOKEN>/getUpdates`
- Procure por `"chat":{"id":-1001234567890}`

### 2.2. Executar configuração

```powershell
.\configurar_webhook_telegram.ps1
```

O script vai perguntar:
- Token do bot
- Secret do webhook
- Chat ID

E vai configurar automaticamente!

---

## PASSO 3: Edge Functions ⚠️

**PROBLEMA CONHECIDO:** Supabase self-hosted pode não ter suporte completo a Edge Functions.

### Opção A: Testar Edge Functions

Se você atualizou o Supabase recentemente, tente:

```bash
# No servidor
cd /root/supabase
docker-compose down
docker-compose pull
docker-compose up -d
```

Depois, faça deploy da função:

```bash
# Copiar função para o servidor
scp -r supabase/functions root@212.85.0.249:/root/

# No servidor
cd /root/functions
supabase functions deploy telegram-webhook
```

### Opção B: Servidor Webhook Separado (mais confiável)

Se Edge Functions não funcionarem, posso criar um servidor Node.js/Deno separado que:
- Roda na porta 3000
- Recebe webhooks do Telegram
- Insere mensagens direto no Supabase
- Muito mais estável

**Qual opção você prefere?**

---

## PASSO 4: Testar Integração 🧪

### 4.1. Teste de envio (Flutter → Telegram)

1. Abra o app Flutter
2. Vá em um chat configurado
3. Envie uma mensagem
4. Verifique se aparece no Telegram

### 4.2. Teste de recebimento (Telegram → Flutter)

1. Envie mensagem no grupo do Telegram
2. Verifique se aparece no app Flutter

---

## 🆘 TROUBLESHOOTING

### Erro: "SSL error"
- Verifique se o certificado foi instalado: `ls /etc/letsencrypt/live/api.taskflowv3.com.br/`
- Teste HTTPS: `curl -I https://api.taskflowv3.com.br/`

### Erro: "Wrong response from the webhook"
- Edge Functions não estão funcionando
- Use **Opção B: Servidor Webhook Separado**

### Erro: "Unauthorized"
- Verifique o token do bot
- Teste: `curl https://api.telegram.org/bot<TOKEN>/getMe`

### Erro: "Bad Request: bad webhook"
- Verifique se HTTPS está funcionando
- Verifique se a porta 443 está aberta no firewall

---

## 📝 PRÓXIMOS PASSOS

Após concluir os passos acima:

1. Execute `.\executar_ssl.ps1` primeiro
2. Teste o HTTPS
3. Execute `.\configurar_webhook_telegram.ps1`
4. Me avise qual opção quer para as Edge Functions

**Preparado para começar? Execute o primeiro comando!** 🚀
