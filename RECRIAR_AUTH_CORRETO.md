# ✅ Recriar Container auth (nome correto do serviço)

## Correção:
O serviço no docker-compose.yml se chama `auth`, não `supabase-auth`!

## Comandos Corretos:

### 1. Validar o docker-compose.yml:
```bash
cd /root/supabase/docker
docker-compose config > /dev/null 2>&1 && echo "✅ Válido!" || echo "❌ Ainda há erros"
```

### 2. Recriar o container (usando o nome do serviço):
```bash
docker-compose up -d auth
```

### 3. Verificar se iniciou (usando o nome do container):
```bash
docker ps | grep supabase-auth
```

### 4. Verificar a configuração:
```bash
docker exec supabase-auth env | grep -i "MAILER_AUTOCONFIRM"
```

**Deve mostrar:** `GOTRUE_MAILER_AUTOCONFIRM=true`

### 5. Ver logs:
```bash
docker logs supabase-auth --tail 20
```

### 6. Testar no app:
Após recriar, teste criar um novo usuário. O erro não deve mais aparecer!

**Execute `docker-compose up -d auth` e me mostre o resultado!**






