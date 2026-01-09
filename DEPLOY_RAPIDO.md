# ⚡ Deploy Rápido - Aplicação Flutter Web

## 🚀 Deploy em 3 Passos

### 1. Build da Aplicação

```bash
./deploy_app_web.sh
# Escolha a opção 2 (Build + Deploy completo)
```

**OU manualmente:**

```bash
flutter clean
flutter pub get
flutter build web --release
```

### 2. Configurar Variáveis (Primeira vez)

```bash
export PRODUCTION_SERVER=usuario@seu-servidor-hostinger
export REMOTE_PATH=/var/www/html/task2026
```

### 3. Deploy

O script já faz o deploy automaticamente, ou manualmente:

```bash
scp -r build/web/* $PRODUCTION_SERVER:$REMOTE_PATH/
```

## 📝 Configuração do Servidor (Primeira vez)

### Nginx (Recomendado)

```bash
sudo nano /etc/nginx/sites-available/task2026
```

Cole:

```nginx
server {
    listen 80;
    server_name seu-dominio.com.br;
    root /var/www/html/task2026;
    index index.html;
    
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

Ative:

```bash
sudo ln -s /etc/nginx/sites-available/task2026 /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### Apache

O arquivo `.htaccess` já está configurado na pasta `web/`. Certifique-se de que o Apache tem `mod_rewrite` habilitado:

```bash
sudo a2enmod rewrite
sudo systemctl restart apache2
```

## ✅ Pronto!

Acesse: `http://seu-servidor-hostinger` ou `https://seu-dominio.com.br`

## 🔄 Atualizações Futuras

Apenas execute:

```bash
./deploy_app_web.sh
# Opção 2 (Build + Deploy)
```

## 🆘 Problemas?

Veja o guia completo: `DEPLOY_APLICACAO_WEB.md`
