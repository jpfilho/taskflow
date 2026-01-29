# 🔧 Corrigir Erro "Kong Error" ao Acessar N8N

## 🚨 Problema

Ao acessar `https://api.taskflowv3.com.br/n8n`, você vê:
```
Kong Error - Invalid authentication credentials
```

**Causa**: O Nginx está processando o `location /` (Supabase) **ANTES** do `location /n8n`, então todas as requisições vão para o Supabase/Kong ao invés do N8N.

---

## ✅ Solução

### 1. Verificar Ordem dos Locations

Execute no servidor:

```bash
ssh root@212.85.0.249
bash verificar_nginx_n8n.sh
```

Ou verifique manualmente:

```bash
grep -n "location" /etc/nginx/sites-available/supabase | grep -E "(location /n8n|location / )"
```

**O `location /n8n` DEVE estar em uma linha ANTERIOR ao `location /`**.

### 2. Corrigir Ordem (se necessário)

Se o `location /n8n` estiver DEPOIS do `location /`, você precisa movê-lo:

```bash
nano /etc/nginx/sites-available/supabase
```

**Estrutura correta** (dentro do bloco `server` com `listen 443`):

```nginx
server {
    listen 443 ssl http2;
    server_name api.taskflowv3.com.br;
    
    # ... configurações SSL ...
    
    # ✅ N8N PRIMEIRO (location mais específico)
    location /n8n {
        proxy_pass http://127.0.0.1:5678;
        # ... configurações ...
    }
    
    # ✅ Supabase DEPOIS (location genérico)
    location / {
        proxy_pass http://127.0.0.1:8000;
        # ... configurações ...
    }
}
```

**IMPORTANTE**: No Nginx, locations mais específicos devem vir ANTES dos genéricos.

### 3. Testar e Recarregar

```bash
nginx -t
systemctl reload nginx
```

### 4. Testar Acesso

```bash
curl -k https://api.taskflowv3.com.br/n8n/
```

Deve retornar `{"message": "Unauthorized"}` (do N8N), **NÃO** erro do Kong.

---

## 🔍 Verificação Rápida

Para verificar rapidamente se está correto:

```bash
# Ver ordem dos locations no bloco HTTPS
grep -A 100 "listen 443" /etc/nginx/sites-available/supabase | grep -n "location" | head -5
```

A saída deve mostrar `location /n8n` com número menor que `location /`.

---

## 📝 Exemplo de Estrutura Correta

```nginx
server {
    listen 443 ssl http2;
    server_name api.taskflowv3.com.br;
    
    ssl_certificate /etc/letsencrypt/live/api.taskflowv3.com.br/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.taskflowv3.com.br/privkey.pem;
    
    # ... outras configurações SSL ...
    
    # ✅ CORRETO: location /n8n ANTES de location /
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
    
    # ✅ CORRETO: location / DEPOIS (genérico)
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_buffering off;
    }
}
```

---

## ⚠️ Se Ainda Não Funcionar

1. **Verificar se N8N está rodando**:
   ```bash
   docker ps | grep n8n
   ```

2. **Verificar logs do Nginx**:
   ```bash
   tail -20 /var/log/nginx/error.log
   ```

3. **Testar proxy diretamente**:
   ```bash
   curl http://127.0.0.1:5678/
   ```
   Deve retornar resposta do N8N (não Kong).

4. **Verificar se não há outro location interferindo**:
   ```bash
   grep -n "location" /etc/nginx/sites-available/supabase
   ```

---

**Após corrigir, o N8N deve estar acessível em `https://api.taskflowv3.com.br/n8n` sem erro do Kong!**
