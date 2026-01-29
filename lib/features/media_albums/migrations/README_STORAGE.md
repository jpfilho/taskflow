# Configuração do Storage - Álbuns de Mídia

## Passo a Passo

### 1. Criar o Bucket no Supabase Dashboard

1. Acesse o Supabase Dashboard do seu projeto
2. Vá em **Storage** > **Buckets**
3. Clique em **New Bucket**
4. Preencha:
   - **Name**: `taskflow-media`
   - **Public bucket**: **DESMARCADO** (deixar privado)
   - **File size limit**: 50 MB (ou o valor desejado)
   - **Allowed MIME types**: `image/jpeg, image/jpg, image/png, image/webp, image/gif`
5. Clique em **Create bucket**

### 2. Executar as Políticas de Storage

**IMPORTANTE**: Se você receber o erro **"must be owner of table objects"**, 
use o método manual via Dashboard (veja abaixo).

#### Método 1: Via SQL (pode falhar por permissões)

1. No Supabase Dashboard, vá em **SQL Editor**
2. Abra o arquivo `create_storage_policies.sql`
3. Copie e cole o conteúdo no SQL Editor
4. Clique em **Run** para executar

**Se der erro de permissão**, use o Método 2.

#### Método 2: Via Dashboard (RECOMENDADO se SQL falhar)

1. No Supabase Dashboard, vá em **Storage** > **Policies**
2. Selecione o bucket **taskflow-media** no dropdown
3. Para cada política, clique em **New Policy**:
   - **SELECT**: `bucket_id = 'taskflow-media'`
   - **INSERT**: `bucket_id = 'taskflow-media' AND (string_to_array(name, '/'))[1] = auth.uid()::text`
   - **UPDATE**: `bucket_id = 'taskflow-media' AND (string_to_array(name, '/'))[1] = auth.uid()::text`
   - **DELETE**: `bucket_id = 'taskflow-media' AND (string_to_array(name, '/'))[1] = auth.uid()::text`

**Veja instruções detalhadas**: `create_storage_policies_manual.md`

### 3. Verificar se Funcionou

Execute estas queries no SQL Editor para verificar:

```sql
-- Verificar se o bucket foi criado
SELECT * FROM storage.buckets WHERE id = 'taskflow-media';

-- Verificar políticas criadas
SELECT * FROM pg_policies 
WHERE tablename = 'objects' 
AND policyname LIKE 'taskflow_media%';
```

Você deve ver:
- 1 bucket: `taskflow-media`
- 4 políticas: `taskflow_media_select_authenticated`, `taskflow_media_insert_own`, `taskflow_media_update_own`, `taskflow_media_delete_own`

## Estrutura de Pastas

Os arquivos são armazenados com a seguinte estrutura:

```
taskflow-media/
  └── {userId}/
      └── {segmentId}/
          └── {equipmentId}/
              └── {roomId}/
                  └── {year}/
                      └── {month}/
                          └── {uuid}.jpg
```

Exemplo:
```
taskflow-media/
  └── 123e4567-e89b-12d3-a456-426614174000/
      └── 223e4567-e89b-12d3-a456-426614174001/
          └── 323e4567-e89b-12d3-a456-426614174002/
              └── 2026/
                  └── 01/
                      └── 456e7890-e89b-12d3-a456-426614174003.jpg
```

## Políticas de Segurança

### SELECT (Leitura)
- ✅ Usuários autenticados podem ler **qualquer** arquivo do bucket
- Isso permite que todos vejam as imagens de todos

### INSERT (Upload)
- ✅ Usuários autenticados podem fazer upload **apenas** em pastas que começam com seu próprio `userId`
- Isso garante que cada usuário só pode fazer upload em sua própria pasta

### UPDATE (Atualização)
- ✅ Usuários autenticados podem atualizar **apenas** arquivos em suas próprias pastas

### DELETE (Exclusão)
- ✅ Usuários autenticados podem deletar **apenas** arquivos em suas próprias pastas

## URLs e Acesso

Como o bucket é **privado**, você precisa usar **signed URLs** para acessar os arquivos:

```dart
// No código Flutter (já implementado no repositório)
final url = await repository.getSignedUrl(path, expiresIn: 3600);
```

As signed URLs expiram após o tempo especificado (padrão: 1 hora).

## Troubleshooting

### Erro: "bucket does not exist"
- Verifique se o bucket foi criado no Dashboard
- Execute o comando `INSERT INTO storage.buckets...` do arquivo `create_storage_policies.sql`

### Erro: "new row violates row-level security policy"
- Verifique se as políticas foram criadas corretamente
- Verifique se o usuário está autenticado
- Verifique se o caminho do arquivo começa com o `userId` do usuário autenticado

### Erro: "permission denied"
- Verifique se RLS está habilitado: `ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;`
- Verifique se as políticas foram criadas: `SELECT * FROM pg_policies WHERE tablename = 'objects';`

### Arquivos não aparecem
- Verifique se o `file_path` na tabela `media_images` está correto
- Verifique se o arquivo realmente existe no bucket (Storage > taskflow-media)
- Verifique se a signed URL está sendo gerada corretamente

## Limites

- **Tamanho máximo por arquivo**: 50 MB (configurável)
- **Tipos permitidos**: JPEG, PNG, WEBP, GIF
- **Validade da signed URL**: 1 hora (configurável)

## Próximos Passos

Após configurar o storage:
1. Teste fazendo upload de uma imagem pelo app
2. Verifique se o arquivo aparece no bucket (Storage > taskflow-media)
3. Verifique se a imagem aparece na galeria
4. Teste edição e exclusão
