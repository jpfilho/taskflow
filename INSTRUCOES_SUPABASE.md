# ✅ Configuração do Supabase - Status

## 📊 Status Atual

✅ **Configuração do MCP**: Completa
✅ **Chave Anon**: Configurada no código
✅ **Service Role Key**: Configurada no MCP
✅ **Schema SQL**: Pronto em `supabase_schema.sql`

⚠️ **Tabelas**: Precisam ser criadas no banco

## 🚀 Próximos Passos

### Opção 1: Via Dashboard do Supabase (Recomendado)

1. Acesse o dashboard: **https://srv750497.hstgr.cloud/project/default**
2. Vá em **SQL Editor** (menu lateral)
3. Clique em **New Query**
4. Abra o arquivo `supabase_schema.sql` neste projeto
5. Copie TODO o conteúdo
6. Cole no editor SQL
7. Clique em **Run** ou pressione `Cmd+Enter` (Mac) / `Ctrl+Enter` (Windows/Linux)

### Opção 2: Via MCP do Supabase (Se funcionar)

Se o MCP do Supabase estiver funcionando corretamente, você pode pedir:

```
"Execute o SQL do arquivo supabase_schema.sql no meu projeto Supabase"
```

### Opção 3: Via psql (Avançado)

Se você tiver acesso direto ao banco PostgreSQL:

```bash
psql -h [HOST] -U [USER] -d [DATABASE] -f supabase_schema.sql
```

## 📋 O que será criado

1. **Tabela `tasks`**: Armazena todas as tarefas
   - Campos: id, status, regional, divisao, local, tipo, ordem, tarefa, executor, frota, coordenador, si, data_inicio, data_fim, observacoes, horas_previstas, horas_executadas, prioridade, parent_id, etc.

2. **Tabela `gantt_segments`**: Armazena segmentos do gráfico Gantt
   - Campos: id, task_id, data_inicio, data_fim, label, tipo

3. **Índices**: Para melhor performance nas consultas

4. **Triggers**: Para atualizar automaticamente `updated_at` e `data_atualizacao`

5. **Políticas RLS**: Para controle de acesso (atualmente permitindo todas as operações)

## ✅ Verificação

Após executar o SQL, você pode verificar se funcionou:

```bash
# Verificar se as tabelas existem
curl "https://srv750497.hstgr.cloud/rest/v1/tasks?limit=1" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzY1ODE3OTgzLCJleHAiOjIwODExNzc5ODN9.YQByqDrpmw0en7VeEcjDfvvTx8Ind_q8gD6-bzEY4Yc" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzY1ODE3OTgzLCJleHAiOjIwODExNzc5ODN9.YQByqDrpmw0en7VeEcjDfvvTx8Ind_q8gD6-bzEY4Yc"
```

Se retornar `[]` (array vazio) ou dados, as tabelas foram criadas com sucesso!

## 🔧 Configuração do Código

O arquivo `lib/config/supabase_config.dart` já está configurado com:
- ✅ URL: `https://srv750497.hstgr.cloud`
- ✅ Anon Key: Configurada

## 📝 Notas

- O schema SQL usa `CREATE TABLE IF NOT EXISTS`, então é seguro executar múltiplas vezes
- As políticas RLS estão configuradas para permitir todas as operações (ajuste conforme necessário para produção)
- Os triggers atualizam automaticamente os campos `updated_at` e `data_atualizacao`









