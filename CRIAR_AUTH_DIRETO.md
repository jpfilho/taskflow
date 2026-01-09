# 🔧 Criar Container Auth Diretamente (Bypass docker-compose)

## Problema:
O `docker-compose` está dando erro `KeyError: 'ContainerConfig'`. Vamos criar o container diretamente.

## Solução: Criar o container auth manualmente

```bash
cd /root/supabase/docker

# 1. Verificar a rede Docker que o db está usando
docker inspect supabase-db | grep -A 10 "Networks"

# 2. Criar o container auth diretamente na mesma rede
# (Substitua 'supabase_default' pela rede que o db está usando)
docker run -d \
  --name supabase-auth \
  --network supabase_default \
  -e GOTRUE_API_HOST=0.0.0.0 \
  -e GOTRUE_API_PORT=9999 \
  -e GOTRUE_DB_DRIVER=postgres \
  -e GOTRUE_DB_DATABASE_URL=postgres://supabase_auth_admin:postgres@db:5432/postgres \
  -e GOTRUE_SITE_URL=http://localhost:3000 \
  -e GOTRUE_URI_ALLOW_LIST=http://localhost:3000 \
  -e GOTRUE_DISABLE_SIGNUP=false \
  -e GOTRUE_JWT_SECRET=your-super-secret-jwt-token-with-at-least-32-characters-long \
  -e GOTRUE_JWT_EXP=3600 \
  -e GOTRUE_JWT_DEFAULT_GROUP_NAME=authenticated \
  -e GOTRUE_EXTERNAL_EMAIL_ENABLED=true \
  -e GOTRUE_MAILER_AUTOCONFIRM=true \
  -e GOTRUE_SMTP_HOST=supabase-mail \
  -e GOTRUE_SMTP_PORT=2500 \
  -e GOTRUE_SMTP_USER=fake_mail_user \
  -e GOTRUE_SMTP_PASS=fake_mail_password \
  -e GOTRUE_SMTP_ADMIN_EMAIL=admin@example.com \
  -e GOTRUE_SMTP_SENDER_NAME=fake_sender \
  supabase/gotrue:v2.180.0 \
  auth

# 3. Verificar se iniciou
docker ps | grep supabase-auth

# 4. Ver logs
docker logs supabase-auth --tail 30
```

**OU** use o docker-compose.yml para pegar as variáveis de ambiente:

```bash
cd /root/supabase/docker

# Extrair a configuração do auth do docker-compose.yml
docker-compose config | grep -A 50 "auth:"

# Depois criar manualmente com essas variáveis
```

**OU** tente atualizar o docker-compose:

```bash
# Atualizar docker-compose
pip3 install --upgrade docker-compose

# Ou usar docker compose (sem hífen, versão mais nova)
docker compose up -d auth
```






