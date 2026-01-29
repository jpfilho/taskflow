# 🔧 Corrigir proxy_pass do N8N - Remover Prefixo

## 🚨 Problema

Mesmo com a ordem correta dos locations, ainda aparece erro do Kong. Isso acontece porque o Nginx está passando o path `/n8n` para o N8N, mas o N8N espera receber requisições na raiz `/`.

**Sintoma**: `curl` funciona, mas navegador mostra erro do Kong.

---

## ✅ Solução

O `proxy_pass` precisa ter uma **barra no final** para remover o prefixo do path.

### Configuração Correta

```nginx
location /n8n {
    # ✅ CORRETO: barra no final remove o prefixo /n8n
    proxy_pass http://127.0.0.1:5678/;
    
    # OU usar rewrite (alternativa)
    # rewrite ^/n8n/(.*)$ /$1 break;
    # rewrite ^/n8n$ / break;
    # proxy_pass http://127.0.0.1:5678;
    
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

### Diferença

- **❌ ERRADO**: `proxy_pass http://127.0.0.1:5678;` (sem barra)
  - Requisição: `https://api.taskflowv3.com.br/n8n/`
  - Enviado para N8N: `http://127.0.0.1:5678/n8n/` ← N8N não entende esse path!

- **✅ CORRETO**: `proxy_pass http://127.0.0.1:5678/;` (com barra)
  - Requisição: `https://api.taskflowv3.com.br/n8n/`
  - Enviado para N8N: `http://127.0.0.1:5678/` ← N8N entende!

---

## 🔧 Como Corrigir

### Opção 1: Script Automático

```bash
ssh root@212.85.0.249
bash corrigir_proxy_pass_n8n.sh
```

### Opção 2: Manual

1. **Editar Nginx**:
   ```bash
   nano /etc/nginx/sites-available/supabase
   ```

2. **Encontrar**:
   ```nginx
   location /n8n {
       proxy_pass http://127.0.0.1:5678;
   ```

3. **Alterar para**:
   ```nginx
   location /n8n {
       proxy_pass http://127.0.0.1:5678/;  # ← Adicionar barra no final
   ```

4. **Salvar e testar**:
   ```bash
   nginx -t
   systemctl reload nginx
   ```

---

## 🧪 Testar

```bash
curl -k https://api.taskflowv3.com.br/n8n/
```

Deve retornar `{"message": "Unauthorized"}` (do N8N).

Agora no navegador também deve funcionar!

---

## 📝 Explicação Técnica

No Nginx, quando você usa:
- `proxy_pass http://backend/;` (com barra) → Remove o prefixo do location
- `proxy_pass http://backend;` (sem barra) → Mantém o path completo

**Exemplo**:
- `location /n8n` + `proxy_pass http://127.0.0.1:5678/;`
- Requisição: `/n8n/login`
- Enviado para backend: `/login` (prefixo `/n8n` removido)

Isso é necessário porque o N8N não sabe que está sendo acessado via `/n8n` - ele espera receber requisições na raiz `/`.

---

**Após corrigir, o N8N deve funcionar tanto no curl quanto no navegador!**
