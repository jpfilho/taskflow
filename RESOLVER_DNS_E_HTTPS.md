# Resolver DNS e Configurar HTTPS

## Situação Atual

- **Domínio**: `taskflowv3.com.br`
- **IP atual do DNS**: `84.32.84.32`
- **IP do servidor**: `212.85.0.249`
- **Problema**: DNS não está apontando para o servidor correto

## Solução: Atualizar DNS

### Opção 1: Atualizar DNS Diretamente (Recomendado)

1. **Acesse o painel do seu provedor de domínio** (Registro.br, GoDaddy, Namecheap, etc.)

2. **Localize o registro A** para `taskflowv3.com.br`

3. **Atualize o valor** para `212.85.0.249`:
   ```
   Tipo: A
   Nome: @ (ou vazio, ou taskflowv3)
   Valor: 212.85.0.249
   TTL: 3600 (ou padrão)
   ```

4. **Salve as alterações**

5. **Aguarde a propagação** (pode levar de alguns minutos a 24 horas)

6. **Verifique quando propagou**:
   ```bash
   dig +short taskflowv3.com.br
   # Deve retornar: 212.85.0.249
   ```

7. **Execute o script novamente**:
   ```bash
   ssh root@212.85.0.249
   bash configurar_https_com_supabase.sh
   ```

---

### Opção 2: Se Usar Cloudflare

Se você usa Cloudflare como proxy:

1. **Acesse**: https://dash.cloudflare.com

2. **Selecione o domínio** `taskflowv3.com.br`

3. **Vá em DNS > Records**

4. **Localize o registro A** e edite:
   - **Nome**: `@` ou `taskflowv3`
   - **Tipo**: `A`
   - **Conteúdo**: `212.85.0.249`
   - **Proxy**: **DESATIVADO** (ícone de nuvem deve estar **CINZA**, não laranja)
     - ⚠️ **IMPORTANTE**: O proxy do Cloudflare (nuvem laranja) impede o Let's Encrypt de validar
     - Deixe **CINZA** (DNS only) para o Let's Encrypt funcionar

5. **Salve**

6. **Aguarde alguns minutos** para propagar

7. **Verifique**:
   ```bash
   dig +short taskflowv3.com.br
   ```

8. **Execute o script**:
   ```bash
   ssh root@212.85.0.249
   bash configurar_https_com_supabase.sh
   ```

---

### Opção 3: Usar Subdomínio (Alternativa)

Se não quiser alterar o DNS principal, use um subdomínio:

1. **Crie um subdomínio** (ex: `app.taskflowv3.com.br`)

2. **Configure o DNS**:
   ```
   Tipo: A
   Nome: app
   Valor: 212.85.0.249
   ```

3. **Atualize o script** para usar o subdomínio:
   ```bash
   # Editar configurar_https_com_supabase.sh
   # Mudar: DOMINIO="app.taskflowv3.com.br"
   ```

4. **Execute o script**

---

### Opção 4: Certificado Auto-assinado (Temporário)

Se precisar funcionar **agora** sem esperar DNS:

⚠️ **Aviso**: Mostrará aviso de segurança no navegador

```bash
ssh root@212.85.0.249
bash configurar_https_sem_dominio.sh
```

Depois acesse: `https://212.85.0.249/task2026/`

No navegador: Clique em "Avançado" → "Continuar para o site"

---

## Verificar DNS

### Localmente (Mac/Linux):
```bash
dig +short taskflowv3.com.br
# ou
nslookup taskflowv3.com.br
```

### Online:
- https://www.whatsmydns.net/#A/taskflowv3.com.br
- https://dnschecker.org/#A/taskflowv3.com.br

---

## Após DNS Propagado

Quando o DNS estiver correto (`212.85.0.249`):

```bash
# 1. Conectar ao servidor
ssh root@212.85.0.249

# 2. Executar script
bash configurar_https_com_supabase.sh

# 3. Verificar
systemctl status nginx
certbot certificates
```

---

## Verificar Configuração Final

```bash
# Status do Nginx
systemctl status nginx

# Ver certificados
certbot certificates

# Testar HTTPS
curl -I https://taskflowv3.com.br/task2026/

# Ver logs
tail -f /var/log/nginx/error.log
```

---

## URLs Finais

Após configurar:

- **Aplicação Flutter**: `https://taskflowv3.com.br/task2026/`
- **Supabase**: `https://taskflowv3.com.br/`

---

## Solução de Problemas

### DNS não propaga

- Aguarde até 24 horas (normalmente leva 1-4 horas)
- Limpe cache do DNS local: `sudo dscacheutil -flushcache` (Mac)
- Use DNS público: `8.8.8.8` (Google) ou `1.1.1.1` (Cloudflare)

### Let's Encrypt falha após DNS correto

```bash
# Verificar se porta 80 está acessível
curl -I http://taskflowv3.com.br/.well-known/acme-challenge/test

# Ver logs do Certbot
journalctl -u certbot -n 50

# Tentar novamente
certbot --nginx -d taskflowv3.com.br -d www.taskflowv3.com.br
```

### Supabase não funciona após configuração

Verifique a porta do Supabase:

```bash
# Ver containers Docker
docker ps

# Ver portas
netstat -tulpn | grep LISTEN

# Ajustar configuração do Nginx se necessário
nano /etc/nginx/sites-available/task2026
# Altere: proxy_pass http://localhost:PORTA_CORRETA;
nginx -t
systemctl reload nginx
```
