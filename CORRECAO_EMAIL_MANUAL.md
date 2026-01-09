# 🔧 Correção Manual da Configuração de Email

## Problema Identificado:

No arquivo `.env` original, há uma inconsistência:
- ❌ `ENABLE_EMAIL_AUTOCONFIRM=false` (está desabilitando auto-confirmação)
- ✅ `GOTRUE_MAILER_AUTOCONFIRM=true` (correto)
- ✅ `ENABLE_EMAIL_CONFIRMATION=false` (correto)

## Solução:

Execute estes comandos no servidor:

### 1. Acessar o diretório:
```bash
cd /root/supabase/docker
```

### 2. Fazer backup:
```bash
cp .env .env.backup
```

### 3. Editar o arquivo:
```bash
nano .env
```

### 4. Localizar e alterar esta linha:
**DE:**
```env
ENABLE_EMAIL_AUTOCONFIRM=false
```

**PARA:**
```env
ENABLE_EMAIL_AUTOCONFIRM=true
```

### 5. Salvar:
- `Ctrl + O` (salvar)
- `Enter` (confirmar)
- `Ctrl + X` (sair)

### 6. Verificar as configurações:
```bash
grep -E "ENABLE_EMAIL_AUTOCONFIRM|GOTRUE_MAILER_AUTOCONFIRM|ENABLE_EMAIL_CONFIRMATION" .env
```

**Deve mostrar:**
```
ENABLE_EMAIL_AUTOCONFIRM=true
GOTRUE_MAILER_AUTOCONFIRM=true
ENABLE_EMAIL_CONFIRMATION=false
```

### 7. Reiniciar o container:
```bash
docker-compose restart supabase-auth
```

### 8. Verificar logs:
```bash
docker logs supabase-auth --tail 20
```

## Ou use o script automático:

```bash
cd /root/supabase/docker
chmod +x corrigir_email_confirmation.sh
./corrigir_email_confirmation.sh
```

## Teste:

Após reiniciar, teste criar um novo usuário no app Flutter. O erro não deve mais aparecer!






