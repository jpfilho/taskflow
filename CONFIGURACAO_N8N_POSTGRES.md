# Configuração N8N - Conexão Postgres Supabase

## ✅ Status: Pronto para Configurar

A porta 5432 já está mapeada e acessível via `supabase-pooler`.

## 📋 Configuração no N8N

Ao criar a conexão Postgres no N8N, use:

```
Host: 212.85.0.249
Port: 5432
Database: postgres
User: postgres
Password: KhVAFkxwia0BttKJ0Z3gnbauuc9z3W5YmVd70WVuA
```

## 🔍 Verificação

- ✅ Porta 5432 está acessível
- ✅ Container `supabase-pooler` está rodando (healthy)
- ✅ Porta mapeada: `0.0.0.0:5432`
- ✅ Senha obtida do arquivo `/root/supabase/docker/.env`

## 📝 Notas

- A conexão passa pelo `supabase-pooler`, que é adequado para o N8N
- Se `postgres` não funcionar como usuário, tente `supabase_admin`
- O database padrão é `postgres`

## 🧪 Teste de Conexão

Após configurar no N8N, teste a conexão. Se houver problemas:

1. Verifique se o container está rodando:
   ```bash
   ssh root@212.85.0.249
   docker ps | grep supabase-pooler
   ```

2. Verifique a porta:
   ```bash
   docker port supabase-pooler 5432
   ```

3. Teste a conexão localmente:
   ```bash
   psql -h 212.85.0.249 -p 5432 -U postgres -d postgres
   ```
