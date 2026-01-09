# Configurar HTTPS para a Aplicação

## Opção 1: Let's Encrypt (Recomendado - Certificado Válido)

### Pré-requisitos:
- **Domínio** apontando para o IP `212.85.0.249`
- Portas **80** e **443** abertas no firewall

### Passo a Passo:

#### 1. Configurar DNS
Configure o DNS do seu domínio para apontar para `212.85.0.249`:
```
A    app.seudominio.com    212.85.0.249
```

#### 2. Executar Script no Servidor

```bash
# Conectar ao servidor
ssh root@212.85.0.249

# Executar script
bash configurar_https.sh
```

O script irá:
- Instalar Certbot
- Configurar Nginx para HTTPS
- Obter certificado SSL automaticamente
- Configurar renovação automática

#### 3. Acessar a Aplicação

```
https://seudominio.com/task2026/
```

---

## Opção 2: Sem Domínio (Certificado Auto-assinado)

⚠️ **AVISO**: Certificado auto-assinado mostrará aviso de segurança no navegador.

### Executar no Servidor:

```bash
# Conectar ao servidor
ssh root@212.85.0.249

# Executar script
bash configurar_https_sem_dominio.sh
```

### Acessar:

```
https://212.85.0.249/task2026/
```

**No navegador:**
1. Clique em "Avançado" ou "Advanced"
2. Clique em "Continuar para o site" ou "Proceed to site"

---

## Opção 3: Usar Serviço de DNS Dinâmico (Gratuito)

Se você não tem um domínio próprio, pode usar:

### DuckDNS (Recomendado)
1. Acesse: https://www.duckdns.org/
2. Crie uma conta gratuita
3. Crie um subdomínio (ex: `task2026.duckdns.org`)
4. Configure o IP: `212.85.0.249`
5. Use o script `configurar_https.sh` com o domínio DuckDNS

### No-IP
1. Acesse: https://www.noip.com/
2. Crie uma conta gratuita
3. Crie um hostname (ex: `task2026.ddns.net`)
4. Configure o IP: `212.85.0.249`
5. Use o script `configurar_https.sh` com o domínio No-IP

---

## Configuração Manual (Let's Encrypt)

Se preferir configurar manualmente:

```bash
# 1. Instalar Certbot
apt update
apt install -y certbot python3-certbot-nginx

# 2. Configurar Nginx (já deve estar configurado)
# Editar /etc/nginx/sites-available/task2026
# Adicionar bloco server para porta 443 com SSL

# 3. Obter certificado
certbot --nginx -d seudominio.com --non-interactive --agree-tos --email seu@email.com

# 4. Testar renovação
certbot renew --dry-run
```

---

## Verificar Configuração

```bash
# Ver status do Nginx
systemctl status nginx

# Verificar certificado
certbot certificates

# Testar renovação
certbot renew --dry-run

# Ver logs
tail -f /var/log/nginx/error.log
tail -f /var/log/nginx/access.log
```

---

## Renovação Automática

O Certbot configura renovação automática via cron. Para verificar:

```bash
# Ver tarefas agendadas
systemctl list-timers | grep certbot
# ou
cat /etc/cron.d/certbot
```

---

## Solução de Problemas

### Erro: "Failed to obtain certificate"

**Causas possíveis:**
1. DNS não está apontando para o servidor
2. Porta 80 bloqueada no firewall
3. Domínio já tem certificado em outro servidor

**Solução:**
```bash
# Verificar DNS
dig +short seudominio.com

# Verificar firewall
ufw status
# Se necessário, abrir portas:
ufw allow 80/tcp
ufw allow 443/tcp
```

### Erro: "Port 80 already in use"

O Supabase pode estar usando a porta 80. Nesse caso:
1. Configure o Nginx como proxy reverso
2. Ou use porta alternativa para o Supabase
3. Ou use certificado auto-assinado

### Certificado não renova automaticamente

```bash
# Forçar renovação
certbot renew

# Ver logs
journalctl -u certbot.timer
```

---

## Configuração Avançada (Nginx + Supabase)

Se o Supabase estiver usando a porta 80, configure o Nginx como proxy reverso:

```nginx
server {
    listen 80;
    server_name seudominio.com;
    
    # Redirecionar para HTTPS
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name seudominio.com;
    
    ssl_certificate /etc/letsencrypt/live/seudominio.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/seudominio.com/privkey.pem;
    
    # Aplicação Flutter
    location /task2026/ {
        root /var/www/html;
        index index.html;
        try_files $uri $uri/ /task2026/index.html;
    }
    
    # Supabase (se necessário)
    location /supabase/ {
        proxy_pass http://localhost:8000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

---

## Testar HTTPS

```bash
# Testar localmente
curl -I https://seudominio.com/task2026/

# Testar SSL
openssl s_client -connect seudominio.com:443 -servername seudominio.com

# Verificar certificado online
# https://www.ssllabs.com/ssltest/
```

---

## Segurança Adicional

Após configurar HTTPS, considere:

1. **Habilitar HSTS** (já incluído no script)
2. **Configurar firewall**:
   ```bash
   ufw allow 22/tcp    # SSH
   ufw allow 80/tcp    # HTTP (para Let's Encrypt)
   ufw allow 443/tcp   # HTTPS
   ufw enable
   ```

3. **Desabilitar versões antigas de TLS**:
   ```nginx
   ssl_protocols TLSv1.2 TLSv1.3;
   ```

4. **Configurar cipher suites seguros**:
   ```nginx
   ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';
   ssl_prefer_server_ciphers on;
   ```
