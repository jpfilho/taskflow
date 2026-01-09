# ✅ Configurar Email no Supabase VPS

## Localização Encontrada:
- **Docker Compose:** `/root/supabase/docker/docker-compose.yml`
- **Arquivo .env:** `/root/supabase/docker/.env`
- **Container Auth:** `supabase-auth` (rodando)

## Passos para Desabilitar Confirmação de Email:

### 1. Acessar o diretório do Supabase:
```bash
cd /root/supabase/docker
```

### 2. Ver o conteúdo atual do .env:
```bash
cat .env | grep -i email
cat .env | grep -i auth
```

### 3. Editar o arquivo .env:
```bash
nano .env
# ou
vi .env
```

### 4. Procurar ou adicionar estas variáveis:

Procure por:
- `GOTRUE_MAILER_AUTOCONFIRM=true` (ou `false`)
- `ENABLE_EMAIL_CONFIRMATION=false`
- `GOTRUE_MAIL_ENABLED=true`

**Adicione ou modifique para:**
```env
# Desabilitar confirmação de email
GOTRUE_MAILER_AUTOCONFIRM=true

# Ou se não existir, adicione:
ENABLE_EMAIL_CONFIRMATION=false
```

### 5. Salvar o arquivo:
- **Nano:** `Ctrl + O` (salvar), `Enter`, `Ctrl + X` (sair)
- **Vi:** `:wq` (salvar e sair)

### 6. Reiniciar o container de autenticação:
```bash
cd /root/supabase/docker
docker-compose restart supabase-auth
```

### 7. Verificar se funcionou:
```bash
docker logs supabase-auth | tail -20
```

## Alternativa: Editar via Docker Compose

Se preferir, você também pode editar o `docker-compose.yml`:

```bash
cd /root/supabase/docker
nano docker-compose.yml
```

Procure pela seção do `supabase-auth` e adicione:
```yaml
environment:
  - GOTRUE_MAILER_AUTOCONFIRM=true
```

Depois reinicie:
```bash
docker-compose restart supabase-auth
```

## Verificar Configuração Atual

Execute para ver todas as variáveis relacionadas a email:
```bash
cd /root/supabase/docker
grep -i "mail\|email\|confirm" .env
```

## Teste Final

Após reiniciar, teste criar um novo usuário no app Flutter. O erro de confirmação de email não deve mais aparecer.






