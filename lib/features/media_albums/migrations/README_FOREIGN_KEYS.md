# Remover Foreign Keys do Módulo de Mídia

## Problema

O erro `insert or update on table "media_images" violates foreign key constraint` ocorre porque:

1. **segment_id**: A aplicação usa IDs da tabela `segmentos` (sistema), mas a foreign key referencia `segments` (módulo de mídia)
2. **equipment_id**: IDs são gerados dinamicamente (UUIDs determinísticos) a partir de `equipamentos_sap.localizacao` e podem não existir na tabela `equipments`
3. **room_id**: IDs são gerados dinamicamente (UUIDs determinísticos) a partir de `equipamentos_sap.sala` e podem não existir na tabela `rooms`

## Solução

Remover as foreign keys que estão causando problemas, já que:

- Os segmentos vêm da tabela `segmentos` do sistema
- Os equipamentos e salas são derivados dinamicamente de `equipamentos_sap`
- Não há necessidade de integridade referencial rígida para esses campos

## Scripts de Correção

### 1. Remover Foreign Key de segment_id

**Arquivo:** `REMOVER_FOREIGN_KEY_SEGMENT_ID.sql`

Execute este script primeiro para remover a foreign key de `segment_id`.

### 2. Remover Foreign Keys de equipment_id e room_id

**Arquivo:** `REMOVER_FOREIGN_KEYS_HIERARQUIA.sql`

Execute este script para remover as foreign keys de `equipment_id` e `room_id`.

## Ordem de Execução

1. Execute `REMOVER_FOREIGN_KEY_SEGMENT_ID.sql`
2. Execute `REMOVER_FOREIGN_KEYS_HIERARQUIA.sql`
3. (Opcional) Execute `CORRIGIR_FOREIGN_KEY_CREATED_BY.sql` se a foreign key de `created_by` ainda referencia `auth.users`

## Verificação

Após executar os scripts, verifique:

```sql
-- Verificar foreign keys restantes em media_images
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
  AND tc.table_name = 'media_images';
```

Deve mostrar apenas a foreign key de `created_by` (se ainda existir e referenciar `usuarios`).

## Teste

Após executar os scripts, tente fazer upload de uma imagem novamente. O erro de foreign key não deve mais ocorrer.
