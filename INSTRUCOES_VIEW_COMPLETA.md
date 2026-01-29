# Instruções para Criar View Completa de Execuções

## Problema
A view `mv_execucoes_dia` atual só inclui períodos de **EXECUÇÃO**, não incluindo períodos de **PLANEJAMENTO** e **DESLOCAMENTO**.

## Solução
Criar uma nova view `mv_execucoes_dia_completa` que inclui **TODOS** os tipos de períodos:
- ✅ EXECUÇÃO
- ✅ PLANEJAMENTO  
- ✅ DESLOCAMENTO

## Passos para Implementar

### 1. Executar o Script SQL

1. Acesse o SQL Editor do Supabase:
   - https://srv750497.hstgr.cloud/project/default/sql/new
   - Ou use o dashboard do seu Supabase

2. Abra o arquivo `criar_view_execucoes_completa.sql`

3. Execute o script completo no SQL Editor

### 2. Verificar se a View foi Criada

Execute no SQL Editor:
```sql
SELECT * FROM mv_execucoes_dia_completa LIMIT 10;
```

Você deve ver colunas incluindo:
- `executor_id`
- `executor_nome`
- `task_id`
- `day`
- `tipo_periodo` ← **NOVO**: indica se é EXECUCAO, PLANEJAMENTO ou DESLOCAMENTO
- `periodo_inicio`
- `periodo_fim`
- `has_conflict`
- etc.

### 3. Atualizar a View Após Alterações

A view é materializada, então precisa ser atualizada quando houver alterações em:
- `executor_periods`
- `gantt_segments`
- `tasks`

Execute:
```sql
SELECT refresh_mv_execucoes_dia_completa();
```

**Nota**: O código já foi atualizado para chamar essa função automaticamente após criar/editar tarefas.

### 4. Testar na Tela de Equipes

Após criar a view:
1. Recarregue a aplicação
2. Acesse a tela de Equipes
3. Os períodos de **PLANEJAMENTO** e **DESLOCAMENTO** devem aparecer automaticamente

## Estrutura da View

A view `mv_execucoes_dia_completa` combina dados de:

1. **executor_periods** (períodos específicos por executor)
   - EXECUÇÃO
   - PLANEJAMENTO
   - DESLOCAMENTO

2. **gantt_segments** (períodos gerais da tarefa)
   - EXECUÇÃO (quando não há executor_periods)
   - PLANEJAMENTO
   - DESLOCAMENTO

3. **tasks** (fallback - datas gerais quando não há segmentos)

## Vantagens

✅ **Performance**: Uma única query retorna todos os períodos
✅ **Simplicidade**: Não precisa buscar dados separadamente
✅ **Completude**: Inclui todos os tipos de períodos automaticamente
✅ **Manutenibilidade**: Lógica centralizada na view

## Rollback (se necessário)

Se precisar voltar para a view antiga, o código tem fallback automático:
- Tenta usar `mv_execucoes_dia_completa`
- Se não existir, usa `mv_execucoes_dia` (view antiga)
