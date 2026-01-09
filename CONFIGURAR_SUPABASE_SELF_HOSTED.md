# 🔧 Configurar Autenticação no Supabase Self-Hosted (Hostinger)

Como você está usando Supabase self-hosted na Hostinger, a interface pode ser diferente. Vamos configurar via arquivos de configuração ou SQL.

## Opção 1: Via Arquivo .env (Recomendado)

Se você tem acesso SSH ao servidor VPS da Hostinger:

1. **Acesse o servidor via SSH**
2. **Localize o diretório do Supabase** (geralmente em `/opt/supabase` ou similar)
3. **Edite o arquivo `.env`** ou `config.toml`
4. **Procure por estas variáveis:**

```env
# Desabilitar confirmação de email
ENABLE_EMAIL_CONFIRMATION=false

# Habilitar signup
ENABLE_SIGNUP=true

# Site URL (ajuste conforme necessário)
SITE_URL=http://localhost:3000
```

5. **Reinicie o Supabase:**
```bash
docker-compose restart
# ou
supabase stop && supabase start
```

## Opção 2: Via SQL (Se tiver acesso ao banco)

Execute no SQL Editor do Supabase:

```sql
-- Verificar se existe tabela de configuração
SELECT * FROM information_schema.tables 
WHERE table_schema = 'auth';

-- Tentar atualizar configurações (se a tabela existir)
UPDATE auth.config 
SET value = 'false' 
WHERE name = 'ENABLE_EMAIL_CONFIRMATION';
```

## Opção 3: Via API do Supabase (Se disponível)

Se o Supabase self-hosted tiver API de configuração, você pode usar:

```bash
curl -X PATCH 'http://seu-servidor-supabase/auth/v1/admin/settings' \
  -H 'apikey: SUA_CHAVE_SERVICE_ROLE' \
  -H 'Content-Type: application/json' \
  -d '{
    "ENABLE_EMAIL_CONFIRMATION": false
  }'
```

## Opção 4: Modificar o Código do App (Solução Temporária)

Como alternativa temporária, podemos modificar o código para lidar com o erro:

1. **Modificar o AuthService** para não depender de confirmação de email
2. **Tratar o erro 500** e considerar o usuário como criado mesmo com o erro

## Verificar Configuração Atual

Execute este SQL para ver o que está configurado:

```sql
-- Ver todas as configurações de auth
SELECT * FROM pg_settings WHERE name LIKE '%auth%';

-- Ver usuários criados (mesmo com erro)
SELECT id, email, email_confirmed_at, created_at 
FROM auth.users 
ORDER BY created_at DESC 
LIMIT 10;
```

## Solução Rápida: Modificar o App para Ignorar o Erro

Se não conseguir acessar as configurações do servidor, posso modificar o código do app para:
1. Tentar criar o usuário
2. Se der erro 500 de email, considerar como sucesso
3. Fazer login automaticamente

Qual opção você prefere tentar primeiro?






