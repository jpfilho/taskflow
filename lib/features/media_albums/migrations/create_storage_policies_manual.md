# Criar Políticas de Storage Manualmente

Se você recebeu o erro **"must be owner of table objects"**, você precisa criar as políticas via **Supabase Dashboard** ao invés de SQL.

## Passo a Passo

### 1. Acesse o Supabase Dashboard

1. Vá para o seu projeto no Supabase Dashboard
2. Clique em **Storage** no menu lateral
3. Clique em **Policies**

### 2. Selecione o Bucket

1. No dropdown "Select a bucket", escolha **taskflow-media**
2. Se o bucket não aparecer, crie-o primeiro (Storage > Buckets > New Bucket)

### 3. Criar Política 1: SELECT (Leitura)

1. Clique em **New Policy**
2. Escolha **"For full customization"** ou **"Create a policy from scratch"**
3. Preencha:
   - **Policy name**: `taskflow_media_select_authenticated`
   - **Allowed operation**: `SELECT`
   - **Policy definition**: Cole o seguinte código:

```sql
bucket_id = 'taskflow-media'
```

4. Clique em **Review** e depois **Save policy**

### 4. Criar Política 2: INSERT (Upload)

1. Clique em **New Policy**
2. Escolha **"For full customization"**
3. Preencha:
   - **Policy name**: `taskflow_media_insert_own`
   - **Allowed operation**: `INSERT`
   - **Policy definition**: Cole o seguinte código:

```sql
bucket_id = 'taskflow-media' AND
(string_to_array(name, '/'))[1] = auth.uid()::text
```

4. Clique em **Review** e depois **Save policy**

### 5. Criar Política 3: UPDATE (Atualização)

1. Clique em **New Policy**
2. Escolha **"For full customization"**
3. Preencha:
   - **Policy name**: `taskflow_media_update_own`
   - **Allowed operation**: `UPDATE`
   - **Policy definition**: Cole o seguinte código:

```sql
bucket_id = 'taskflow-media' AND
(string_to_array(name, '/'))[1] = auth.uid()::text
```

4. Clique em **Review** e depois **Save policy**

### 5. Criar Política 4: DELETE (Exclusão)

1. Clique em **New Policy**
2. Escolha **"For full customization"**
3. Preencha:
   - **Policy name**: `taskflow_media_delete_own`
   - **Allowed operation**: `DELETE`
   - **Policy definition**: Cole o seguinte código:

```sql
bucket_id = 'taskflow-media' AND
(string_to_array(name, '/'))[1] = auth.uid()::text
```

4. Clique em **Review** e depois **Save policy**

## Verificar

Após criar todas as políticas, você deve ver 4 políticas listadas:

1. ✅ `taskflow_media_select_authenticated` (SELECT)
2. ✅ `taskflow_media_insert_own` (INSERT)
3. ✅ `taskflow_media_update_own` (UPDATE)
4. ✅ `taskflow_media_delete_own` (DELETE)

## Explicação das Políticas

### SELECT (Leitura)
- **Permite**: Todos usuários autenticados podem ler qualquer arquivo
- **Uso**: Visualizar imagens na galeria

### INSERT (Upload)
- **Permite**: Upload apenas em pastas que começam com o `userId` do usuário
- **Restrição**: `(string_to_array(name, '/'))[1] = auth.uid()::text`
- **Uso**: Fazer upload de novas imagens

### UPDATE (Atualização)
- **Permite**: Atualizar apenas arquivos em pastas próprias
- **Uso**: Substituir imagens existentes

### DELETE (Exclusão)
- **Permite**: Deletar apenas arquivos em pastas próprias
- **Uso**: Remover imagens

## Estrutura de Pastas

As políticas garantem que o caminho do arquivo siga esta estrutura:

```
{userId}/{segmentId}/{equipmentId}/{roomId}/{year}/{month}/{filename}
```

A primeira pasta **DEVE** ser o `userId` do usuário autenticado para as políticas funcionarem.

## Troubleshooting

### Erro: "Policy already exists"
- A política já foi criada anteriormente
- Você pode deletá-la e criar novamente, ou simplesmente usar a existente

### Erro: "Invalid policy definition"
- Verifique se copiou o código SQL corretamente
- Certifique-se de que o bucket 'taskflow-media' existe

### Upload não funciona
- Verifique se a política INSERT foi criada
- Verifique se o caminho do arquivo começa com o `userId` correto
- Verifique se o usuário está autenticado

### Leitura não funciona
- Verifique se a política SELECT foi criada
- Verifique se o bucket existe e está acessível
