# Solução Rápida - Conexão N8N com Postgres

## 🎯 Problema

N8N não consegue conectar ao Postgres do Supabase (erro: "Couldn't connect with these settings").

## ✅ Solução Automática

Execute este script para mapear a porta automaticamente:

```powershell
.\mapear_porta_postgres_simples.ps1
```

**OU** se preferir a versão completa com mais verificações:

```powershell
.\mapear_porta_postgres_automatico.ps1
```

O script vai:
1. ✅ Encontrar o `docker-compose.yml` do Supabase
2. ✅ Verificar se a porta já está mapeada
3. ✅ Fazer backup do arquivo
4. ✅ Adicionar mapeamento de porta `5432:5432`
5. ✅ Reiniciar o container
6. ✅ Verificar se funcionou

## 📝 Configuração no N8N

Após executar o script, configure no N8N:

```
Host: 212.85.0.249
Port: 5432
Database: postgres
User: postgres
Password: [senha do Supabase]
SSL: Prefer (ou desabilitado)
Maximum Number of Connections: 100
```

## 🔍 Se o Script Não Funcionar

### Opção 1: Verificar Credenciais

Execute para ver as credenciais corretas:

```powershell
.\verificar_postgres_docker.ps1
```

### Opção 2: Editar Manualmente

1. Acesse o servidor:
   ```bash
   ssh root@212.85.0.249
   ```

2. Encontre o docker-compose.yml:
   ```bash
   find /opt /home /root -name "docker-compose.yml" | xargs grep -l "supabase-db"
   ```

3. Edite o arquivo e adicione na seção `supabase-db:`:
   ```yaml
   supabase-db:
     ports:
       - "5432:5432"
     # ... resto da configuração
   ```

4. Reinicie:
   ```bash
   cd [diretório do docker-compose]
   docker-compose up -d supabase-db
   ```

### Opção 3: Se N8N Estiver no Mesmo Servidor

Se o N8N estiver rodando no servidor `212.85.0.249`, você pode conectar diretamente:

```
Host: 127.0.0.1
Port: 5432
Database: postgres
User: postgres
Password: [senha do Supabase]
```

OU usar o nome do container (se Docker estiver na mesma rede):

```
Host: supabase-db
Port: 5432
Database: postgres
User: postgres
Password: [senha do Supabase]
```

## 🧪 Testar Conexão

Após configurar, teste a conexão no N8N:

1. Abra a credencial Postgres no N8N
2. Clique em **Test** ou **Save**
3. Se aparecer "Connection successful", está funcionando! ✅

## 📚 Scripts Disponíveis

- `mapear_porta_postgres_automatico.ps1` - **Use este primeiro!** Mapeia porta automaticamente
- `verificar_postgres_docker.ps1` - Verifica configuração e credenciais
- `corrigir_porta_postgres_supabase.ps1` - Diagnóstico completo
- `testar_conexao_postgres_n8n.ps1` - Testa conexão do servidor

## ⚠️ Notas Importantes

- O script faz **backup automático** do `docker-compose.yml` antes de modificar
- Se algo der errado, o backup está em: `docker-compose.yml.backup_YYYYMMDD_HHMMSS`
- O container será reiniciado, mas os dados estão seguros (Supabase usa volumes persistentes)
