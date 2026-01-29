# 🔧 Solução Definitiva: Kong Error no N8N

## 🚨 Problema

As requisições para `https://api.taskflowv3.com.br/n8n` estão indo para o **Supabase/Kong** ao invés do **N8N**.

**Sintoma**: Navegador mostra "Kong Error - Invalid authentication credentials"

---

## ✅ Solução Definitiva

O problema é que o Nginx está processando o `location /` (Supabase) **ANTES** do `location /n8n`. Precisamos garantir que o `location /n8n` seja processado primeiro.

### Passo 1: Diagnosticar

Execute no servidor:

```bash
ssh root@212.85.0.249
bash diagnosticar_roteamento_nginx.sh
```

Isso mostrará:
- Ordem dos locations
- Configuração atual
- Para onde as requisições estão indo

### Passo 2: Forçar location /n8n primeiro

Execute o script que força o `location /n8n` a ser processado primeiro:

```bash
bash forcar_location_n8n.sh
```

Este script:
1. Remove todas as configurações antigas de `/n8n`
2. Insere `location /n8n` **logo no início** do bloco HTTPS (após `listen 443`)
3. Garante que está **ANTES** de qualquer `location /`

### Passo 3: Verificar

```bash
# Ver ordem dos locations
grep -A 150 "listen 443" /etc/nginx/sites-available/supabase | grep -n "location" | head -5

# Testar
curl -k https://api.taskflowv3.com.br/n8n/
```

Deve retornar `{"message": "Unauthorized"}` (do N8N).

---

## 🔧 Correção Manual (Se o script não funcionar)

### 1. Editar Nginx

```bash
nano /etc/nginx/sites-available/supabase
```

### 2. Encontrar o bloco HTTPS

Procure por `listen 443` e encontre o bloco `server` HTTPS.

### 3. Mover location /n8n para o INÍCIO

O `location /n8n` **DEVE** estar logo após as configurações SSL, **ANTES** de qualquer outro `location`.

**Estrutura correta**:

```nginx
server {
    listen 443 ssl http2;
    server_name api.taskflowv3.com.br;
    
    # ... configurações SSL (certificados, protocolos, etc.) ...
    
    # ✅ location /n8n PRIMEIRO (logo após SSL, antes de tudo)
    location /n8n {
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
    
    # ✅ location / DEPOIS (genérico, pega tudo que não foi /n8n)
    location / {
        proxy_pass http://127.0.0.1:8000;
        # ... configurações do Supabase ...
    }
}
```

### 4. Salvar e recarregar

```bash
nginx -t
systemctl reload nginx
```

---

## 🔍 Verificação Final

Após corrigir, verifique:

```bash
# 1. Ordem dos locations
grep -A 150 "listen 443" /etc/nginx/sites-available/supabase | grep -n "location"

# 2. Teste curl
curl -k https://api.taskflowv3.com.br/n8n/
# Deve retornar: {"message": "Unauthorized"}

# 3. Teste no navegador
# Acesse: https://api.taskflowv3.com.br/n8n
# Deve mostrar login do N8N, NÃO erro do Kong
```

---

## ⚠️ Se Ainda Não Funcionar

### Verificar se há location /n8n/ (com barra)

```bash
grep -n "location.*n8n" /etc/nginx/sites-available/supabase
```

Se houver `location /n8n/` (com barra), remova ou renomeie.

### Verificar se há regex interferindo

```bash
grep -n "location ~" /etc/nginx/sites-available/supabase
```

Locations com regex (`~`) têm prioridade diferente.

### Limpar cache e reiniciar

```bash
# Limpar cache do Nginx
rm -rf /var/cache/nginx/*

# Reiniciar (não apenas reload)
systemctl restart nginx
```

### Ver logs em tempo real

```bash
# Terminal 1: Monitorar logs
tail -f /var/log/nginx/access.log | grep n8n

# Terminal 2: Acessar no navegador
# Ver o que aparece nos logs
```

---

## 📝 Checklist Final

- [ ] `location /n8n` está **logo após** `listen 443` (início do bloco HTTPS)
- [ ] `location /n8n` está **ANTES** de `location /`
- [ ] `location /n8n` tem `rewrite` para remover prefixo
- [ ] Nginx testado sem erros: `nginx -t`
- [ ] Nginx reiniciado: `systemctl restart nginx` (não apenas reload)
- [ ] `curl -k https://api.taskflowv3.com.br/n8n/` retorna resposta do N8N
- [ ] Navegador mostra login do N8N (não erro do Kong)

---

**Após aplicar, o N8N deve funcionar corretamente sem erro do Kong!**
