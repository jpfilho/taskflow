# Configuração do Bucket de Storage para Anexos

## Passo 1: Criar o Bucket no Supabase

1. Acesse o **Supabase Dashboard**
2. Vá em **Storage** no menu lateral
3. Clique em **New bucket**
4. Configure:
   - **Name**: `anexos-tarefas`
   - **Public bucket**: ✅ Marque como público (ou configure políticas específicas)
   - **File size limit**: Configure conforme necessário (ex: 50MB)
   - **Allowed MIME types**: Deixe vazio para permitir todos os tipos

## Passo 2: Configurar Políticas RLS do Storage

Após criar o bucket, configure as políticas de acesso:

### Opção 1: Bucket Público (Mais Simples)
- Marque o bucket como **público** ao criá-lo
- Isso permite upload e download sem autenticação

### Opção 2: Políticas RLS Personalizadas (Recomendado)

Execute estas políticas SQL no Supabase SQL Editor:

```sql
-- Política para permitir upload de arquivos
CREATE POLICY "Permitir upload de anexos"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'anexos-tarefas'
);

-- Política para permitir leitura de arquivos
CREATE POLICY "Permitir leitura de anexos"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'anexos-tarefas'
);

-- Política para permitir exclusão de arquivos
CREATE POLICY "Permitir exclusão de anexos"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'anexos-tarefas'
);

-- Política para permitir atualização de arquivos (se necessário)
CREATE POLICY "Permitir atualização de anexos"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'anexos-tarefas'
)
WITH CHECK (
  bucket_id = 'anexos-tarefas'
);
```

### Opção 3: Política Permissiva (Para Desenvolvimento)

Se quiser permitir todas as operações sem autenticação (apenas para desenvolvimento):

```sql
-- ATENÇÃO: Use apenas em desenvolvimento!
CREATE POLICY "Permitir todas as operações em anexos-tarefas"
ON storage.objects
FOR ALL
TO public
USING (bucket_id = 'anexos-tarefas')
WITH CHECK (bucket_id = 'anexos-tarefas');
```

## Passo 3: Verificar Configuração

Após configurar, teste fazendo upload de um arquivo através da interface do aplicativo.

## Notas Importantes

- **Segurança**: Em produção, use políticas RLS mais restritivas
- **Autenticação**: Se usar autenticação, certifique-se de que o usuário está autenticado antes de fazer upload
- **Tamanho**: Configure limites de tamanho de arquivo apropriados
- **Tipos de arquivo**: Considere restringir tipos de arquivo permitidos em produção






