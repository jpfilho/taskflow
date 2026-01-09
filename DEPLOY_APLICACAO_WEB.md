# 🚀 Deploy da Aplicação Flutter Web - Hostinger

Este guia explica como fazer deploy da aplicação Flutter web para o servidor da Hostinger.

## 📋 Pré-requisitos

1. **Flutter SDK instalado** (versão 3.8.1 ou superior)
2. **Acesso SSH ao servidor VPS da Hostinger**
3. **Servidor web configurado** (Nginx ou Apache)
4. **Node.js** (opcional, para otimizações)

## 🔧 Passo 1: Build da Aplicação

### Build para Web (Release)

```bash
# No diretório do projeto
flutter clean
flutter pub get
flutter build web --release
```

Isso criará os arquivos em `build/web/`

### Build Otimizado (Recomendado)

```bash
# Build com otimizações
flutter build web --release --web-renderer canvaskit
```

**Opções de renderer:**
- `canvaskit`: Melhor compatibilidade, maior tamanho
- `html`: Menor tamanho, melhor performance, menos compatibilidade

## 📤 Passo 2: Transferir para o Servidor

### Opção A: Via SCP

```bash
# Transferir pasta build/web para o servidor
scp -r build/web/* usuario@seu-servidor-hostinger:/var/www/html/

# Ou para um subdiretório
scp -r build/web/* usuario@seu-servidor-hostinger:/var/www/html/task2026/
```

### Opção B: Via SFTP

```bash
sftp usuario@seu-servidor-hostinger
cd /var/www/html
put -r build/web/*
```

### Opção C: Via Git (Recomendado para CI/CD)

1. Adicione `build/web/` ao `.gitignore` (já deve estar)
2. No servidor, faça pull e build:
```bash
git pull
flutter build web --release
# Copiar arquivos para diretório web
```

## 🌐 Passo 3: Configurar Servidor Web

### Nginx

Crie ou edite `/etc/nginx/sites-available/task2026`:

```nginx
server {
    listen 80;
    server_name seu-dominio.com.br;
    
    root /var/www/html/task2026;
    index index.html;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/json;
    
    # Cache para assets estáticos
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
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
```

Ative o site:
```bash
sudo ln -s /etc/nginx/sites-available/task2026 /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### Apache

Crie ou edite `/etc/apache2/sites-available/task2026.conf`:

```apache
<VirtualHost *:80>
    ServerName seu-dominio.com.br
    DocumentRoot /var/www/html/task2026
    
    <Directory /var/www/html/task2026>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
        
        # Fallback para SPA
        RewriteEngine On
        RewriteBase /
        RewriteRule ^index\.html$ - [L]
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule . /index.html [L]
    </Directory>
    
    # Gzip compression
    <IfModule mod_deflate.c>
        AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css text/javascript application/javascript application/json
    </IfModule>
    
    # Cache para assets
    <IfModule mod_expires.c>
        ExpiresActive On
        ExpiresByType image/jpg "access plus 1 year"
        ExpiresByType image/jpeg "access plus 1 year"
        ExpiresByType image/png "access plus 1 year"
        ExpiresByType text/css "access plus 1 year"
        ExpiresByType application/javascript "access plus 1 year"
    </IfModule>
</VirtualHost>
```

Ative o site:
```bash
sudo a2ensite task2026.conf
sudo systemctl reload apache2
```

## 🔒 Passo 4: Configurar HTTPS (SSL)

### Usando Let's Encrypt (Certbot)

```bash
# Instalar Certbot
sudo apt update
sudo apt install certbot python3-certbot-nginx  # Para Nginx
# ou
sudo apt install certbot python3-certbot-apache  # Para Apache

# Obter certificado
sudo certbot --nginx -d seu-dominio.com.br
# ou
sudo certbot --apache -d seu-dominio.com.br

# Renovação automática (já configurado por padrão)
sudo certbot renew --dry-run
```

## 🔄 Passo 5: Script de Deploy Automatizado

Use o script `deploy_app_web.sh` para automatizar o processo.

## ✅ Verificação Pós-Deploy

1. **Acesse a aplicação**: `https://seu-dominio.com.br`
2. **Verifique o console do navegador** (F12) para erros
3. **Teste funcionalidades principais**:
   - Login/Logout
   - CRUD de tarefas
   - Upload de arquivos
   - Chat

## 🐛 Troubleshooting

### Erro 404 ao navegar entre páginas

**Causa**: Servidor não configurado para SPA (Single Page Application)

**Solução**: Configure o fallback para `index.html` (veja configurações acima)

### Assets não carregam

**Causa**: Caminho base incorreto

**Solução**: 
```bash
# Rebuild com base-href correto
flutter build web --release --base-href=/task2026/
```

### Erro de CORS

**Causa**: Supabase bloqueando requisições

**Solução**: Configure CORS no Supabase ou use proxy reverso

### Aplicação muito lenta

**Solução**:
- Use `--web-renderer html` para melhor performance
- Habilite compressão Gzip
- Configure cache de assets
- Use CDN para assets estáticos

## 📝 Atualizações Futuras

Para atualizar a aplicação:

```bash
# Local
flutter build web --release
scp -r build/web/* usuario@servidor:/var/www/html/task2026/

# Ou no servidor (se tiver Flutter instalado)
cd /caminho/do/projeto
git pull
flutter build web --release
sudo cp -r build/web/* /var/www/html/task2026/
```

## 🔗 Links Úteis

- [Flutter Web Deployment](https://docs.flutter.dev/deployment/web)
- [Nginx Configuration](https://nginx.org/en/docs/)
- [Apache Configuration](https://httpd.apache.org/docs/)
