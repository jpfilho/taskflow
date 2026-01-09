# ✅ Solução Final: Corrigir GOTRUE_MAILER_AUTOCONFIRM

## Problema Identificado:
O container mostra: `GOTRUE_MAILER_AUTOCONFIRM=false`

Isso significa que a configuração não foi aplicada corretamente.

## Solução:

### Passo 1: Editar docker-compose.yml

```bash
cd /root/supabase/docker
nano docker-compose.yml
```

Localize a linha:
```yaml
GOTRUE_MAILER_AUTOCONFIRM: ${ENABLE_EMAIL_AUTOCONFIRM}
```

**Altere para:**
```yaml
GOTRUE_MAILER_AUTOCONFIRM: true
```

Salve: `Ctrl + O`, `Enter`, `Ctrl + X`

### Passo 2: Recriar o Container

Como `docker-compose` não está instalado, use uma destas opções:

#### Opção A: Usar `docker compose` (sem hífen - Docker Compose V2)
```bash
cd /root/supabase/docker
docker compose stop supabase-auth
docker compose rm -f supabase-auth
docker compose up -d supabase-auth
```

#### Opção B: Usar `docker` diretamente
```bash
cd /root/supabase/docker
docker stop supabase-auth
docker rm supabase-auth
docker run -d --name supabase-auth \
  --env-file .env \
  -e GOTRUE_MAILER_AUTOCONFIRM=true \
  --network supabase_default \
  supabase/gotrue:v2.180.0
```

**Mas isso é complicado. Melhor usar a Opção A ou instalar docker-compose.**

#### Opção C: Instalar docker-compose
```bash
apt update
apt install docker-compose
```

Depois use:
```bash
cd /root/supabase/docker
docker-compose stop supabase-auth
docker-compose rm -f supabase-auth
docker-compose up -d supabase-auth
```

### Passo 3: Verificar

```bash
docker exec supabase-auth env | grep -i "MAILER_AUTOCONFIRM"
```

**Deve mostrar:** `GOTRUE_MAILER_AUTOCONFIRM=true`

### Passo 4: Verificar Logs

```bash
docker logs supabase-auth --tail 20
```

## Recomendação:

**Use a Opção A** (`docker compose` sem hífen). Se não funcionar, instale docker-compose (Opção C).

**Execute e me mostre o resultado!**






