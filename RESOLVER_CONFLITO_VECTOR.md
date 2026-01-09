# 🔧 Resolver Conflito com Container supabase-vector

## Problema:
O container `supabase-vector` já existe e está causando conflito ao tentar iniciar o `auth`.

## Solução:

### Opção 1: Remover o container conflitante e iniciar apenas o auth
```bash
cd /root/supabase/docker

# Remover o container conflitante
docker rm -f a38bdad7426b313eed75bd0fa17f62535d11f2b067f112bcbb6a19fb1b0e4738

# Ou remover pelo nome
docker rm -f supabase-vector

# Iniciar apenas o auth (sem dependências)
docker-compose up -d --no-deps auth
```

### Opção 2: Remover e recriar todos os containers
```bash
cd /root/supabase/docker

# Parar todos os serviços
docker-compose down

# Remover o container conflitante
docker rm -f supabase-vector

# Iniciar todos os serviços novamente
docker-compose up -d
```

### Opção 3: Verificar e limpar containers órfãos
```bash
cd /root/supabase/docker

# Ver todos os containers (rodando e parados)
docker ps -a | grep supabase

# Remover containers parados
docker-compose down

# Limpar containers órfãos
docker container prune -f

# Iniciar novamente
docker-compose up -d
```

**Recomendação:** Use a Opção 1 primeiro, pois é mais rápida e específica.






