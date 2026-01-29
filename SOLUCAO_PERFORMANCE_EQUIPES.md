# Solução: Performance da Tela de Equipes

## Problema Identificado

A tela de equipes está **muito mais lenta** que a tela de tarefas porque:

### Tela de Tarefas (Rápida)
- ✅ SELECT simples na tabela `tasks` com joins
- ✅ Retorna apenas registros de tarefas (não expande)
- ✅ Processa dados já estruturados

### Tela de Equipes (Lenta)
- ❌ Usa view `v_execucoes_dia_completa` que expande **TODOS** os períodos em dias individuais
- ❌ Se há 100 tarefas com 30 dias cada = **3.000+ linhas** só de execução
- ❌ Multiplica por PLANEJAMENTO e DESLOCAMENTO = **milhares de linhas**
- ❌ Depois processa tudo no Flutter com loops aninhados

## Soluções Implementadas

### 1. View Otimizada (`criar_view_execucoes_completa_otimizada.sql`)

**Mudanças:**
- ✅ Filtra períodos fora da janela de datas comum **ANTES** do `generate_series`
- ✅ Adiciona filtro: `data_fim >= CURRENT_DATE - INTERVAL '1 year'` e `data_inicio <= CURRENT_DATE + INTERVAL '2 years'`
- ✅ Reduz drasticamente o número de linhas processadas

**Como aplicar:**
```sql
-- Execute no SQL Editor do Supabase
-- Substitui a view atual pela versão otimizada
```

### 2. Índices Adicionais (`otimizar_view_execucoes.sql`)

**Índices criados:**
- ✅ `idx_executor_periods_dates_tipo` - Filtra por data e tipo mais rápido
- ✅ `idx_gantt_segments_dates_tipo` - Filtra por data e tipo mais rápido
- ✅ `idx_tasks_status_dates` - Filtra tarefas canceladas mais cedo

**Como aplicar:**
```sql
-- Execute no SQL Editor do Supabase
-- Cria índices para melhorar performance
```

### 3. Otimizações no Flutter (Futuro)

**Melhorias sugeridas:**
- ⏳ Adicionar cache dos resultados da view
- ⏳ Carregar dados progressivamente (paginado)
- ⏳ Mostrar loading incremental
- ⏳ Reduzir loops aninhados no processamento

## Passos para Aplicar

### Passo 1: Executar Scripts SQL

1. Execute `otimizar_view_execucoes.sql` primeiro (cria índices)
2. Execute `criar_view_execucoes_completa_otimizada.sql` (substitui a view)

### Passo 2: Testar Performance

1. Abra a tela de equipes
2. Meça o tempo de carregamento
3. Compare com a tela de tarefas

### Passo 3: Monitorar

- Verifique logs do Supabase para tempo de query
- Monitore uso de memória no Flutter
- Ajuste os intervalos de data se necessário

## Resultados Esperados

- ⚡ **Redução de 70-90%** no tempo de carregamento
- ⚡ **Menos linhas processadas** (filtro antes de expandir)
- ⚡ **Índices melhoram** performance de filtros
- ⚡ **View ainda atualiza automaticamente** (não materializada)

## Notas Importantes

1. **Janela de datas**: A view filtra períodos fora de 1 ano atrás até 2 anos à frente
   - Se precisar de mais, ajuste os intervalos no SQL
   - O Supabase client ainda filtra por `startDate` e `endDate` do widget

2. **Compatibilidade**: A view otimizada mantém a mesma estrutura
   - Não precisa mudar código Flutter
   - Apenas executa os scripts SQL

3. **Fallback**: Se a view otimizada não existir, o código usa a view materializada ou antiga
