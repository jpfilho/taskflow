# ✅ Verificar Deploy - Próximos Passos

## 🎉 Upload Concluído!

Os arquivos foram enviados com sucesso para o servidor!

## 📋 Próximos Passos

### 1. Verificar se os arquivos estão no servidor

Conecte-se ao servidor e verifique:

```bash
ssh root@212.85.0.249
ls -la /var/www/html/task2026/
exit
```

### 2. Verificar permissões

```bash
ssh root@212.85.0.249
chown -R www-data:www-data /var/www/html/task2026
chmod -R 755 /var/www/html/task2026
ls -la /var/www/html/task2026/ | head -10
exit
```

### 3. Configurar Servidor Web (se ainda não estiver configurado)

#### Para Nginx:

Crie o arquivo `/etc/nginx/sites-available/task2026`:

```nginx
server {
    listen 80;
    server_name 212.85.0.249;  # ou seu domínio
    
    root /var/www/html/task2026;
    index index.html;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/json;
    
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
```

Ative o site:

```bash
sudo ln -s /etc/nginx/sites-available/task2026 /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

#### Para Apache:

O arquivo `.htaccess` já está incluído no build. Certifique-se de que o Apache tem `mod_rewrite` habilitado:

```bash
sudo a2enmod rewrite
sudo systemctl restart apache2
```

### 4. Testar a Aplicação

Acesse no navegador:
- `http://212.85.0.249/task2026/`
- Ou seu domínio configurado

### 5. Verificar Console do Navegador

Abra o DevTools (F12) e verifique:
- ✅ Sem erros no console
- ✅ Arquivos carregando corretamente
- ✅ Aplicação iniciando

### 6. Verificar Logs do Servidor (se houver problemas)

```bash
# Nginx
sudo tail -f /var/log/nginx/error.log

# Apache
sudo tail -f /var/log/apache2/error.log
```

## 🐛 Troubleshooting

### Erro 404 ao navegar entre páginas

**Solução**: Configure o fallback para `index.html` (veja configuração acima)

### Assets não carregam

**Solução**: Verifique permissões:
```bash
chown -R www-data:www-data /var/www/html/task2026
chmod -R 755 /var/www/html/task2026
```

### Erro de CORS

**Solução**: Verifique se o Supabase está configurado para aceitar requisições do seu domínio

## ✅ Checklist Final

- [ ] Arquivos enviados para o servidor
- [ ] Permissões configuradas corretamente
- [ ] Servidor web configurado (Nginx/Apache)
- [ ] Aplicação acessível via navegador
- [ ] Sem erros no console do navegador
- [ ] Login funcionando
- [ ] Dados carregando do Supabase

## 🎯 Pronto!

Sua aplicação está em produção! 🚀
