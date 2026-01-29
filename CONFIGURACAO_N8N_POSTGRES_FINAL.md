# Configuração N8N - Postgres (Baseado na Documentação Oficial)

## Configurações Necessárias

### 1. Host
- **Se N8N está no mesmo servidor:** Use `localhost` ou `127.0.0.1`
- **Se N8N está em outro servidor:** Use o IP `212.85.0.249` ou hostname do servidor

**Para verificar o host correto no Postgres:**
```sql
SELECT inet_server_addr();
```

### 2. Database
- **Valor:** `postgres`

**Para verificar o database correto:**
Execute `/conninfo` no psql ou verifique a configuração.

### 3. User
- **Valor:** `postgres`

### 4. Password
- **Valor:** `KhVAFkxwia0BttKJ0Z3gnbauuc9z3W5YmVd70WVuA`

### 5. Port
- **Valor:** `5433`

**Para verificar a porta correta no Postgres:**
```sql
SELECT inet_server_port();
```

### 6. Ignore SSL Issues
- **Recomendado:** ✅ **Ativado** (para conexões locais ou sem certificado)

### 7. SSL
- **Recomendado:** `Disable` ou `Allow`
  - **Disable:** Apenas conexões não-SSL
  - **Allow:** Tenta não-SSL primeiro, depois SSL se falhar
  - **Require:** Apenas conexões SSL (requer certificado válido)

### 8. SSH Tunnel
- **Recomendado:** ❌ **Desativado** (a menos que necessário)
- **Limitações:** Só funciona com o node Postgres (não funciona com Agent node)
- Requer SSH server no mesmo servidor do Postgres

## Configuração Recomendada (N8N no mesmo servidor)

```
Host: localhost
Port: 5433
Database: postgres
User: postgres
Password: KhVAFkxwia0BttKJ0Z3gnbauuc9z3W5YmVd70WVuA
Ignore SSL Issues: ✅ Ativado
SSL: Disable
SSH Tunnel: ❌ Desativado
```

## Configuração Recomendada (N8N em outro servidor)

```
Host: 212.85.0.249
Port: 5433
Database: postgres
User: postgres
Password: KhVAFkxwia0BttKJ0Z3gnbauuc9z3W5YmVd70WVuA
Ignore SSL Issues: ✅ Ativado
SSL: Disable
SSH Tunnel: ❌ Desativado
```

## Troubleshooting

### Se ainda não conectar:

1. **Verifique se o N8N está no mesmo servidor:**
   ```powershell
   .\verificar_n8n_e_testar_conexao.ps1
   ```

2. **Teste a conexão diretamente do servidor:**
   ```bash
   ssh root@212.85.0.249
   PGPASSWORD='KhVAFkxwia0BttKJ0Z3gnbauuc9z3W5YmVd70WVuA' psql -h localhost -p 5433 -U postgres -d postgres -c "SELECT version();"
   ```

3. **Verifique os logs do N8N:**
   - Procure por mensagens de erro específicas sobre conexão
   - Verifique se há timeout ou erro de autenticação

4. **Verifique se o Postgres aceita conexões externas:**
   ```bash
   docker exec supabase-db psql -U postgres -c "SHOW listen_addresses;"
   ```
   - Deve mostrar `*` ou `0.0.0.0` para aceitar conexões externas

5. **Teste com SSL desabilitado:**
   - Certifique-se de que "SSL" está configurado como `Disable`
   - Ative "Ignore SSL Issues" como backup

## Referência

Documentação oficial: https://docs.n8n.io/integrations/builtin/credentials/postgres/#using-database-connection
