# 🔧 Solução Final: Erro Kong ao Acessar N8N

## 🚨 Problema Persistente

Mesmo após configurar a ordem correta dos locations, ainda aparece:
```
Kong Error - Invalid authentication credentials
```

Isso indica que o Nginx ainda está enviando requisições para o Supabase/Kong ao invés do N8N.

---

## ✅ Solução Completa (Passo a Passo)

### 1. Diagnosticar o Problema

Execute no servidor:

```bash
ssh root@212.85.0.249
bash diagnosticar_nginx_n8n.sh
```

Ou verifique manualmente:

```bash
# Ver configuração atual
grep -A 20 "location /n8n" /etc/nginx/sites-available/supabase

# Verificar proxy_pass
grep -A 3 "location /n8n" /etc/nginx/sites-available/supabase | grep "proxy_pass"
```

### 2. Corrigir proxy_pass (CRÍTICO)

O `proxy_pass` **DEVE** ter barra no final:

```bash
nano /etc/nginx/sites-available/supabase
```

**Encontre**:
```nginx
location /n8n {
    proxy_pass http://127.0.0.1:5678;  # ❌ ERRADO
```

**Altere para**:
```nginx
location /n8n {
    proxy_pass http://127.0.0.1:5678/;  # ✅ CORRETO (barra no final)
```

**OU use rewrite** (alternativa):
```nginx
location /n8n {
    rewrite ^/n8n/(.*)$ /$1 break;
    rewrite ^/n8n$ / break;
    proxy_pass http://127.0.0.1:5678;
```

### 3. Verificar Configuração Completa

A configuração completa do `location /n8n` deve ser:

```nginx
location /n8n {
    # ✅ IMPORTANTE: barra no final OU rewrite
    proxy_pass http://127.0.0.1:5678/;
    
    # OU usar rewrite:
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

### 4. Testar e Recarregar

```bash
nginx -t
systemctl reload nginx
```

### 5. Testar Acesso

```bash
# Teste 1: Direto no N8N (deve funcionar)
curl http://127.0.0.1:5678/

# Teste 2: Via Nginx HTTPS (deve retornar mesmo resultado)
curl -k https://api.taskflowv3.com.br/n8n/
```

Ambos devem retornar `{"message": "Unauthorized"}` (do N8N).

---

## 🔍 Se Ainda Não Funcionar

### Verificar se há cache do Nginx

```bash
# Limpar cache (se houver)
rm -rf /var/cache/nginx/*
systemctl restart nginx
```

### Verificar se não há outro location interferindo

```bash
# Ver todos os locations no arquivo
grep -n "location" /etc/nginx/sites-available/supabase

# Verificar se há location /n8n/ (com barra) que pode estar interferindo
grep -n "location /n8n" /etc/nginx/sites-available/supabase
```

### Verificar logs detalhados

```bash
# Ativar logs de debug temporariamente
tail -f /var/log/nginx/access.log &
tail -f /var/log/nginx/error.log &

# Acessar no navegador e ver o que aparece nos logs
```

### Testar com path diferente

Se nada funcionar, tente usar um path diferente temporariamente:

```nginx
location /n8n-app {
    proxy_pass http://127.0.0.1:5678/;
    # ... resto da configuração ...
}
```

E acesse: `https://api.taskflowv3.com.br/n8n-app`

---

## 📝 Checklist Final

- [ ] `location /n8n` está ANTES de `location /`
- [ ] `proxy_pass` tem barra no final: `http://127.0.0.1:5678/;`
- [ ] Nginx testado sem erros: `nginx -t`
- [ ] Nginx recarregado: `systemctl reload nginx`
- [ ] N8N está rodando: `docker ps | grep n8n`
- [ ] `curl http://127.0.0.1:5678/` retorna resposta do N8N
- [ ] `curl -k https://api.taskflowv3.com.br/n8n/` retorna mesma resposta
- [ ] Navegador limpo (cache limpo ou guia anônima)

---

## 🚀 Solução Rápida (Script)

Execute o script de correção:

```bash
ssh root@212.85.0.249
bash corrigir_proxy_pass_n8n.sh
```

Este script:
1. Faz backup
2. Adiciona barra no final do `proxy_pass`
3. Testa a configuração
4. Recarrega o Nginx

---

**Após aplicar todas as correções, o N8N deve estar acessível sem erro do Kong!**
