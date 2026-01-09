# 🔍 Verificar e Reiniciar Container

## Erro Atual:
"name resolution failed" (503) - O container pode ter parado ou há problema de rede.

## Solução Rápida:

### 1. Verificar se o container está rodando:
```bash
docker ps | grep supabase-auth
```

### 2. Se não estiver rodando, ver todos os containers:
```bash
docker ps -a | grep supabase-auth
```

### 3. Se o container existir mas estiver parado, iniciar:
```bash
docker start supabase-auth
```

### 4. Se o container não existir ou houver erro, restaurar backup do docker-compose.yml:
```bash
cd /root/supabase/docker
ls -la docker-compose.yml.backup*
# Use o backup mais recente
cp docker-compose.yml.backup.* docker-compose.yml
```

### 5. Tentar iniciar apenas o container auth (sem validar o YAML completo):
```bash
cd /root/supabase/docker
docker-compose up -d supabase-auth --no-deps
```

### 6. Ou usar docker diretamente (se docker-compose falhar):
```bash
# Ver a configuração do container original
docker inspect supabase-auth | grep -A 20 "Env"

# Iniciar o container existente
docker start supabase-auth
```

### 7. Verificar logs:
```bash
docker logs supabase-auth --tail 30
```

### 8. Verificar se está acessível:
```bash
docker exec supabase-auth env | grep -i "MAILER_AUTOCONFIRM"
```

## Solução Alternativa (Se nada funcionar):

Se o docker-compose.yml estiver muito quebrado, você pode:

1. **Restaurar do backup original**
2. **Editar APENAS a linha do GOTRUE_MAILER_AUTOCONFIRM manualmente**
3. **Reiniciar o container sem recriar**

**Execute primeiro o comando `docker ps | grep supabase-auth` e me mostre o resultado!**






