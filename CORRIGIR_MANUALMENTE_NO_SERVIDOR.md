# Correção Manual no Servidor

Execute estes comandos diretamente no servidor (via SSH ou console).

## 1. Verificar Status Atual

```bash
# Verificar se Node.js está rodando
systemctl status telegram-webhook

# Verificar se porta 3001 está aberta
netstat -tlnp | grep 3001
# ou
ss -tlnp | grep 3001

# Verificar firewall
ufw status | grep 3001
```

## 2. Configurar Nginx para /send-message

### 2.1. Identificar arquivo de configuração

```bash
# Ver qual arquivo está sendo usado
ls -la /etc/nginx/sites-enabled/

# Provavelmente será um destes:
# - supabase-ssl
# - default
# - api_taskflow
```

### 2.2. Fazer backup

```bash
# Se for supabase-ssl
cp /etc/nginx/sites-enabled/supabase-ssl /etc/nginx/sites-enabled/supabase-ssl.backup.$(date +%Y%m%d_%H%M%S)

# Se for default
cp /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/default.backup.$(date +%Y%m%d_%H%M%S)
```

### 2.3. Editar configuração do Nginx

```bash
# Editar o arquivo (substitua pelo nome correto)
nano /etc/nginx/sites-enabled/supabase-ssl
# ou
nano /etc/nginx/sites-enabled/default
```

### 2.4. Adicionar location /send-message

**IMPORTANTE:** Adicione ANTES do `location /` no bloco HTTPS (porta 443).

Procure por algo assim:
```nginx
server {
    listen 443 ssl http2;
    server_name api.taskflowv3.com.br;
    
    # ... configurações SSL ...
    
    location / {          # <-- Adicione ANTES desta linha
        proxy_pass http://127.0.0.1:8000;
        # ...
    }
}
```

**Adicione isto ANTES do `location /`:**
```nginx
    # Proxy para Telegram webhook (Node.js porta 3001)
    location /send-message {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Content-Type application/json;
        
        # Timeouts aumentados
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # CORS
        add_header Access-Control-Allow-Origin * always;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
        add_header Access-Control-Allow-Headers "Origin, X-Requested-With, Content-Type, Accept, Authorization" always;
        
        # OPTIONS preflight
        if ($request_method = OPTIONS) {
            return 204;
        }
    }
```

### 2.5. Testar e recarregar Nginx

```bash
# Testar configuração
nginx -t

# Se der OK, recarregar
systemctl reload nginx

# Verificar se recarregou sem erros
systemctl status nginx
```

## 3. Liberar Porta 3001 no Firewall

```bash
# Verificar se firewall está ativo
ufw status

# Se estiver ativo, liberar porta 3001
ufw allow 3001/tcp comment 'Telegram webhook HTTP fallback'

# Verificar se foi liberada
ufw status | grep 3001
```

## 4. Verificar se Node.js está Escutando Corretamente

```bash
# Verificar em qual interface está escutando
netstat -tlnp | grep 3001

# Deve mostrar algo como:
# tcp  0  0 0.0.0.0:3001  0.0.0.0:*  LISTEN  <pid>/node
# ou
# tcp6  0  0 :::3001  :::*  LISTEN  <pid>/node

# Se mostrar apenas 127.0.0.1:3001, o Node.js só aceita conexões locais
# Neste caso, o Nginx pode fazer proxy mesmo assim
```

## 5. Testar Endpoints

### 5.1. Testar localmente (no servidor)

```bash
# Testar endpoint local
curl -X POST http://127.0.0.1:3001/send-message \
  -H 'Content-Type: application/json' \
  -d '{"mensagem_id":"test","thread_type":"TASK","thread_id":"test"}'

# Deve retornar erro sobre mensagem não encontrada (esperado)
# Mas não deve dar 401 ou timeout
```

### 5.2. Testar via Nginx (HTTPS)

```bash
# Testar via Nginx
curl -X POST https://api.taskflowv3.com.br/send-message \
  -H 'Content-Type: application/json' \
  -d '{"mensagem_id":"test","thread_type":"TASK","thread_id":"test"}'

# Deve retornar erro sobre mensagem não encontrada (esperado)
# Mas não deve dar 401 Unauthorized
```

## 6. Verificar Logs (se ainda houver problemas)

```bash
# Logs do Nginx
tail -f /var/log/nginx/error.log

# Logs do Node.js
journalctl -u telegram-webhook -f

# Logs do Nginx de acesso
tail -f /var/log/nginx/access.log
```

## 7. Verificar Configuração Final

```bash
# Ver se location /send-message está configurado
grep -A 20 "location /send-message" /etc/nginx/sites-enabled/*

# Ver se proxy_pass está correto
grep "proxy_pass.*3001" /etc/nginx/sites-enabled/*

# Verificar se Nginx está rodando
systemctl status nginx

# Verificar se Node.js está rodando
systemctl status telegram-webhook
```

## Resumo dos Comandos Essenciais

```bash
# 1. Backup
cp /etc/nginx/sites-enabled/supabase-ssl /etc/nginx/sites-enabled/supabase-ssl.backup

# 2. Editar (adicione location /send-message antes do location /)
nano /etc/nginx/sites-enabled/supabase-ssl

# 3. Testar e recarregar
nginx -t && systemctl reload nginx

# 4. Liberar firewall
ufw allow 3001/tcp

# 5. Testar
curl -X POST http://127.0.0.1:3001/send-message -H 'Content-Type: application/json' -d '{"mensagem_id":"test","thread_type":"TASK","thread_id":"test"}'
```

## Exemplo Completo de Configuração Nginx

Se precisar ver um exemplo completo, aqui está um bloco server completo:

```nginx
server {
    listen 443 ssl http2;
    server_name api.taskflowv3.com.br;

    ssl_certificate /etc/letsencrypt/live/api.taskflowv3.com.br/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.taskflowv3.com.br/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # ===== ADICIONAR ESTE BLOCO =====
    # Proxy para Telegram webhook (Node.js porta 3001)
    location /send-message {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Content-Type application/json;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        add_header Access-Control-Allow-Origin * always;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
        add_header Access-Control-Allow-Headers "Origin, X-Requested-With, Content-Type, Accept, Authorization" always;
        
        if ($request_method = OPTIONS) {
            return 204;
        }
    }
    # ===== FIM DO BLOCO =====

    # Proxy para Supabase (mantenha este como está)
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

## Troubleshooting

### Se ainda der erro 401:

```bash
# Verificar se a configuração foi salva
grep -A 10 "location /send-message" /etc/nginx/sites-enabled/supabase-ssl

# Verificar logs de erro
tail -20 /var/log/nginx/error.log

# Verificar se Nginx recarregou
systemctl status nginx
```

### Se HTTP direto ainda der timeout:

```bash
# Verificar firewall
ufw status | grep 3001

# Verificar se Node.js está escutando
netstat -tlnp | grep 3001

# Testar localmente primeiro
curl http://127.0.0.1:3001/send-message
```

### Se nada funcionar:

```bash
# Verificar se Node.js está rodando
systemctl status telegram-webhook

# Reiniciar Node.js
systemctl restart telegram-webhook

# Ver logs
journalctl -u telegram-webhook -n 50
```
