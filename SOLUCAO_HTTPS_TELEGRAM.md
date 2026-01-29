# 🔐 Solução: HTTPS para Webhooks Telegram

## 🚨 Problema

O Telegram Bot API **exige HTTPS** para webhooks, mas seu Supabase está rodando apenas em HTTP:
- ✅ Funciona: `http://212.85.0.249:8000`
- ❌ Não funciona: `https://srv750497.hstgr.cloud` (porta 443 fechada)

---

## 🎯 3 SOLUÇÕES DISPONÍVEIS

### ✅ Solução 1: Configurar HTTPS no Servidor (RECOMENDADO)

Configurar certificado SSL/TLS no seu servidor Hostinger.

**Vantagens:**
- ✅ Solução permanente e profissional
- ✅ Sem dependências externas
- ✅ Grátis (Let's Encrypt)

**Como fazer:**

1. **SSH no servidor:**
```bash
ssh root@212.85.0.249
```

2. **Instalar Certbot:**
```bash
# Ubuntu/Debian
apt update
apt install certbot nginx -y

# CentOS/RHEL
yum install certbot nginx -y
```

3. **Gerar certificado:**
```bash
certbot certonly --standalone -d srv750497.hstgr.cloud
```

4. **Configurar Nginx como proxy reverso:**

Criar arquivo `/etc/nginx/sites-available/supabase`:

```nginx
server {
    listen 80;
    server_name srv750497.hstgr.cloud 212.85.0.249;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name srv750497.hstgr.cloud 212.85.0.249;

    ssl_certificate /etc/letsencrypt/live/srv750497.hstgr.cloud/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/srv750497.hstgr.cloud/privkey.pem;

    # Supabase API
    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Edge Functions
    location /functions/ {
        proxy_pass http://localhost:8000/functions/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

5. **Ativar e reiniciar Nginx:**
```bash
ln -s /etc/nginx/sites-available/supabase /etc/nginx/sites-enabled/
nginx -t
systemctl restart nginx
```

6. **Testar:**
```bash
curl https://srv750497.hstgr.cloud
```

7. **Atualizar Flutter:**

Editar `lib/config/supabase_config.dart`:
```dart
static const String supabaseUrl = 'https://srv750497.hstgr.cloud';
```

8. **Configurar webhook:**
```bash
curl -X POST "https://api.telegram.org/bot8432168734:AAF_R1iq3p1c5Crm2oAcLsgkfzqH5_Pywec/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://srv750497.hstgr.cloud/functions/v1/telegram-webhook",
    "secret_token": "SEU_WEBHOOK_SECRET",
    "allowed_updates": ["message", "edited_message", "callback_query"]
  }'
```

---

### ✅ Solução 2: Cloudflare Tunnel (RÁPIDO)

Usar Cloudflare Tunnel para expor o servidor via HTTPS gratuitamente.

**Vantagens:**
- ✅ Rápido de configurar (5 minutos)
- ✅ Grátis
- ✅ HTTPS automático
- ✅ Proteção DDoS inclusa

**Como fazer:**

1. **No servidor, instalar cloudflared:**
```bash
ssh root@212.85.0.249

# Download
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
dpkg -i cloudflared-linux-amd64.deb
```

2. **Login Cloudflare:**
```bash
cloudflared tunnel login
```

3. **Criar tunnel:**
```bash
cloudflared tunnel create taskflow-supabase
```

4. **Configurar tunnel:**

Criar arquivo `~/.cloudflared/config.yml`:
```yaml
tunnel: <TUNNEL_ID>
credentials-file: /root/.cloudflared/<TUNNEL_ID>.json

ingress:
  - hostname: supabase-taskflow.seu-dominio.com
    service: http://localhost:8000
  - service: http_status:404
```

5. **Configurar DNS no Cloudflare:**
```bash
cloudflared tunnel route dns taskflow-supabase supabase-taskflow.seu-dominio.com
```

6. **Iniciar tunnel:**
```bash
cloudflared tunnel run taskflow-supabase
```

7. **Webhook URL:**
```
https://supabase-taskflow.seu-dominio.com/functions/v1/telegram-webhook
```

---

### ✅ Solução 3: Modo Polling (SEM WEBHOOK)

Adaptar o bot para usar **polling** em vez de webhooks.

**Vantagens:**
- ✅ Não precisa HTTPS
- ✅ Funciona com HTTP/IP direto
- ✅ Mais simples de debugar

**Desvantagens:**
- ❌ Menos eficiente (consulta periódica)
- ❌ Latência maior
- ❌ Requer processo rodando constantemente

**Como fazer:**

1. **Criar serviço de polling:**

Arquivo `telegram_polling_service.js`:
```javascript
const TelegramBot = require('node-telegram-bot-api');
const { createClient } = require('@supabase/supabase-js');

const token = '8432168734:AAF_R1iq3p1c5Crm2oAcLsgkfzqH5_Pywec';
const supabaseUrl = 'http://212.85.0.249:8000';
const supabaseKey = 'eyJhbGc...'; // Service role key

const bot = new TelegramBot(token, { polling: true });
const supabase = createClient(supabaseUrl, supabaseKey);

// Receber mensagens do Telegram
bot.on('message', async (msg) => {
  console.log('Mensagem recebida:', msg);
  
  // Buscar subscription
  const { data: subscription } = await supabase
    .from('telegram_subscriptions')
    .select('*')
    .eq('telegram_chat_id', msg.chat.id)
    .single();

  if (!subscription) {
    console.log('Chat não tem subscription');
    return;
  }

  // Inserir mensagem no Supabase
  const { error } = await supabase
    .from('mensagens')
    .insert({
      grupo_id: subscription.thread_id,
      conteudo: msg.text,
      tipo: 'texto',
      source: 'telegram',
      telegram_metadata: {
        chat_id: msg.chat.id,
        message_id: msg.message_id,
        from_id: msg.from.id,
        from_username: msg.from.username
      }
    });

  if (error) {
    console.error('Erro ao inserir mensagem:', error);
  }
});

// Enviar mensagens do Supabase para Telegram
const channel = supabase
  .channel('mensagens')
  .on('postgres_changes', 
    { event: 'INSERT', schema: 'public', table: 'mensagens' },
    async (payload) => {
      const mensagem = payload.new;
      
      // Só enviar mensagens do app
      if (mensagem.source !== 'app') return;

      // Buscar subscriptions
      const { data: subscriptions } = await supabase
        .from('telegram_subscriptions')
        .select('*')
        .eq('thread_id', mensagem.grupo_id);

      // Enviar para cada subscription
      for (const sub of subscriptions || []) {
        try {
          await bot.sendMessage(sub.telegram_chat_id, mensagem.conteudo);
        } catch (error) {
          console.error('Erro ao enviar para Telegram:', error);
        }
      }
    }
  )
  .subscribe();

console.log('Bot iniciado em modo polling');
```

2. **Instalar dependências:**
```bash
npm install node-telegram-bot-api @supabase/supabase-js
```

3. **Rodar serviço:**
```bash
node telegram_polling_service.js
```

4. **Configurar como serviço systemd:**

Arquivo `/etc/systemd/system/telegram-polling.service`:
```ini
[Unit]
Description=Telegram Polling Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/telegram-bot
ExecStart=/usr/bin/node telegram_polling_service.js
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
systemctl enable telegram-polling
systemctl start telegram-polling
systemctl status telegram-polling
```

---

## 🎯 RECOMENDAÇÃO

**Para produção: Solução 1 (HTTPS + Nginx)**
- Profissional e permanente
- Sem custos extras
- Melhor performance

**Para teste rápido: Solução 3 (Polling)**
- Funciona imediatamente
- Não precisa configurar servidor
- Depois migrar para webhook

**Para domínio personalizado: Solução 2 (Cloudflare)**
- Se você tem domínio próprio
- HTTPS gratuito e automático

---

## 📚 Próximos Passos

Escolha uma solução e me avise qual você prefere:

1. **Solução 1:** Preciso criar script de instalação nginx + SSL
2. **Solução 2:** Preciso te guiar no Cloudflare Tunnel
3. **Solução 3:** Preciso adaptar o código para polling mode

Qual solução você prefere? 🤔
