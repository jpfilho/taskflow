# Como Criar o Bucket taskflow-media no Supabase

## Problema
O erro "Bucket não encontrado" ou "new row violates row-level security policy" indica que:
1. O bucket `taskflow-media` não foi criado
2. As políticas RLS do storage não foram configuradas

## Solução Rápida (Dashboard)

### 1. Criar o Bucket

1. Acesse o **Supabase Dashboard**
2. Vá em **Storage** (menu lateral)
3. Clique em **"New bucket"** ou **"Create bucket"**
4. Configure:
   - **Name**: `taskflow-media`
   - **Public bucket**: ❌ **DESMARCADO** (deve ser privado)
   - Clique em **"Create bucket"**

### 2. Configurar Políticas RLS (Row Level Security)

Após criar o bucket, configure as políticas de segurança:

1. No bucket `taskflow-media`, clique em **"Policies"** ou **"Security"**
2. Adicione as seguintes políticas:

#### Política 1: Permitir Upload (INSERT)
- **Policy name**: `Permitir upload para usuários autenticados`
- **Allowed operation**: `INSERT`
- **Policy definition**:
```sql
(bucket_id = 'taskflow-media'::text) AND 
(auth.uid()::text = (storage.foldername(name))[1])
```
- **Description**: Permite que usuários autenticados façam upload apenas em suas próprias pastas (`{userId}/...`)

#### Política 2: Permitir Leitura (SELECT)
- **Policy name**: `Permitir leitura para usuários autenticados`
- **Allowed operation**: `SELECT`
- **Policy definition**:
```sql
(bucket_id = 'taskflow-media'::text) AND 
(auth.role() = 'authenticated'::text)
```
- **Description**: Permite que usuários autenticados leiam arquivos do bucket

#### Política 3: Permitir Exclusão (DELETE)
- **Policy name**: `Permitir exclusão para dono do arquivo`
- **Allowed operation**: `DELETE`
- **Policy definition**:
```sql
(bucket_id = 'taskflow-media'::text) AND 
(auth.uid()::text = (storage.foldername(name))[1])
```
- **Description**: Permite que usuários deletem apenas seus próprios arquivos

### 3. Verificar Políticas

Após criar as políticas, verifique se estão ativas:
- Todas devem estar com status **"Active"**
- O bucket deve estar marcado como **"Private"**

## Solução via SQL (Alternativa)

Se preferir usar SQL diretamente, execute o arquivo:
```
lib/features/media_albums/migrations/create_storage_policies.sql
```

**NOTA**: Alguns comandos podem falhar com "must be owner of table objects". Nesse caso, use o método do Dashboard acima.

## Teste

Após criar o bucket e configurar as políticas:
1. Tente fazer upload novamente
2. Verifique os logs no console
3. O upload deve funcionar sem erros de RLS

## Troubleshooting

### Erro: "Bucket não encontrado"
- ✅ Verifique se o bucket foi criado com o nome exato: `taskflow-media`
- ✅ Verifique se está no projeto correto do Supabase

### Erro: "new row violates row-level security policy"
- ✅ Verifique se as políticas RLS foram criadas
- ✅ Verifique se o usuário está autenticado (`auth.uid()` não é null)
- ✅ Verifique se o caminho do arquivo começa com `{userId}/` (ex: `b700d4a5-cbf3-492e-8e69-dc48520d858f/...`)

### Erro: "403 Unauthorized"
- ✅ Verifique se as políticas permitem a operação (INSERT/SELECT/DELETE)
- ✅ Verifique se o usuário tem role `authenticated`
- ✅ Verifique se o bucket está configurado como privado
