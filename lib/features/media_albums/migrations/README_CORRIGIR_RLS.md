# Como Corrigir Erros de RLS na Tabela media_images

## Problema
Erro: `new row violates row-level security policy for table "media_images"`

Isso ocorre porque:
1. As políticas RLS usam `auth.uid()`, mas a aplicação **NÃO usa autenticação do Supabase**
2. A coluna `created_by` pode estar referenciando `auth.users` em vez de `usuarios`

## Solução

### Passo 1: Corrigir as Políticas RLS

Execute o script SQL no Supabase SQL Editor:

**Arquivo:** `lib/features/media_albums/migrations/CORRIGIR_POLITICAS_MEDIA_IMAGES.sql`

Este script:
- Remove as políticas antigas que usam `auth.uid()`
- Cria novas políticas que verificam se `created_by` existe na tabela `usuarios`

### Passo 2: (Opcional) Corrigir Foreign Key

Se a coluna `created_by` ainda referencia `auth.users`, execute também:

**Arquivo:** `lib/features/media_albums/migrations/CORRIGIR_FOREIGN_KEY_CREATED_BY.sql`

Este script:
- Remove a foreign key antiga para `auth.users`
- Adiciona nova foreign key para `usuarios`

**NOTA:** Se a coluna `id` da tabela `usuarios` não for UUID, você precisará ajustar o script.

### Passo 3: Verificar

Execute estas queries para verificar:

```sql
-- Verificar políticas criadas
SELECT policyname, cmd FROM pg_policies 
WHERE schemaname = 'public' AND tablename = 'media_images';

-- Verificar foreign key
SELECT
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_name = 'media_images'
  AND kcu.column_name = 'created_by';
```

## Ordem de Execução

1. Primeiro: `CORRIGIR_POLITICAS_MEDIA_IMAGES.sql`
2. Depois (se necessário): `CORRIGIR_FOREIGN_KEY_CREATED_BY.sql`

## Teste

Após executar os scripts, tente fazer upload de uma imagem novamente. O erro de RLS não deve mais ocorrer.
