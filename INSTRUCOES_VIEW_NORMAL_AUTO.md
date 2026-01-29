# Instruções: View Normal (Atualização Automática)

## Problema
A view materializada `mv_execucoes_dia_completa` não atualiza automaticamente. É necessário executar `REFRESH MATERIALIZED VIEW` manualmente após cada mudança.

## Solução
Criar uma **view normal** (não materializada) `v_execucoes_dia_completa` que atualiza **automaticamente** quando os dados mudam.

## Diferenças

### View Materializada (`mv_execucoes_dia_completa`)
- ❌ **Não atualiza automaticamente**
- ✅ Mais rápida (dados pré-calculados)
- ⚠️ Precisa de `REFRESH MATERIALIZED VIEW` após mudanças

### View Normal (`v_execucoes_dia_completa`)
- ✅ **Atualiza automaticamente** (sempre reflete dados atuais)
- ⚠️ Pode ser um pouco mais lenta (executa query a cada consulta)
- ✅ Não precisa de refresh manual

## Passos para Implementar

### 1. Executar o Script SQL

1. Acesse o SQL Editor do Supabase
2. Abra o arquivo `criar_view_execucoes_completa_auto.sql`
3. Execute o script completo

Isso criará a view normal `v_execucoes_dia_completa` que atualiza automaticamente.

### 2. Verificar se a View foi Criada

Execute no SQL Editor:
```sql
SELECT * FROM v_execucoes_dia_completa LIMIT 10;
```

Você deve ver os mesmos dados que a view materializada, mas sempre atualizados.

### 3. O Código Já Está Atualizado

O código Flutter já foi atualizado para:
1. **Tentar usar a view normal primeiro** (`v_execucoes_dia_completa`)
2. **Fazer fallback para view materializada** se a normal não existir
3. **Fazer fallback para view antiga** se necessário

### 4. Testar

1. Crie ou edite uma tarefa na tela de atividades
2. A tela de equipes deve atualizar **automaticamente** sem precisar de F5
3. Não é mais necessário executar `REFRESH MATERIALIZED VIEW`

## Vantagens da View Normal

✅ **Atualização automática**: Sempre reflete os dados atuais
✅ **Sem refresh manual**: Não precisa executar `REFRESH MATERIALIZED VIEW`
✅ **Funciona com Realtime**: Mudanças aparecem imediatamente
✅ **Mais simples**: Menos código de gerenciamento

## Desvantagens

⚠️ **Pode ser mais lenta**: Executa a query completa a cada consulta
⚠️ **Mais carga no banco**: Cada consulta processa todos os dados

## Recomendação

- **Use view normal** se a performance for aceitável
- **Use view materializada** apenas se a view normal for muito lenta
- **Pode manter ambas**: O código tenta a normal primeiro, depois a materializada

## Nota Importante

A view normal usa a mesma lógica da view materializada, mas sempre executa a query quando consultada. Isso garante que os dados estejam sempre atualizados, mas pode ser mais lento se houver muitos dados.
