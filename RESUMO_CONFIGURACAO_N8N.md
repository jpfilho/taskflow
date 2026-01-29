# Resumo - Configuração N8N Postgres

## ✅ Status Atual

- ✅ Porta 5433 mapeada e acessível localmente
- ✅ Firewall liberado (porta 5433)
- ✅ Container supabase-db rodando
- ✅ N8N está no mesmo servidor

## 🔧 Configuração no N8N

Use **EXATAMENTE** estas configurações:

```
Host: localhost
Port: 5433
Database: postgres
User: postgres
Password: KhVAFkxwia0BttKJ0Z3gnbauuc9z3W5YmVd70WVuA
Ignore SSL Issues: ✅ ATIVADO
SSL: Disable
SSH Tunnel: ❌ DESATIVADO
Maximum Number of Connections: 100 (padrão)
```

## ⚠️ Pontos Importantes

1. **Host DEVE ser `localhost`** (não `212.85.0.249`)
2. **Port DEVE ser `5433`** (não 5432)
3. **Ignore SSL Issues DEVE estar ATIVADO**
4. **SSL DEVE estar como `Disable`**
5. **SSH Tunnel DEVE estar DESATIVADO**

## 🔍 Se Ainda Não Funcionar

### 1. Verifique os logs do N8N
```bash
# Se N8N está em Docker
docker logs n8n | tail -50

# Ou verifique os logs do N8N na interface web
```

### 2. Teste a conexão manualmente
```bash
ssh root@212.85.0.249
docker exec -it supabase-db psql -U postgres -d postgres
# Dentro do psql, execute:
\conninfo
```

### 3. Verifique se o usuário postgres tem permissão
```bash
docker exec supabase-db psql -U postgres -c "\du"
```

### 4. Verifique listen_addresses
```bash
docker exec supabase-db psql -U postgres -c "SHOW listen_addresses;"
# Deve mostrar: *
```

## 📝 Checklist Final

- [ ] Host configurado como `localhost` (não IP externo)
- [ ] Port configurada como `5433`
- [ ] Database: `postgres`
- [ ] User: `postgres`
- [ ] Password: `KhVAFkxwia0BttKJ0Z3gnbauuc9z3W5YmVd70WVuA`
- [ ] Ignore SSL Issues: ✅ Ativado
- [ ] SSL: `Disable`
- [ ] SSH Tunnel: ❌ Desativado
- [ ] Clicou em "Save" e depois "Test Connection"

## 🎯 Próximos Passos

1. Configure no N8N com as configurações acima
2. Clique em "Save"
3. Clique em "Test Connection" ou "Retry"
4. Se ainda falhar, verifique os logs do N8N para ver o erro exato
