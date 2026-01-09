# Configurar HTTPS para taskflowv3.com.br (com Supabase)

## Situação Atual

- **Domínio**: `taskflowv3.com.br`
- **IP do Servidor**: `212.85.0.249`
- **Supabase**: Já está rodando e acessível via domínio
- **Aplicação Flutter**: Precisa ser acessível via HTTPS em `/task2026/`

## Solução: Nginx como Proxy Reverso

O Nginx irá:
1. Servir a aplicação Flutter em `https://taskflowv3.com.br/task2026/`
2. Fazer proxy reverso para o Supabase em `https://taskflowv3.com.br/`
3. Configurar HTTPS com Let's Encrypt

## Passo a Passo

### 1. Executar Script no Servidor

```bash
# Conectar ao servidor
ssh root@212.85.0.249

# Fazer upload do script (se necessário)
# Ou criar o arquivo diretamente no servidor

# Executar
bash configurar_https_com_supabase.sh
```

### 2. O Script Irá:

- ✅ Verificar se o domínio aponta para o servidor
- ✅ Detectar a porta do Supabase (Docker ou manual)
- ✅ Instalar Certbot
- ✅ Configurar Nginx como proxy reverso
- ✅ Obter certificado SSL do Let's Encrypt
- ✅ Configurar renovação automática

### 3. Acessar a Aplicação

Após a configuração:

- **Aplicação Flutter**: `https://taskflowv3.com.br/task2026/`
- **Supabase**: `https://taskflowv3.com.br/` (continua funcionando)

## Configuração Manual (Alternativa)

Se preferir configurar manualmente:

### 1. Instalar Certbot

```bash
apt update
apt install -y certbot python3-certbot-nginx
```

### 2. Criar Configuração do Nginx

```bash
nano /etc/nginx/sites-available/task2026
```

Cole este conteúdo:

```nginx
# Redirecionar HTTP para HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name taskflowv3.com.br www.taskflowv3.com.br;
    
    # Permitir validação do Let's Encrypt
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # Redirecionar para HTTPS
    location / {
        return 301 https://$host$request_uri;
    }
}

# Configuração HTTPS
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name taskflowv3.com.br www.taskflowv3.com.br;
    
    # Certificados SSL (serão adicionados pelo Certbot)
    # ssl_certificate /etc/letsencrypt/live/taskflowv3.com.br/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/taskflowv3.com.br/privkey.pem;
    
    # Aplicação Flutter
    location /task2026/ {
        alias /var/www/html/task2026/;
        index index.html;
        try_files $uri $uri/ /task2026/index.html;
    }
    
    # Supabase - Proxy reverso
    location / {
        proxy_pass http://localhost:8000;  # Ajuste a porta se necessário
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

### 3. Ativar Site

```bash
ln -sf /etc/nginx/sites-available/task2026 /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx
```

### 4. Obter Certificado SSL

```bash
certbot --nginx -d taskflowv3.com.br -d www.taskflowv3.com.br \
    --non-interactive --agree-tos --email seu@email.com
```

## Verificar Porta do Supabase

Se o script não detectar automaticamente:

```bash
# Ver containers Docker
docker ps

# Ver portas em uso
netstat -tulpn | grep LISTEN
# ou
ss -tulpn | grep LISTEN

# Verificar logs do Supabase
docker logs supabase  # ou nome do container
```

## Verificar Configuração

```bash
# Status do Nginx
systemctl status nginx

# Testar configuração
nginx -t

# Ver certificados
certbot certificates

# Ver logs
tail -f /var/log/nginx/error.log
tail -f /var/log/nginx/access.log
```

## Solução de Problemas

### Erro: "Port 80 already in use"

O Supabase pode estar usando a porta 80. Nesse caso:

1. **Opção 1**: Configure o Supabase para usar outra porta
2. **Opção 2**: Use o Nginx como proxy reverso (recomendado - é o que o script faz)

### Erro: "Failed to obtain certificate"

**Causas:**
- DNS não está apontando corretamente
- Porta 80 bloqueada no firewall
- Supabase está usando a porta 80

**Solução:**
```bash
# Verificar DNS
dig +short taskflowv3.com.br

# Verificar firewall
ufw status
# Se necessário:
ufw allow 80/tcp
ufw allow 443/tcp

# Verificar o que está na porta 80
lsof -i :80
```

### Supabase não funciona após configuração

Verifique se a porta do proxy está correta:

```bash
# Verificar porta do Supabase
docker ps --format "{{.Names}}\t{{.Ports}}"

# Ajustar configuração do Nginx
nano /etc/nginx/sites-available/task2026
# Altere: proxy_pass http://localhost:PORTA_CORRETA;
nginx -t
systemctl reload nginx
```

### Aplicação Flutter não carrega

```bash
# Verificar se os arquivos estão no lugar
ls -la /var/www/html/task2026/

# Verificar permissões
chown -R www-data:www-data /var/www/html/task2026
chmod -R 755 /var/www/html/task2026

# Ver logs do Nginx
tail -50 /var/log/nginx/error.log
```

## Atualizar Aplicação Flutter

Após configurar HTTPS, você pode precisar atualizar a URL do Supabase na aplicação Flutter para usar `https://taskflowv3.com.br` em vez do IP.

Verifique o arquivo de configuração do Supabase na aplicação:
- `lib/services/supabase_service.dart` ou similar
- Variáveis de ambiente
- Arquivo `.env` se houver

## Renovação Automática

O Certbot configura renovação automática. Para verificar:

```bash
# Ver timer
systemctl list-timers | grep certbot

# Testar renovação
certbot renew --dry-run
```

## Segurança

Após configurar, considere:

1. **Habilitar firewall**:
   ```bash
   ufw allow 22/tcp    # SSH
   ufw allow 80/tcp    # HTTP (para Let's Encrypt)
   ufw allow 443/tcp   # HTTPS
   ufw enable
   ```

2. **Configurar fail2ban** (proteção contra ataques):
   ```bash
   apt install -y fail2ban
   systemctl enable fail2ban
   systemctl start fail2ban
   ```
