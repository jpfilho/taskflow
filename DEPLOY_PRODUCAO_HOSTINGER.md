# 🚀 Deploy para Produção - Hostinger

Este guia explica como colocar em produção no servidor da Hostinger o mesmo que está no seu Supabase local/desenvolvimento.

## 📋 Pré-requisitos

1. **Acesso SSH ao servidor VPS da Hostinger**
2. **Acesso ao Supabase local** (desenvolvimento)
3. **Acesso ao Supabase de produção** (`https://srv750497.hstgr.cloud`)
4. **PostgreSQL client** (`psql`) instalado localmente ou no servidor

## 🔄 Opção 1: Backup e Restore Completo (Recomendado)

### Passo 1: Fazer Backup do Banco Local

```bash
# No seu ambiente local/desenvolvimento
# Substitua as variáveis pelos valores do seu Supabase local
pg_dump -h localhost \
  -U postgres \
  -d postgres \
  -F c \
  -f backup_supabase_local_$(date +%Y%m%d_%H%M%S).dump

# Ou se usar Docker:
docker exec supabase-db pg_dump -U postgres postgres -F c -f /tmp/backup.dump
docker cp supabase-db:/tmp/backup.dump ./backup_supabase_local_$(date +%Y%m%d_%H%M%S).dump
```

### Passo 2: Transferir Backup para o Servidor

```bash
# Usando SCP
scp backup_supabase_local_*.dump usuario@seu-servidor-hostinger:/root/

# Ou usando SFTP
sftp usuario@seu-servidor-hostinger
put backup_supabase_local_*.dump /root/
```

### Passo 3: Restaurar no Servidor de Produção

```bash
# Conectar ao servidor via SSH
ssh usuario@seu-servidor-hostinger

# Localizar o container do banco de dados
docker ps | grep postgres

# Restaurar o backup
# Opção A: Se o banco estiver em Docker
docker exec -i supabase-db pg_restore -U postgres -d postgres --clean --if-exists < backup_supabase_local_*.dump

# Opção B: Se tiver acesso direto ao PostgreSQL
pg_restore -h localhost -U postgres -d postgres --clean --if-exists backup_supabase_local_*.dump
```

## 🔄 Opção 2: Migração Apenas do Schema (Estrutura)

Se você só quer sincronizar a estrutura das tabelas (sem dados):

### Passo 1: Exportar Schema do Local

```bash
# Exportar apenas o schema (estrutura)
pg_dump -h localhost \
  -U postgres \
  -d postgres \
  --schema-only \
  -f schema_only_$(date +%Y%m%d_%H%M%S).sql
```

### Passo 2: Executar no Servidor de Produção

```bash
# Via SQL Editor do Supabase Dashboard
# 1. Acesse: https://srv750497.hstgr.cloud/project/default/sql/new
# 2. Cole o conteúdo do arquivo schema_only_*.sql
# 3. Execute

# OU via psql no servidor:
psql -h localhost -U postgres -d postgres -f schema_only_*.sql
```

## 🔄 Opção 3: Migração Apenas dos Dados

Se você já tem a estrutura e só quer sincronizar os dados:

### Passo 1: Exportar Dados do Local

```bash
# Exportar apenas os dados (sem estrutura)
pg_dump -h localhost \
  -U postgres \
  -d postgres \
  --data-only \
  --column-inserts \
  -f data_only_$(date +%Y%m%d_%H%M%S).sql
```

### Passo 2: Executar no Servidor de Produção

```bash
# Via SQL Editor do Supabase Dashboard
# 1. Acesse: https://srv750497.hstgr.cloud/project/default/sql/new
# 2. Cole o conteúdo do arquivo data_only_*.sql
# 3. Execute

# OU via psql no servidor:
psql -h localhost -U postgres -d postgres -f data_only_*.sql
```

## 🔄 Opção 4: Usar Scripts SQL Existentes

Você já tem vários scripts SQL no projeto. Execute-os na ordem:

### Ordem de Execução Recomendada:

1. **Estrutura Base:**
   - `supabase_schema.sql` (schema principal)
   - `criar_tabela_usuarios.sql`
   - `criar_tabela_executores.sql`
   - `criar_tabela_status.sql`
   - `criar_tabela_tipos_atividade.sql`
   - `criar_tabela_regionais.sql`
   - `criar_tabela_divisoes.sql`
   - `criar_tabela_segmentos.sql`
   - `criar_tabela_locais.sql`
   - `criar_tabela_equipes.sql`
   - `criar_tabela_empresas.sql`
   - `criar_tabela_funcoes.sql`

2. **Tabelas de Relacionamento:**
   - `criar_tabela_divisoes_segmentos.sql`
   - `criar_tabela_executores_segmentos.sql`
   - `criar_tabelas_juncao_tasks.sql`

3. **Tabelas de Funcionalidades:**
   - `criar_tabela_feriados.sql`
   - `criar_tabela_anexos.sql`
   - `criar_tabela_curtidas.sql`
   - `criar_tabela_executor_periods.sql`
   - `criar_tabelas_chat.sql`
   - `criar_tabela_notas_sap.sql`

4. **Configurações e Correções:**
   - `configurar_auth_supabase_sql.sql`
   - `configurar_storage_policies.sql`
   - `adicionar_cor_tipo_atividade.sql`
   - `adicionar_coluna_cor_status.sql`
   - `adicionar_tipo_periodo_gantt_segments.sql`

## 📝 Script Automatizado

Criei um script `deploy_producao.sh` que automatiza o processo. Veja o arquivo para mais detalhes.

## ⚠️ Importante: Antes de Fazer Deploy

1. **Fazer Backup do Banco de Produção:**
   ```bash
   # No servidor de produção
   docker exec supabase-db pg_dump -U postgres postgres -F c -f /tmp/backup_producao_$(date +%Y%m%d_%H%M%S).dump
   docker cp supabase-db:/tmp/backup_producao_*.dump ./
   ```

2. **Verificar Diferenças:**
   ```bash
   # Comparar schemas
   pg_dump --schema-only -h localhost -U postgres -d postgres > schema_local.sql
   pg_dump --schema-only -h servidor-producao -U postgres -d postgres > schema_producao.sql
   diff schema_local.sql schema_producao.sql
   ```

3. **Testar em Ambiente de Staging** (se tiver)

## 🔐 Configuração de Chaves e URLs

Após o deploy, atualize:

1. **Arquivo `mcp_supabase_config.json`:**
   ```json
   {
     "mcpServers": {
       "supabase": {
         "env": {
           "SUPABASE_URL": "https://srv750497.hstgr.cloud",
           "SUPABASE_ANON_KEY": "SUA_CHAVE_ANON_AQUI",
           "SUPABASE_SERVICE_ROLE_KEY": "SUA_SERVICE_ROLE_KEY_AQUI"
         }
       }
     }
   }
   ```

2. **No código Flutter** (`lib/services/*`):
   - Verificar se as URLs estão apontando para produção
   - Atualizar chaves de API se necessário

## ✅ Verificação Pós-Deploy

1. **Verificar Tabelas:**
   ```sql
   SELECT table_name 
   FROM information_schema.tables 
   WHERE table_schema = 'public' 
   ORDER BY table_name;
   ```

2. **Verificar RLS Policies:**
   ```sql
   SELECT schemaname, tablename, policyname 
   FROM pg_policies 
   WHERE schemaname = 'public';
   ```

3. **Testar Aplicação:**
   - Login/Logout
   - CRUD de tarefas
   - Upload de anexos
   - Chat
   - Likes

## 🆘 Em Caso de Problemas

1. **Restaurar Backup:**
   ```bash
   docker exec -i supabase-db pg_restore -U postgres -d postgres --clean --if-exists < backup_producao_*.dump
   ```

2. **Verificar Logs:**
   ```bash
   docker logs supabase-db --tail 100
   docker logs supabase-auth --tail 100
   ```

3. **Verificar Conexões:**
   ```bash
   docker ps
   netstat -tulpn | grep -E "5432|54321|54322"
   ```

## 📞 Próximos Passos

1. Escolha uma das opções acima
2. Execute o backup do ambiente local
3. Transfira e restaure no servidor de produção
4. Verifique se tudo está funcionando
5. Atualize as configurações da aplicação Flutter

Qual opção você prefere usar?
