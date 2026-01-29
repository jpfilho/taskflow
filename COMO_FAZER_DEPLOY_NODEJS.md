# Como Fazer Deploy do Node.js

## Método Rápido (Recomendado)

Use o script PowerShell para fazer deploy apenas do arquivo atualizado:

```powershell
.\deploy_nodejs_rapido.ps1
```

Este script:
1. ✅ Faz backup do arquivo atual
2. ✅ Copia o arquivo atualizado
3. ✅ Reinicia o serviço
4. ✅ Verifica se está funcionando

## Método Manual (No Servidor)

Se preferir fazer manualmente no servidor:

### 1. Conectar ao servidor

```bash
ssh root@212.85.0.249
```

### 2. Fazer backup do arquivo atual

```bash
cd /root/telegram-webhook
cp telegram-webhook-server-generalized.js telegram-webhook-server-generalized.js.backup.$(date +%Y%m%d_%H%M%S)
```

### 3. Copiar arquivo atualizado (do Windows)

No PowerShell do Windows:

```powershell
scp telegram-webhook-server-generalized.js root@212.85.0.249:/root/telegram-webhook/
```

### 4. Reiniciar serviço

```bash
systemctl restart telegram-webhook
```

### 5. Verificar status

```bash
systemctl status telegram-webhook --no-pager
```

### 6. Ver logs

```bash
journalctl -u telegram-webhook -f
```

## Método Completo (Primeira Vez)

Se é a primeira vez configurando ou precisa reinstalar tudo:

```powershell
.\deploy_telegram_completo.ps1
```

Este script faz:
- ✅ Instala Node.js (se necessário)
- ✅ Instala dependências NPM
- ✅ Cria serviço systemd
- ✅ Configura Nginx
- ✅ Configura webhook do Telegram

## Verificação Pós-Deploy

### 1. Verificar se serviço está rodando

```bash
systemctl status telegram-webhook
```

Deve mostrar: `Active: active (running)`

### 2. Verificar logs

```bash
journalctl -u telegram-webhook -n 50 --no-pager
```

### 3. Testar endpoint

```bash
curl -X POST http://127.0.0.1:3001/delete-message \
  -H 'Content-Type: application/json' \
  -d '{"mensagem_id": "test-id"}'
```

### 4. Testar via HTTPS

```bash
curl -X POST https://api.taskflowv3.com.br/delete-message \
  -H 'Content-Type: application/json' \
  -d '{"mensagem_id": "test-id"}'
```

## Troubleshooting

### Serviço não inicia

```bash
# Ver logs de erro
journalctl -u telegram-webhook -n 50 --no-pager

# Verificar sintaxe do arquivo
node /root/telegram-webhook/telegram-webhook-server-generalized.js
```

### Erro de permissão

```bash
chmod +x /root/telegram-webhook/telegram-webhook-server-generalized.js
chown root:root /root/telegram-webhook/telegram-webhook-server-generalized.js
```

### Porta 3001 já em uso

```bash
# Ver o que está usando a porta
lsof -i :3001

# Parar processo se necessário
kill -9 <PID>
```

## Estrutura de Arquivos no Servidor

```
/root/telegram-webhook/
├── telegram-webhook-server-generalized.js  # Arquivo principal
├── package.json                           # Dependências
├── node_modules/                          # Pacotes instalados
└── *.backup.*                            # Backups automáticos
```

## Variáveis de Ambiente

O serviço usa estas variáveis (configuradas no systemd):

- `PORT=3001`
- `TELEGRAM_BOT_TOKEN=...`
- `TELEGRAM_WEBHOOK_SECRET=...`
- `SUPABASE_URL=http://127.0.0.1:8000`
- `SUPABASE_SERVICE_KEY=...`

Para alterar, edite:

```bash
nano /etc/systemd/system/telegram-webhook.service
systemctl daemon-reload
systemctl restart telegram-webhook
```
