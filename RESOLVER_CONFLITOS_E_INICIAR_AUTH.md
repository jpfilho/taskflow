# 🔧 Resolver Conflitos e Iniciar Auth Corretamente

## Situação:
- `supabase-db` está rodando e saudável ✅
- `supabase-auth` foi removido ❌
- Containers conflitantes impedem `docker-compose up -d`

## Solução:

### Opção 1: Iniciar apenas o auth (recomendado, já que db está rodando)

```bash
cd /root/supabase/docker

# Iniciar apenas o auth (sem --no-deps para incluir dependências de rede)
docker-compose up -d auth

# Verificar se iniciou
docker ps | grep supabase-auth

# Ver logs
docker logs supabase-auth --tail 30
```

### Opção 2: Se ainda der erro de rede, forçar recriação do auth

```bash
cd /root/supabase/docker

# Parar e remover o auth se existir
docker stop supabase-auth 2>/dev/null
docker rm supabase-auth 2>/dev/null

# Forçar recriação do auth
docker-compose up -d --force-recreate auth

# Verificar
docker ps | grep supabase-auth
docker logs supabase-auth --tail 30
```

### Opção 3: Se quiser resolver todos os conflitos de uma vez

```bash
cd /root/supabase/docker

# Remover containers conflitantes (CUIDADO: isso pode parar serviços)
docker rm -f supabase-vector supabase-imgproxy 2>/dev/null

# NÃO remover o db, ele está funcionando!

# Agora iniciar todos os serviços
docker-compose up -d

# Verificar auth
docker ps | grep supabase-auth
docker logs supabase-auth --tail 30
```

**Recomendação:** Use a **Opção 1** primeiro, pois o `db` já está funcionando e não precisa ser recriado.






