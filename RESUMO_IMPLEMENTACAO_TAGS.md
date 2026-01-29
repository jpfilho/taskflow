# Resumo Executivo: Implementação de Tags Nota/Ordem

## 🎯 Objetivo

Adicionar funcionalidade de "taguear" mensagens do chat com Nota ou Ordem, permitindo:
- Filtrar mensagens por tag
- Visualizar tag na UI do Flutter
- Exibir prefixo bonito no Telegram
- Auditoria e rastreabilidade

## ✅ Regra de Ouro

**NÃO quebrar nada que já funciona!**
- Mensagens antigas continuam funcionando (tratadas como "GERAL")
- Mensagens do Telegram continuam funcionando (sempre "GERAL")
- Payload antigo continua sendo aceito

## 📊 Mudança no Banco

### Tabela: `mensagens`

**Adicionar 3 colunas opcionais:**
- `ref_type` (TEXT): 'GERAL' | 'NOTA' | 'ORDEM' (default: 'GERAL')
- `ref_id` (UUID): ID da nota ou ordem (nullable)
- `ref_label` (TEXT): Label para exibição (nullable)

**SQL:** `migration_adicionar_tags_mensagens.sql`

## 🔄 Fluxo de Dados

### Flutter → Node.js → Telegram

```
Flutter (com tag)
  ↓
Node.js /send-message
  ├─ Valida ref_type/ref_id
  ├─ Gera ref_label se necessário
  ├─ Salva no Supabase com tags
  └─ Envia para Telegram com prefixo
     📌 NOTA 12345
     🧾 ORDEM 67890
     💬 GERAL
```

### Telegram → Node.js → Supabase

```
Telegram (sempre GERAL)
  ↓
Node.js processMessage
  ├─ ref_type = 'GERAL'
  ├─ ref_id = NULL
  └─ Salva no Supabase
```

## 📁 Arquivos Criados

1. **`PROPOSTA_TAGS_NOTAS_ORDENS.md`**
   - Análise completa do schema
   - Modelo de dados
   - Diagramas
   - Checklist de implementação

2. **`migration_adicionar_tags_mensagens.sql`**
   - SQL de migração completo
   - Índices para performance
   - Validações e rollback

3. **`queries_buscar_notas_ordens.sql`**
   - Queries para buscar notas/ordens por tarefa
   - Queries para filtrar mensagens por tag
   - Queries de validação

4. **`EXEMPLOS_PAYLOAD_TAGS.md`**
   - Exemplos de payload Flutter → Node.js
   - Exemplos de processamento Telegram
   - Validações e erros

5. **`RESUMO_IMPLEMENTACAO_TAGS.md`** (este arquivo)
   - Resumo executivo
   - Próximos passos

## 🚀 Próximos Passos

### 1. Validar Schema (CRÍTICO)

Execute no Supabase SQL Editor:

```sql
-- Verificar se grupos_chat tem tarefa_id
SELECT column_name, data_type 
FROM information_schema.columns
WHERE table_name = 'grupos_chat' 
  AND column_name LIKE '%tarefa%';

-- Verificar campos de notas_sap
SELECT column_name, data_type 
FROM information_schema.columns
WHERE table_name = 'notas_sap';

-- Verificar campos de ordens
SELECT column_name, data_type 
FROM information_schema.columns
WHERE table_name = 'ordens';
```

**Ajustar queries se necessário:**
- Campo `numero` pode ter nome diferente
- Campo `descricao` pode ter nome diferente

### 2. Executar Migração

```sql
-- Executar: migration_adicionar_tags_mensagens.sql
-- Verificar resultados das queries de validação
```

### 3. Implementar Flutter

- [ ] Atualizar modelo `Mensagem` (adicionar `refType`, `refId`, `refLabel`)
- [ ] Criar widget seletor de tag (`_buildTagSelector`)
- [ ] Implementar busca de notas/ordens por tarefa
- [ ] Atualizar `ChatService.enviarMensagem()` para incluir tags
- [ ] Adicionar filtros na UI (por tag)
- [ ] Exibir badge/tag nas mensagens

### 4. Implementar Node.js

- [ ] Atualizar endpoint `/send-message` para aceitar `ref_type`, `ref_id`, `ref_label`
- [ ] Validar payload (ref_type válido, ref_id existe)
- [ ] Gerar `ref_label` automaticamente se não fornecido
- [ ] Formatar mensagem Telegram com prefixo (📌/🧾/💬)
- [ ] Salvar tags no Supabase
- [ ] Manter compatibilidade com payload antigo

### 5. Testar

- [ ] Mensagem geral (sem tag)
- [ ] Mensagem com nota
- [ ] Mensagem com ordem
- [ ] Mensagem do Telegram (deve ser GERAL)
- [ ] Mensagem antiga (deve ser GERAL)
- [ ] Filtros por tag
- [ ] Validações (ref_id inválido, etc.)

## 📋 Checklist de Validação

Antes de implementar, confirmar:

- [ ] `grupos_chat.tarefa_id` existe e é FK para `tasks.id`
- [ ] `notas_sap.numero` existe (ou nome do campo correto)
- [ ] `ordens.numero` existe (ou nome do campo correto)
- [ ] Relacionamento `tasks_notas_sap` funciona
- [ ] Relacionamento `tasks_ordens` funciona
- [ ] Migração SQL executada com sucesso
- [ ] Índices criados
- [ ] Dados existentes não foram afetados

## 🎨 UI Sugerida (Flutter)

### Seletor de Tag

```
┌─────────────────────────────┐
│ [💬 Geral] [📌 Nota] [🧾 Ordem] │  ← Botões/Tabs
└─────────────────────────────┘

Se selecionar Nota/Ordem:
┌─────────────────────────────┐
│ Selecionar Nota:            │
│ [Dropdown com notas]        │
│   - NOTA 12345              │
│   - NOTA 12346              │
│   - NOTA 12347              │
└─────────────────────────────┘
```

### Exibição de Mensagem

```
┌─────────────────────────────┐
│ 📌 NOTA 12345              │  ← Badge/Tag
│ João Silva                  │
│ Verifiquei a nota...        │
│ 10:30                       │
└─────────────────────────────┘
```

### Filtros

```
┌─────────────────────────────┐
│ Filtros:                    │
│ [ ] Todas                   │
│ [ ] Geral                   │
│ [ ] Notas                   │
│ [ ] Ordens                  │
└─────────────────────────────┘
```

## 🔒 Garantias de Compatibilidade

1. **Mensagens Antigas:**
   - `ref_type = NULL` → Tratado como 'GERAL'
   - `ref_id = NULL` → OK
   - Continuam sendo exibidas normalmente

2. **Payload Antigo:**
   - Sem `ref_type` → Tratado como 'GERAL'
   - Node.js não retorna erro

3. **Mensagens do Telegram:**
   - Sempre `ref_type = 'GERAL'`
   - `ref_id = NULL`
   - Continuam funcionando como hoje

4. **Queries Existentes:**
   - `WHERE deleted_at IS NULL` continua funcionando
   - `ORDER BY created_at` continua funcionando
   - Filtros por `grupo_id` continuam funcionando

## 📞 Suporte

Se encontrar problemas:

1. Verificar logs do Node.js
2. Verificar queries SQL de validação
3. Verificar se campos `numero` existem em `notas_sap`/`ordens`
4. Verificar se `grupos_chat.tarefa_id` existe

## ✅ Pronto para Implementar!

Todos os arquivos necessários foram criados. Execute a migração e comece a implementar! 🚀
