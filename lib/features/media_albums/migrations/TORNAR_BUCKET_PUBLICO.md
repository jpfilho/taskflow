# Tornar o Bucket taskflow-media Público

## Problema
O bucket `taskflow-media` não está sendo encontrado ou está dando erro de RLS. A solução é torná-lo **PÚBLICO**, como os outros buckets do sistema (`anexos-tarefas`, `sap_exports`, `kmz`, etc.).

## Solução Rápida

### 1. Tornar o Bucket Público

1. Acesse o **Supabase Dashboard**
2. Vá em **Storage** > **Buckets**
3. Clique no bucket **taskflow-media**
4. Clique no botão **Edit** (ou nos três pontos > Edit)
5. Na tela de edição:
   - **Public bucket**: ✅ **MARQUE** (toggle deve ficar verde/ativado)
   - Clique em **Save**

### 2. Executar as Políticas Simplificadas

Após tornar o bucket público, execute o script SQL:

1. No Supabase Dashboard, vá em **SQL Editor**
2. Abra o arquivo: `lib/features/media_albums/migrations/CORRIGIR_POLITICAS_STORAGE.sql`
3. Copie e cole o conteúdo no SQL Editor
4. Clique em **Run**

**OU** crie as políticas manualmente via Dashboard:

1. Vá em **Storage** > **Policies**
2. Selecione o bucket **taskflow-media** no dropdown
3. Remova políticas antigas (se existirem)
4. Crie 4 políticas novas:

#### Política 1: SELECT (Leitura)
- **Policy name**: `taskflow_media_select_public`
- **Allowed operation**: `SELECT`
- **Policy definition**: `bucket_id = 'taskflow-media'`

#### Política 2: INSERT (Upload)
- **Policy name**: `taskflow_media_insert_public`
- **Allowed operation**: `INSERT`
- **Policy definition**: `bucket_id = 'taskflow-media'`

#### Política 3: UPDATE (Atualização)
- **Policy name**: `taskflow_media_update_public`
- **Allowed operation**: `UPDATE`
- **Policy definition**: `bucket_id = 'taskflow-media'`

#### Política 4: DELETE (Exclusão)
- **Policy name**: `taskflow_media_delete_public`
- **Allowed operation**: `DELETE`
- **Policy definition**: `bucket_id = 'taskflow-media'`

### 3. Verificar

Execute no SQL Editor:

```sql
-- Verificar se o bucket está público
SELECT id, name, public FROM storage.buckets WHERE id = 'taskflow-media';
-- O campo 'public' deve ser TRUE

-- Verificar políticas criadas
SELECT policyname, cmd FROM pg_policies 
WHERE schemaname = 'storage' AND tablename = 'objects' 
AND policyname LIKE 'taskflow_media%';
-- Deve retornar 4 políticas
```

## Por que Público?

Os outros buckets do sistema (`anexos-tarefas`, `sap_exports`, `kmz`) são públicos e funcionam perfeitamente. Tornar `taskflow-media` público mantém a consistência e resolve problemas de permissão.

As políticas RLS ainda garantem que apenas arquivos do bucket correto sejam acessados, mas sem restrições adicionais de autenticação.
