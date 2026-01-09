-- ============================================
-- CONFIGURAR POLÍTICAS RLS DO STORAGE BUCKET
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- ANTES de executar, certifique-se de que o bucket "anexos-tarefas" foi criado

-- Remover políticas antigas se existirem
DROP POLICY IF EXISTS "Permitir upload de anexos" ON storage.objects;
DROP POLICY IF EXISTS "Permitir leitura de anexos" ON storage.objects;
DROP POLICY IF EXISTS "Permitir exclusão de anexos" ON storage.objects;
DROP POLICY IF EXISTS "Permitir atualização de anexos" ON storage.objects;
DROP POLICY IF EXISTS "Permitir todas as operações em anexos-tarefas" ON storage.objects;

-- Política para permitir upload de arquivos
CREATE POLICY "Permitir upload de anexos"
ON storage.objects
FOR INSERT
TO public
WITH CHECK (
  bucket_id = 'anexos-tarefas'
);

-- Política para permitir leitura de arquivos
CREATE POLICY "Permitir leitura de anexos"
ON storage.objects
FOR SELECT
TO public
USING (
  bucket_id = 'anexos-tarefas'
);

-- Política para permitir exclusão de arquivos
CREATE POLICY "Permitir exclusão de anexos"
ON storage.objects
FOR DELETE
TO public
USING (
  bucket_id = 'anexos-tarefas'
);

-- Política para permitir atualização de arquivos (se necessário)
CREATE POLICY "Permitir atualização de anexos"
ON storage.objects
FOR UPDATE
TO public
USING (
  bucket_id = 'anexos-tarefas'
)
WITH CHECK (
  bucket_id = 'anexos-tarefas'
);

-- Verificar se as políticas foram criadas
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'objects' 
  AND schemaname = 'storage'
  AND policyname LIKE '%anexos%';

