# 🔐 Solução: N8N com HTTPS para Webhooks Telegram

## 🚨 Problema

Ao tentar ativar o workflow do Telegram no N8N, você recebe o erro:

```
Telegram Trigger: Bad Request: bad webhook: An HTTPS URL must be provided for webhook
```

**Causa**: O Telegram Bot API **exige HTTPS** para webhooks, mas o N8N está configurado com URL HTTP (`http://212.85.0.249:5678`).

---

## ✅ Solução Rápida

### Opção 1: Script PowerShell (Windows)

Execute o script de configuração:

```powershell
.\configurar_n8n_https.ps1
```

Este script irá:
1. Verificar se o certificado SSL existe
2. Configurar Nginx para expor N8N via HTTPS no path `/n8n`
3. Atualizar container do N8N com URL HTTPS correta
4. Testar a configuração

### Opção 2: Direto no Servidor (Recomendado)

Se preferir executar diretamente no servidor, veja o guia completo:

📖 **[CONFIGURAR_N8N_HTTPS_DIRETO.md](CONFIGURAR_N8N_HTTPS_DIRETO.md)** - Guia passo a passo para executar no servidor

**Resumo rápido**:
```bash
ssh root@212.85.0.249
# Editar /etc/nginx/sites-available/supabase (adicionar location /n8n)
# Recriar container N8N com variáveis HTTPS
```

---

## 📋 Pré-requisitos

Antes de executar o script, certifique-se de que:

1. **HTTPS está configurado no servidor**:
   - Certificado SSL válido para `api.taskflowv3.com.br`
   - Nginx configurado e funcionando

   Se não estiver configurado, execute primeiro:
   ```bash
   # No servidor
   bash configurar_https_taskflow.sh
   ```

2. **N8N está instalado e rodando**:
   ```bash
   ssh root@212.85.0.249 'docker ps | grep n8n'
   ```

---

## 🔧 Configuração Manual (Alternativa)

Se preferir configurar manualmente:

### 1. Configurar Nginx

Adicione ao arquivo `/etc/nginx/sites-available/supabase` (dentro do bloco `server` HTTPS):

```nginx
# N8N via HTTPS (path /n8n)
location /n8n {
    proxy_pass http://127.0.0.1:5678;
    proxy_http_version 1.1;
    
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Port 443;
    
    proxy_connect_timeout 600s;
    proxy_send_timeout 600s;
    proxy_read_timeout 600s;
    proxy_buffering off;
    client_max_body_size 50M;
}
```

**IMPORTANTE**: Esta configuração deve estar **ANTES** do `location /` final, para que o Nginx processe o path `/n8n` antes de redirecionar tudo para o Supabase.

Teste e recarregue:
```bash
nginx -t
systemctl reload nginx
```

### 2. Atualizar Container N8N

Pare e recrie o container com as variáveis de ambiente corretas:

```bash
ssh root@212.85.0.249
docker stop n8n
docker rm n8n

docker run -d \
    --name n8n \
    --restart unless-stopped \
    -p 127.0.0.1:5678:5678 \
    -v /opt/n8n:/home/node/.n8n \
    -e N8N_BASIC_AUTH_ACTIVE=true \
    -e N8N_BASIC_AUTH_USER=admin \
    -e N8N_BASIC_AUTH_PASSWORD=n8n_admin_2026 \
    -e N8N_HOST=api.taskflowv3.com.br \
    -e N8N_PORT=443 \
    -e N8N_PROTOCOL=https \
    -e WEBHOOK_URL=https://api.taskflowv3.com.br/n8n/ \
    -e N8N_PATH=/n8n \
    n8nio/n8n:latest
```

**Variáveis importantes**:
- `N8N_HOST`: Domínio público com HTTPS
- `N8N_PORT`: 443 (porta HTTPS)
- `N8N_PROTOCOL`: https
- `WEBHOOK_URL`: URL completa HTTPS onde o N8N está acessível
- `N8N_PATH`: Path onde o N8N está exposto (se usar subpath)

### 3. Verificar Configuração

Teste se o N8N está acessível:

```bash
curl -k https://api.taskflowv3.com.br/n8n/
```

Deve retornar a página de login do N8N.

---

## 🧪 Testar Webhook do Telegram

Após configurar, teste o webhook:

1. **Acesse o N8N**: `https://api.taskflowv3.com.br/n8n`
2. **Abra o workflow do Telegram**
3. **Clique no nó "Telegram Trigger"**
4. **Verifique a URL do webhook**:
   - Deve mostrar: `https://api.taskflowv3.com.br/n8n/webhook/telegram-webhook`
   - **NÃO** deve mostrar `http://212.85.0.249:5678`

5. **Ative o workflow**
6. **Verifique se não há erros**

Se ainda houver erro, verifique os logs:

```bash
ssh root@212.85.0.249 'docker logs n8n --tail 50'
```

---

## 🔍 Troubleshooting

### Erro: "Certificado SSL não encontrado"

**Solução**: Configure HTTPS primeiro:
```bash
bash configurar_https_taskflow.sh
```

### Erro: "502 Bad Gateway" ao acessar `/n8n`

**Causa**: N8N não está rodando ou Nginx não consegue conectar.

**Solução**:
```bash
# Verificar se N8N está rodando
ssh root@212.85.0.249 'docker ps | grep n8n'

# Verificar logs do N8N
ssh root@212.85.0.249 'docker logs n8n --tail 50'

# Verificar logs do Nginx
ssh root@212.85.0.249 'tail -20 /var/log/nginx/error.log'
```

### Erro: "404 Not Found" ao acessar `/n8n`

**Causa**: Configuração do Nginx não está correta ou path está errado.

**Solução**:
1. Verifique se a configuração do Nginx está correta
2. Certifique-se de que o `location /n8n` está **ANTES** do `location /`
3. Teste a configuração: `nginx -t`
4. Recarregue: `systemctl reload nginx`

### Webhook ainda mostra URL HTTP

**Causa**: Variável `WEBHOOK_URL` não foi atualizada no container.

**Solução**:
1. Pare e remova o container
2. Recrie com a variável `WEBHOOK_URL` correta (veja seção 2 acima)
3. Reinicie o N8N

---

## 📚 Referências

- [Documentação N8N - Webhooks](https://docs.n8n.io/integrations/builtin/core-nodes/webhook/)
- [Documentação N8N - Environment Variables](https://docs.n8n.io/hosting/configuration/environment-variables/)
- [Telegram Bot API - setWebhook](https://core.telegram.org/bots/api#setwebhook)

---

## ✅ Checklist

Após configurar, verifique:

- [ ] N8N acessível em `https://api.taskflowv3.com.br/n8n`
- [ ] Login funciona corretamente
- [ ] Workflow do Telegram mostra URL HTTPS no webhook
- [ ] Workflow ativa sem erros
- [ ] Teste enviando mensagem no Telegram
- [ ] Bot responde corretamente

---

**Última atualização**: 2026-01-25
