# 🚧 PRÓXIMOS PASSOS - INTEGRAÇÃO TELEGRAM

## 📊 STATUS ATUAL

### ✅ CONCLUÍDO:
1. Bot Telegram criado (@taskflow_bot)
2. Token correto: `8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec`
3. Migrations SQL executadas (3 tabelas criadas)
4. Código Flutter implementado (`TelegramService`, `TelegramConfigDialog`)
5. Edge Functions criadas (TypeScript/Deno)
6. DNS configurado: `api.taskflow3.com.br` → `212.85.0.249`

### ❌ BLOQUEIOS IDENTIFICADOS:
1. **Supabase Self-Hosted não suporta Edge Functions nativamente**
   - Erro: `InvalidWorkerCreation: could not find an appropriate entrypoint`
   - Solução: Usar servidor proxy ou migrar para Supabase Cloud

2. **Certificado SSL auto-assinado rejeitado pelo Telegram**
   - Telegram requer certificado válido (Let's Encrypt)
   - DNS ainda não propagou completamente

3. **Flutter não pode chamar API do Telegram diretamente**
   - Exporia o TELEGRAM_BOT_TOKEN no cliente (inseguro)
   - Precisa de backend intermediário

---

## 🔧 SOLUÇÃO 1: USAR NGINX COMO PROXY (RECOMENDADO)

Em vez de Edge Functions, usar Nginx para fazer proxy das chamadas.

### Passo 1: Aguardar DNS Propagar

Verificar se `api.taskflow3.com.br` resolve:

```bash
nslookup api.taskflow3.com.br 8.8.8.8
```

**Tempo estimado:** 30 minutos a 24 horas

---

### Passo 2: Instalar Let's Encrypt

Quando o DNS propagar, executar no servidor:

```bash
ssh root@212.85.0.249 < configurar_lets_encrypt_dns.sh
```

Isso vai:
- Instalar Certbot
- Obter certificado SSL válido
- Configurar Nginx com HTTPS

**Tempo estimado:** 5 minutos

---

### Passo 3: Criar APIs Proxy no Servidor

Criar endpoints simples que chamam a API do Telegram:

**Arquivo:** `/root/telegram_proxy.js`

```javascript
const express = require('express');
const axios = require('axios');
const app = express();

app.use(express.json());

const TELEGRAM_BOT_TOKEN = '8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec';
const TELEGRAM_API = `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}`;

// Endpoint: Enviar mensagem
app.post('/telegram/send', async (req, res) => {
  try {
    const { chat_id, text } = req.body;
    
    const response = await axios.post(`${TELEGRAM_API}/sendMessage`, {
      chat_id,
      text
    });
    
    res.json(response.data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Endpoint: Webhook (receber mensagens do Telegram)
app.post('/telegram/webhook', async (req, res) => {
  try {
    const update = req.body;
    
    // TODO: Processar update e salvar no Supabase
    console.log('Received update:', update);
    
    res.json({ ok: true });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(3000, () => {
  console.log('Telegram Proxy rodando na porta 3000');
});
```

**Instalar e rodar:**

```bash
ssh root@212.85.0.249 <<'EOF'
cd /root
npm init -y
npm install express axios
node telegram_proxy.js &
EOF
```

---

### Passo 4: Configurar Nginx para Proxy

Adicionar ao Nginx:

```nginx
location /telegram/ {
    proxy_pass http://localhost:3000/telegram/;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
}
```

---

### Passo 5: Atualizar Flutter

Modificar `TelegramService`:

```dart
Future<void> sendMessageToTelegram({
  required String chatId,
  required String text,
}) async {
  try {
    final response = await http.post(
      Uri.parse('https://api.taskflow3.com.br/telegram/send'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'chat_id': chatId, 'text': text}),
    );
    
    if (response.statusCode == 200) {
      print('✅ Mensagem enviada para Telegram');
    }
  } catch (e) {
    print('❌ Erro: $e');
  }
}
```

---

### Passo 6: Configurar Webhook

```bash
curl -X POST "https://api.telegram.org/bot8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://api.taskflow3.com.br/telegram/webhook",
    "secret_token": "Tg0h00kSecr3t2025fasKFlow"
  }'
```

---

## 🔧 SOLUÇÃO 2: MIGRAR PARA SUPABASE CLOUD (MAIS FÁCIL)

Se você criar um projeto no **Supabase Cloud** (grátis até 500MB):

1. Edge Functions funcionam nativamente ✅
2. HTTPS automático ✅
3. Webhooks funcionam ✅
4. Não precisa gerenciar servidor ✅

**Desvantagens:**
- Dados no cloud (não self-hosted)
- Limite grátis de 500MB

---

## 🔧 SOLUÇÃO 3: DESISTIR DO TELEGRAM TEMPORARIAMENTE

Focar em outras funcionalidades do app até a infraestrutura estar pronta.

---

## 📋 CHECKLIST PARA RETOMAR

- [ ] DNS de `api.taskflow3.com.br` propagou (verificar com nslookup)
- [ ] Certificado SSL válido instalado (Let's Encrypt)
- [ ] Proxy Node.js ou similar rodando no servidor
- [ ] Nginx configurado para fazer proxy
- [ ] Webhook do Telegram configurado
- [ ] Código Flutter atualizado para usar novo endpoint
- [ ] Testar envio Flutter → Telegram
- [ ] Testar recebimento Telegram → Flutter

---

## ⏰ TEMPO ESTIMADO TOTAL

**Com DNS já propagado:** 30 minutos  
**Aguardando DNS:** 1-24 horas + 30 minutos

---

## 🆘 AJUDA RÁPIDA

Se precisar de ajuda para qualquer etapa:
1. Verifique os logs: `docker-compose logs`
2. Teste o DNS: `nslookup api.taskflow3.com.br 8.8.8.8`
3. Teste HTTPS: `curl https://api.taskflow3.com.br`

---

## 📞 CONTATO

Qualquer dúvida, me avise e eu ajudo a implementar!
