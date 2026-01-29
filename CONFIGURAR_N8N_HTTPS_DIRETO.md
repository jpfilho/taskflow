# 🔐 Configurar N8N com HTTPS - Direto no Servidor

Este guia explica como configurar o N8N com HTTPS **executando os comandos diretamente no servidor**, sem usar o script PowerShell.

---

## 📋 Pré-requisitos

1. Acesso SSH ao servidor `212.85.0.249`
2. Certificado SSL já configurado para `api.taskflowv3.com.br`
3. N8N já instalado e rodando

---

## 🚀 Passo a Passo

### 1. Conectar ao Servidor

```bash
ssh root@212.85.0.249
```

### 2. Verificar Certificado SSL

```bash
ls -la /etc/letsencrypt/live/api.taskflowv3.com.br/fullchain.pem
```

Se o arquivo existir, continue. Se não, configure HTTPS primeiro:
```bash
bash configurar_https_taskflow.sh
```

### 3. Fazer Backup do Nginx

```bash
cp /etc/nginx/sites-available/supabase /etc/nginx/sites-available/supabase.backup.$(date +%Y%m%d_%H%M%S)
```

### 4. Adicionar Configuração do N8N no Nginx

Edite o arquivo do Nginx:

```bash
nano /etc/nginx/sites-available/supabase
```

**OU** use `vi`:

```bash
vi /etc/nginx/sites-available/supabase
```

#### O que adicionar:

Encontre o bloco `server` que contém `listen 443` (bloco HTTPS). 

**IMPORTANTE**: Adicione a configuração do N8N **ANTES** do `location / {` final, para que o Nginx processe o path `/n8n` antes de redirecionar tudo para o Supabase.

Adicione este bloco:

```nginx
    # N8N via HTTPS
    location /n8n {
        # IMPORTANTE: Remover prefixo /n8n antes de enviar para N8N
        rewrite ^/n8n/(.*)$ /$1 break;
        rewrite ^/n8n$ / break;
        
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

**IMPORTANTE**: As linhas `rewrite` são **essenciais** para remover o prefixo `/n8n` antes de enviar para o N8N. Sem elas, o N8N recebe `/n8n/...` e não consegue processar.

**Exemplo de onde adicionar** (dentro do bloco `server` com `listen 443`):

```nginx
server {
    listen 443 ssl http2;
    server_name api.taskflowv3.com.br;
    
    # ... outras configurações SSL ...
    
    # N8N via HTTPS (ADICIONAR AQUI - ANTES do location /)
    location /n8n {
        # IMPORTANTE: Remover prefixo /n8n
        rewrite ^/n8n/(.*)$ /$1 break;
        rewrite ^/n8n$ / break;
        
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
    
    # Supabase (location / final)
    location / {
        proxy_pass http://127.0.0.1:8000;
        # ... outras configurações ...
    }
}
```

Salve o arquivo:
- **nano**: `Ctrl+O` (salvar), `Enter` (confirmar), `Ctrl+X` (sair)
- **vi**: `Esc`, depois `:wq` (salvar e sair)

### 5. Testar Configuração do Nginx

```bash
nginx -t
```

Se aparecer `syntax is ok` e `test is successful`, continue. Se houver erro, corrija o arquivo.

### 6. Recarregar Nginx

```bash
systemctl reload nginx
```

### 7. Atualizar Container do N8N

Pare e remova o container atual:

```bash
docker stop n8n
docker rm n8n
```

Recrie o container com as variáveis de ambiente HTTPS:

```bash
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

### 8. Verificar se Está Funcionando

Aguarde alguns segundos e verifique se o container está rodando:

```bash
docker ps | grep n8n
```

Teste se o N8N está acessível:

```bash
curl -k https://api.taskflowv3.com.br/n8n/
```

Deve retornar a página de login do N8N.

### 9. Verificar Logs (se necessário)

Se houver problemas, verifique os logs:

```bash
# Logs do N8N
docker logs n8n --tail 50

# Logs do Nginx
tail -20 /var/log/nginx/error.log
```

---

## ✅ Verificação Final

1. **Acesse o N8N**: `https://api.taskflowv3.com.br/n8n`
2. **Faça login** com:
   - Usuário: `admin`
   - Senha: `n8n_admin_2026`
3. **Abra o workflow do Telegram**
4. **Clique no nó "Telegram Trigger"**
5. **Verifique a URL do webhook**:
   - ✅ Deve mostrar: `https://api.taskflowv3.com.br/n8n/webhook/telegram-webhook`
   - ❌ **NÃO** deve mostrar: `http://212.85.0.249:5678`
6. **Ative o workflow** - não deve mais aparecer o erro de HTTPS!

---

## 🔍 Troubleshooting

### Erro: "502 Bad Gateway" ao acessar `/n8n`

**Causa**: N8N não está rodando ou Nginx não consegue conectar.

**Solução**:
```bash
# Verificar se N8N está rodando
docker ps | grep n8n

# Se não estiver, verificar logs
docker logs n8n --tail 50

# Reiniciar N8N
docker restart n8n
```

### Erro: "404 Not Found" ao acessar `/n8n`

**Causa**: Configuração do Nginx não está correta ou path está errado.

**Solução**:
1. Verifique se o `location /n8n` está **ANTES** do `location /` no arquivo do Nginx
2. Teste a configuração: `nginx -t`
3. Recarregue: `systemctl reload nginx`

### Webhook ainda mostra URL HTTP

**Causa**: Variável `WEBHOOK_URL` não foi atualizada no container.

**Solução**:
1. Pare e remova o container: `docker stop n8n && docker rm n8n`
2. Recrie com a variável `WEBHOOK_URL` correta (veja passo 7 acima)
3. Reinicie o N8N

### Erro no teste do Nginx

**Solução**:
```bash
# Verificar erro específico
nginx -t

# Se houver erro de sintaxe, verificar o arquivo
cat /etc/nginx/sites-available/supabase | grep -A 20 "location /n8n"

# Restaurar backup se necessário
cp /etc/nginx/sites-available/supabase.backup.* /etc/nginx/sites-available/supabase
```

---

## 📝 Resumo dos Comandos

```bash
# 1. Conectar
ssh root@212.85.0.249

# 2. Backup
cp /etc/nginx/sites-available/supabase /etc/nginx/sites-available/supabase.backup.$(date +%Y%m%d_%H%M%S)

# 3. Editar Nginx (adicionar location /n8n antes do location /)
nano /etc/nginx/sites-available/supabase

# 4. Testar e recarregar
nginx -t && systemctl reload nginx

# 5. Atualizar container N8N
docker stop n8n && docker rm n8n
docker run -d --name n8n --restart unless-stopped \
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

# 6. Verificar
docker ps | grep n8n
curl -k https://api.taskflowv3.com.br/n8n/
```

---

**Pronto!** Agora o N8N está configurado com HTTPS e o webhook do Telegram funcionará corretamente.
