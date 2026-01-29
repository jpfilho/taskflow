# Solução para Erro SSL no Telegram (`ERR_CERT_AUTHORITY_INVALID`)

## Problema

Quando o Flutter tenta enviar mensagens para o Telegram via servidor Node.js, ocorre o erro:
```
ERR_CERT_AUTHORITY_INVALID
```

### Causa Raiz

O certificado SSL está configurado apenas para o domínio `api.taskflowv3.com.br`, não para o IP `212.85.0.249`. Quando o DNS falha e o código usa o IP direto como fallback, o certificado SSL não corresponde ao IP, causando o erro.

## Soluções Implementadas

### 1. Correção no Flutter (`telegram_service.dart`)

O código agora:
- Detecta erros de DNS e SSL especificamente
- Quando detecta erro SSL/DNS, tenta usar **HTTP direto na porta 3001** ao invés de HTTPS
- Isso evita o problema de certificado SSL para IP

**Mudança principal:**
```dart
// Antes: Tentava HTTPS no IP (falhava com erro de certificado)
final urlFallback = Uri.parse('https://212.85.0.249/send-message');

// Agora: Usa HTTP direto na porta 3001 (Node.js)
final urlFallback = Uri.parse('http://212.85.0.249:3001/send-message');
```

### 2. Script de Diagnóstico Atualizado

O script `testar_servidor_telegram_rapido.ps1` agora testa:
- HTTP direto na porta 3001 (fallback)
- HTTPS via domínio (preferencial)

## Verificações Necessárias

### 1. Verificar se Node.js aceita HTTP na porta 3001

```bash
ssh root@212.85.0.249 "netstat -tlnp | grep 3001"
```

Deve mostrar algo como:
```
tcp  0  0 0.0.0.0:3001  0.0.0.0:*  LISTEN  <pid>/node
```

### 2. Verificar se firewall permite porta 3001

```bash
ssh root@212.85.0.249 "ufw status | grep 3001"
```

Se não estiver liberada:
```bash
ssh root@212.85.0.249 "ufw allow 3001/tcp"
```

### 3. Verificar DNS

```bash
nslookup api.taskflowv3.com.br
```

Deve retornar `212.85.0.249`. Se não retornar, configure o DNS.

### 4. Verificar certificado SSL

```bash
ssh root@212.85.0.249 "certbot certificates"
```

Verifique se o certificado está válido e não expirado.

## Solução Ideal (Longo Prazo)

### Opção 1: Corrigir DNS (Recomendado)

Garanta que `api.taskflowv3.com.br` sempre resolve para `212.85.0.249`. Assim, o Flutter sempre usará HTTPS com certificado válido.

### Opção 2: Configurar Nginx para aceitar HTTP na porta 3001

Se quiser manter HTTP como fallback, configure o Nginx para fazer proxy também na porta 3001:

```nginx
# Adicionar ao /etc/nginx/sites-available/supabase-ssl
server {
    listen 3001;
    server_name 212.85.0.249;
    
    location /send-message {
        proxy_pass http://127.0.0.1:3001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

**Nota:** Isso expõe HTTP sem SSL. Use apenas como fallback temporário.

### Opção 3: Usar certificado wildcard ou SAN

Configure um certificado que inclua tanto o domínio quanto o IP (não é possível com Let's Encrypt padrão).

## Status Atual

✅ **Correção no Flutter implementada** - Agora usa HTTP na porta 3001 como fallback
✅ **Script de diagnóstico atualizado** - Testa HTTP direto
⚠️ **Verificar se porta 3001 está acessível** - Pode estar bloqueada no firewall
⚠️ **Verificar se Node.js aceita conexões externas** - Pode estar escutando apenas em 127.0.0.1

## Problemas Encontrados nos Testes

### 1. Timeout na Porta 3001 (HTTP Direto)

**Sintoma:** `O tempo limite da operação foi atingido` ao tentar `http://212.85.0.249:3001/send-message`

**Causas possíveis:**
- Firewall bloqueando a porta 3001
- Node.js não está escutando em `0.0.0.0` (apenas em `127.0.0.1`)

**Solução:**
```powershell
# Liberar porta 3001 no firewall
.\liberar_porta_3001.ps1
```

### 2. Erro 401 Unauthorized no HTTPS

**Sintoma:** `{ "message":"Unauthorized" }` ao tentar `https://api.taskflowv3.com.br/send-message`

**Causa:** Nginx não está configurado para fazer proxy do endpoint `/send-message` para o Node.js na porta 3001.

**Solução:**
```powershell
# Configurar Nginx para /send-message
.\corrigir_nginx_send_message.ps1
```

Este script:
- Adiciona configuração `location /send-message` no Nginx
- Faz proxy para `http://127.0.0.1:3001/send-message`
- Configura CORS e timeouts adequados
- Testa e recarrega o Nginx

## Próximos Passos

1. **Execute o script de correção do Nginx:**
   ```powershell
   .\corrigir_nginx_send_message.ps1
   ```

2. **Libere a porta 3001 no firewall (se necessário):**
   ```powershell
   .\liberar_porta_3001.ps1
   ```

3. **Teste novamente:**
   ```powershell
   .\testar_servidor_telegram_rapido.ps1
   ```

4. **Se HTTP na porta 3001 ainda não funcionar:**
   - Verifique se o Node.js está escutando em `0.0.0.0:3001` (não apenas `127.0.0.1`)
   - Verifique logs do Node.js: `ssh root@212.85.0.249 "journalctl -u telegram-webhook -n 50"`

5. **Se possível, corrija o DNS** para que o domínio sempre resolva corretamente

6. **Monitore os logs do Flutter** para ver se o fallback HTTP está funcionando

## Logs Esperados

Quando funcionar corretamente, você verá:
```
🔍 [Telegram] Erro de DNS/SSL detectado. Tentando com IP direto via HTTP como fallback...
📡 [Telegram] Tentando endpoint via IP (HTTP porta 3001): http://212.85.0.249:3001/send-message
✅ [Telegram] Mensagem enviada via IP direto (HTTP): <mensagem_id>
```

Se ainda falhar:
```
⚠️ [Telegram] Fallback para IP (HTTP) também falhou: <erro>
💡 Verifique se a porta 3001 está acessível e o Node.js está rodando
```
