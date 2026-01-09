# Configurar Nginx na Porta 8080

## Comandos para Executar no Servidor

Execute estes comandos **no servidor** (via SSH):

```bash
# 1. Criar/atualizar configuração do Nginx
cat > /etc/nginx/sites-available/task2026 << 'EOF'
server {
    listen 8080;
    server_name 212.85.0.249;
    
    root /var/www/html/task2026;
    index index.html;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/json application/wasm;
    
    # Cache para assets estáticos
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot|wasm)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Fallback para SPA (Single Page Application)
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
EOF

# 2. Ativar site
ln -sf /etc/nginx/sites-available/task2026 /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# 3. Testar configuração
nginx -t

# 4. Se o teste passar, recarregar Nginx
systemctl reload nginx

# 5. Verificar status
systemctl status nginx

# 6. Verificar se está escutando na porta 8080
netstat -tulpn | grep :8080
# ou
ss -tulpn | grep :8080

# 7. Testar acesso local
curl -I http://localhost:8080/task2026/
```

## Acessar a Aplicação

Após configurar, acesse:

```
http://212.85.0.249:8080/task2026/
```

## Verificar se Está Funcionando

```bash
# Ver status do Nginx
systemctl status nginx

# Ver logs do Nginx
tail -f /var/log/nginx/error.log
tail -f /var/log/nginx/access.log

# Verificar permissões
ls -ld /var/www/html/task2026/
ls -la /var/www/html/task2026/ | head -10
```

## Solução de Problemas

### Se o Nginx não iniciar:

```bash
# Verificar erros
nginx -t
journalctl -xeu nginx.service

# Verificar se a porta 8080 está livre
netstat -tulpn | grep :8080
```

### Se a aplicação não carregar:

```bash
# Verificar se os arquivos estão no lugar
ls -la /var/www/html/task2026/

# Verificar permissões
chown -R www-data:www-data /var/www/html/task2026
chmod -R 755 /var/www/html/task2026

# Verificar logs do Nginx
tail -50 /var/log/nginx/error.log
```
