# Guia de Introspecção do Schema Supabase

## Objetivo

Mapear completamente o schema do banco de dados antes de implementar a funcionalidade de **tags de Nota/Ordem** nas mensagens do chat.

## Scripts Disponíveis

### 1. `introspeccao_schema_completo.sql`
**Uso:** Execute primeiro para ter uma visão geral completa do banco.

**O que retorna:**
- ✅ Lista de todas as tabelas do schema `public`
- ✅ Todas as colunas com tipos, tamanhos, nullable, defaults
- ✅ Todas as Primary Keys (PKs)
- ✅ Todas as Foreign Keys (FKs) com relacionamentos
- ✅ Todos os índices (normais e únicos)
- ✅ Estrutura detalhada das tabelas críticas:
  - `mensagens`
  - `grupos_chat`
  - `telegram_delivery_logs`
  - `telegram_task_topics`
  - `tasks`
  - `notas` (se existir)
  - `ordens` (se existir)
- ✅ Relacionamentos específicos do chat
- ✅ Contagem de registros por tabela
- ✅ Check constraints (regras de negócio)

### 2. `introspeccao_chat_focado.sql`
**Uso:** Execute depois para análise detalhada das tabelas críticas.

**O que retorna:**
- ✅ Estrutura completa de `mensagens` com identificação de PKs/FKs
- ✅ Estrutura completa de `grupos_chat`
- ✅ Estrutura completa de `telegram_task_topics`
- ✅ Estrutura completa de `tasks`
- ✅ Verificação se existem tabelas `notas`/`ordens` (e variações de nome)
- ✅ Mapeamento de como mensagens se ligam a tasks
- ✅ Exemplos de dados reais (limitados)
- ✅ Check constraints específicos

## Como Executar

1. **Acesse o Supabase Dashboard**
   - Vá para o projeto no Supabase
   - Clique em "SQL Editor" no menu lateral

2. **Execute o script completo primeiro:**
   ```sql
   -- Cole e execute: introspeccao_schema_completo.sql
   ```

3. **Analise os resultados:**
   - Anote os nomes exatos das tabelas
   - Verifique os relacionamentos (FKs)
   - Confirme os tipos de dados

4. **Execute o script focado:**
   ```sql
   -- Cole e execute: introspeccao_chat_focado.sql
   ```

5. **Compartilhe os resultados:**
   - Copie os resultados das queries
   - Ou exporte como CSV/JSON se possível
   - Foque especialmente nas seções:
     - Estrutura de `mensagens`
     - Estrutura de `grupos_chat`
     - Estrutura de `telegram_task_topics`
     - Existência e estrutura de `notas`/`ordens`

## O Que Procurar

### 🔍 Informações Críticas

1. **Tabela `mensagens`:**
   - Quais campos já existem?
   - Tem `grupo_id`? (FK para `grupos_chat`)
   - Tem `task_id` direto? (ou só via `grupo_id`?)
   - Tem campos de metadata/tags já?

2. **Tabela `grupos_chat`:**
   - Tem `tarefa_id`? (FK para `tasks`)
   - Como se relaciona com `mensagens`?

3. **Tabela `telegram_task_topics`:**
   - Mapeia `task_id` → `telegram_topic_id`?
   - Mapeia `grupo_chat_id` → `telegram_chat_id`?

4. **Tabelas `notas`/`ordens`:**
   - Existem? Qual o nome exato?
   - Têm `task_id` ou `tarefa_id`?
   - Qual o tipo do ID (UUID, INTEGER, etc.)?

5. **Relacionamentos:**
   ```
   mensagens → grupos_chat → tasks
   mensagens → telegram_delivery_logs → telegram (chat_id, topic_id, message_id)
   tasks → telegram_task_topics → telegram (topic_id)
   notas → tasks? (verificar)
   ordens → tasks? (verificar)
   ```

## Próximos Passos Após Introspecção

Com os resultados em mãos, vou:

1. ✅ **Propor a mudança mínima no banco:**
   - Adicionar campos opcionais em `mensagens`:
     - `ref_type` (GERAL | NOTA | ORDEM)
     - `ref_id` (UUID ou INTEGER, nullable)
     - `ref_label` (TEXT, nullable, para exibição)

2. ✅ **Criar SQL de migração segura:**
   - `ALTER TABLE` com `IF NOT EXISTS`
   - Defaults compatíveis com dados existentes
   - Índices para performance

3. ✅ **Definir queries de busca:**
   - Buscar notas por `task_id`
   - Buscar ordens por `task_id`
   - Filtrar mensagens por tag

4. ✅ **Atualizar Flutter:**
   - Seletor de tag no UI
   - Carregar notas/ordens da tarefa
   - Enviar payload com tags

5. ✅ **Atualizar Node.js bridge:**
   - Aceitar payload antigo (sem tags)
   - Processar payload novo (com tags)
   - Formatar mensagem Telegram com prefixo

6. ✅ **Garantir compatibilidade:**
   - Mensagens antigas sem tag = "Geral"
   - Mensagens do Telegram sem tag = "Geral"
   - Filtros funcionam com NULL

## Notas Importantes

- ⚠️ **NÃO execute queries de INSERT/UPDATE/DELETE** - apenas SELECT
- ⚠️ **NÃO modifique o schema** ainda - apenas leia
- ✅ **Compartilhe os resultados** para eu analisar e propor a solução
- ✅ **Foque nas tabelas críticas** mencionadas acima

## Exemplo de Resultado Esperado

Após executar, você deve ter algo como:

```
TABELA: mensagens
- id (UUID, PK)
- grupo_id (UUID, FK → grupos_chat.id)
- usuario_id (UUID)
- conteudo (TEXT)
- tipo (TEXT)
- created_at (TIMESTAMPTZ)
- deleted_at (TIMESTAMPTZ, nullable)
- ... (outros campos)

TABELA: grupos_chat
- id (UUID, PK)
- tarefa_id (UUID, FK → tasks.id)
- tarefa_nome (TEXT)
- ...

TABELA: telegram_task_topics
- id (UUID, PK)
- task_id (UUID, FK → tasks.id)
- grupo_chat_id (UUID, FK → grupos_chat.id)
- telegram_chat_id (BIGINT)
- telegram_topic_id (INTEGER)
- ...

TABELA: notas (se existir)
- id (UUID, PK)
- tarefa_id (UUID, FK → tasks.id)
- numero (TEXT ou INTEGER)
- ...
```

Com essas informações, posso propor a solução exata e compatível! 🚀
