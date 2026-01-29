# 🐳 Deploy Edge Functions - Supabase Docker (Hostinger VPS)

## 📋 Visão Geral

Seu Supabase está rodando em Docker na Hostinger VPS (`srv750497.hstgr.cloud`).
Vamos fazer o deploy das Edge Functions para o container `supabase-edge-functions`.

---

## 🚀 OPÇÃO 1: Deploy via SSH (Recomendado)

### 1️⃣ Conectar na VPS via SSH

```bash
# Windows (PowerShell)
ssh root@srv750497.hstgr.cloud

# Ou via painel Hostinger: Terminal SSH
```

### 2️⃣ Localizar Diretório do Supabase

```bash
# Procurar onde está o docker-compose.yml do Supabase
find / -name "docker-compose.yml" -type f 2>/dev/null | grep supabase

# Ou
cd /home/
find . -name "supabase" -type d
```

**Diretórios comuns:**
- `/opt/supabase/`
- `/home/supabase/`
- `/var/www/supabase/`

### 3️⃣ Verificar Estrutura Atual

```bash
cd /caminho/do/supabase  # Substitua pelo caminho encontrado

# Ver estrutura
ls -la

# Ver docker-compose.yml
cat docker-compose.yml | grep -A 10 "edge-functions\|functions"
```

### 4️⃣ Criar Diretório das Functions (se não existir)

```bash
# Dentro do diretório do Supabase
mkdir -p volumes/functions
cd volumes/functions

# Criar diretórios das funções
mkdir -p telegram-webhook telegram-send
```

### 5️⃣ Copiar Arquivos das Edge Functions

**Do seu PC para o servidor:**

```powershell
# No PowerShell do seu PC (Windows)
# Substitua 'root' pelo seu usuário SSH se for diferente

# Copiar telegram-webhook
scp -r C:\aplicativos\taskflow\taskflow\supabase\functions\telegram-webhook root@srv750497.hstgr.cloud:/opt/supabase/volumes/functions/

# Copiar telegram-send
scp -r C:\aplicativos\taskflow\taskflow\supabase\functions\telegram-send root@srv750497.hstgr.cloud:/opt/supabase/volumes/functions/
```

**OU via SFTP (mais fácil):**

Use FileZilla ou WinSCP:
1. Conecte em `srv750497.hstgr.cloud`
2. Navegue até `/opt/supabase/volumes/functions/` (ou caminho correto)
3. Arraste as pastas `telegram-webhook` e `telegram-send`

### 6️⃣ Verificar Arquivos Copiados

```bash
# Na VPS via SSH
cd /opt/supabase/volumes/functions/

# Verificar estrutura
ls -la telegram-webhook/
ls -la telegram-send/

# Deve mostrar:
# telegram-webhook/
#   - index.ts
#   - .env
# telegram-send/
#   - index.ts
#   - .env
```

### 7️⃣ Reiniciar Container das Edge Functions

```bash
# Voltar para o diretório do docker-compose
cd /opt/supabase/

# Reiniciar apenas o container de Edge Functions
docker-compose restart edge-functions

# OU reiniciar todos os containers
docker-compose restart

# Verificar logs
docker-compose logs -f edge-functions
```

### 8️⃣ Testar Função

```bash
# Testar se a função está respondendo
curl https://srv750497.hstgr.cloud/functions/v1/telegram-webhook

# Deve retornar erro 401 (esperado, pois não tem auth)
# Se retornar 404, a função não foi carregada
```

---

## 🐳 OPÇÃO 2: Deploy via Docker Compose

### Verificar Volume Montado

Edite o `docker-compose.yml`:

```yaml
services:
  edge-functions:
    image: supabase/edge-runtime:latest
    volumes:
      - ./volumes/functions:/home/deno/functions:ro
    environment:
      - SUPABASE_URL=https://srv750497.hstgr.cloud
      - SUPABASE_ANON_KEY=sua_anon_key
      - SUPABASE_SERVICE_ROLE_KEY=sua_service_role_key
```

**Reiniciar:**

```bash
docker-compose down edge-functions
docker-compose up -d edge-functions
```

---

## 📁 Estrutura de Diretórios Esperada

```
/opt/supabase/  (ou seu caminho)
├── docker-compose.yml
├── volumes/
│   ├── db/
│   ├── storage/
│   └── functions/
│       ├── telegram-webhook/
│       │   ├── index.ts
│       │   └── .env
│       └── telegram-send/
│           ├── index.ts
│           └── .env
```

---

## 🔧 Troubleshooting

### Função não aparece

```bash
# Verificar logs do container
docker logs supabase-edge-functions

# Entrar no container
docker exec -it supabase-edge-functions sh

# Ver arquivos dentro do container
ls -la /home/deno/functions/
```

### Erro de permissão

```bash
# Ajustar permissões
chmod -R 755 /opt/supabase/volumes/functions/
chown -R 1000:1000 /opt/supabase/volumes/functions/
```

### Função não encontra variáveis de ambiente

Certifique-se que os arquivos `.env` estão dentro de cada pasta de função:
- `/opt/supabase/volumes/functions/telegram-webhook/.env`
- `/opt/supabase/volumes/functions/telegram-send/.env`

---

## 🎯 Configurar Webhook

Após deploy bem-sucedido, execute no seu PC:

```powershell
.\configurar_webhook.ps1
```

Ou manualmente:

```bash
curl -X POST "https://api.telegram.org/bot8432168734:AAF_R1iq3p1c5Crm2oAcLsgkfzqH5_Pywec/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://srv750497.hstgr.cloud/functions/v1/telegram-webhook",
    "secret_token": "SEU_WEBHOOK_SECRET",
    "allowed_updates": ["message", "edited_message", "callback_query"]
  }'
```

**Verificar:**

```bash
curl "https://api.telegram.org/bot8432168734:AAF_R1iq3p1c5Crm2oAcLsgkfzqH5_Pywec/getWebhookInfo"
```

---

## ✅ Checklist de Deploy

- [ ] SSH conectado na VPS
- [ ] Diretório do Supabase localizado
- [ ] Pasta `volumes/functions` criada
- [ ] Arquivos das Edge Functions copiados
- [ ] Arquivos `.env` presentes
- [ ] Container `edge-functions` reiniciado
- [ ] Logs sem erros
- [ ] Webhook configurado
- [ ] Teste de envio/recebimento funcionando

---

## 🆘 Precisa de Ajuda?

Se tiver problemas:

1. **Ver logs:** `docker-compose logs -f edge-functions`
2. **Ver containers:** `docker ps | grep supabase`
3. **Testar endpoint:** `curl https://srv750497.hstgr.cloud/functions/v1/telegram-webhook`

---

## 📚 Próximos Passos

Após deploy:
1. ✅ Executar migration SQL no banco
2. ✅ Testar vinculação no app Flutter
3. ✅ Criar subscription de um chat
4. ✅ Enviar mensagens de teste

Consulte: `INTEGRACAO_TELEGRAM.md` para mais detalhes.
