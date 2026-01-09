# ✅ Checklist SQL - O Que Fazer no Supabase

## 🎯 Script Principal (Execute Primeiro)

**Execute este script primeiro: `VERIFICAR_E_CORRIGIR_TUDO.sql`**

Este script:
- ✅ Verifica a estrutura atual do banco
- ✅ Corrige a tabela `divisoes_segmentos` (chave primária composta e RLS)
- ✅ Adiciona todas as foreign keys necessárias na tabela `tasks`
- ✅ Verifica se a coluna `cor` existe na tabela `status`
- ✅ Mostra relatório final da estrutura

## 📋 Tabelas Necessárias (Ordem de Criação)

### 1. Tabelas Base (Criar Primeiro)
Execute estes scripts na ordem:

1. ✅ `criar_tabela_regionais.sql` - Cadastro de regionais
2. ✅ `criar_tabela_status.sql` - Cadastro de status
3. ✅ `criar_tabela_segmentos.sql` - Cadastro de segmentos

### 2. Tabelas Dependentes
4. ✅ `criar_tabela_divisoes.sql` - Cadastro de divisões (depende de regionais)
5. ✅ `criar_tabela_divisoes_segmentos.sql` - Relacionamento many-to-many (depende de divisoes e segmentos)
6. ✅ `criar_tabela_locais.sql` - Cadastro de locais (depende de regionais, divisoes, segmentos)
7. ✅ `criar_tabela_executores.sql` - Cadastro de executores (depende de divisoes e segmentos)

### 3. Tabelas Principais
8. ✅ `supabase_schema.sql` - Tabelas `tasks` e `gantt_segments` (já devem existir)

### 4. Correções e Migrações
9. ✅ `corrigir_estrutura_divisoes_segmentos.sql` - Corrige estrutura da tabela de relacionamento
10. ✅ `VERIFICAR_E_CORRIGIR_TUDO.sql` - **EXECUTE ESTE PARA VERIFICAR TUDO**

## 🔧 Correções Específicas

### Se a tabela `divisoes_segmentos` já existe com estrutura incorreta:
Execute: `migrar_divisoes_segmentos_para_chave_composta.sql`

### Se precisar adicionar foreign keys na tabela `tasks`:
Execute: `migrar_tasks_para_foreign_keys.sql` e `adicionar_segmento_id_tasks.sql`

### Se precisar adicionar coluna `cor` na tabela `status`:
Execute: `adicionar_coluna_cor_status.sql`

## ✅ Verificação Final

Após executar todos os scripts, verifique:

```sql
-- Verificar se todas as tabelas existem
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN (
    'tasks', 'gantt_segments', 'status', 'regionais', 
    'divisoes', 'segmentos', 'locais', 'executores', 
    'divisoes_segmentos'
  )
ORDER BY table_name;

-- Verificar foreign keys em tasks
SELECT 
    kcu.column_name,
    ccu.table_name AS foreign_table
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.table_name = 'tasks'
    AND tc.constraint_type = 'FOREIGN KEY';

-- Verificar estrutura de divisoes_segmentos
SELECT 
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'divisoes_segmentos';
```

## 🚨 Problemas Comuns

### Erro: "column does not exist"
- Execute `VERIFICAR_E_CORRIGIR_TUDO.sql` que verifica antes de criar

### Erro: "relation already exists"
- Pode ignorar, significa que a tabela já existe

### Erro: "foreign key constraint"
- Verifique se as tabelas dependentes foram criadas primeiro

### Erro: "policy already exists"
- O script `VERIFICAR_E_CORRIGIR_TUDO.sql` remove políticas antigas antes de criar novas

## 📝 Resumo do Que Fazer

1. **Execute `VERIFICAR_E_CORRIGIR_TUDO.sql`** - Este é o script principal que verifica e corrige tudo
2. Se houver erros específicos, execute os scripts de correção correspondentes
3. Verifique o resultado final com as queries de verificação acima

## 🎯 Estrutura Esperada Final

### Tabela `tasks` deve ter:
- ✅ `status_id` (UUID, FK para status)
- ✅ `regional_id` (UUID, FK para regionais)
- ✅ `divisao_id` (UUID, FK para divisoes)
- ✅ `local_id` (UUID, FK para locais)
- ✅ `segmento_id` (UUID, FK para segmentos)

### Tabela `divisoes_segmentos` deve ter:
- ✅ Chave primária composta: `(divisao_id, segmento_id)`
- ✅ **NÃO** deve ter coluna `id` separada
- ✅ Política RLS: `USING (true) WITH CHECK (true)`

### Tabela `status` deve ter:
- ✅ Coluna `cor` (VARCHAR(7))







