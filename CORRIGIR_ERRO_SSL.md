# 🔧 Corrigir Erro SSL - ERR_SSL_PROTOCOL_ERROR

## 🔴 Problema

O navegador está tentando acessar via HTTPS, mas o servidor não está configurado para SSL.

## ✅ Solução Rápida

### Opção 1: Acessar via HTTP (sem HTTPS)

**Use HTTP ao invés de HTTPS:**

```
http://212.85.0.249/task2026/
```

**NÃO use:**
```
https://212.85.0.249/task2026/  ❌
```

### Opção 2: Limpar cache do navegador

O navegador pode estar tentando forçar HTTPS. Limpe o cache:

1. Pressione `Ctrl + Shift + Delete` (Windows/Linux) ou `Cmd + Shift + Delete` (Mac)
2. Selecione "Imagens e arquivos em cache"
3. Limpe os dados

### Opção 3: Modo anônimo/privado

Teste em uma janela anônima/privada:
- Chrome: `Ctrl + Shift + N` (Windows) ou `Cmd + Shift + N` (Mac)
- Firefox: `Ctrl + Shift + P` (Windows) ou `Cmd + Shift + P` (Mac)

## 🔒 Configurar HTTPS (Opcional - Para Produção)

Se quiser usar HTTPS, você precisa:

1. **Instalar certificado SSL** (Let's Encrypt é gratuito):

```bash
ssh root@212.85.0.249

# Instalar Certbot
sudo apt update
sudo apt install certbot python3-certbot-nginx  # Para Nginx
# ou
sudo apt install certbot python3-certbot-apache  # Para Apache

# Obter certificado
sudo certbot --nginx -d seu-dominio.com.br
# ou
sudo certbot --apache -d seu-dominio.com.br
```

2. **Configurar redirecionamento HTTP → HTTPS** no servidor web

## 📝 Verificar Configuração do Servidor

Conecte-se ao servidor e verifique qual servidor web está rodando:

```bash
ssh root@212.85.0.249

# Verificar se Nginx está rodando
systemctl status nginx

# Verificar se Apache está rodando
systemctl status apache2
```

## 🎯 Solução Imediata

**Acesse via HTTP:**
```
http://212.85.0.249/task2026/
```

Se ainda não funcionar, verifique se o servidor web está configurado corretamente para servir arquivos estáticos.
