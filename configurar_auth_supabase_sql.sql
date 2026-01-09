-- Script para verificar e configurar autenticação no Supabase
-- Execute este script no SQL Editor do Supabase Dashboard

-- 1. Verificar se a autenticação está habilitada
-- (A tabela auth.users é criada automaticamente pelo Supabase)

-- 2. Verificar configurações de autenticação
SELECT 
  name,
  setting,
  source
FROM pg_settings
WHERE name LIKE '%auth%' OR name LIKE '%jwt%'
ORDER BY name;

-- 3. Verificar usuários cadastrados (apenas para debug)
-- Descomente para ver usuários (remova em produção)
/*
SELECT 
  id,
  email,
  created_at,
  email_confirmed_at,
  last_sign_in_at,
  raw_user_meta_data
FROM auth.users
ORDER BY created_at DESC
LIMIT 10;
*/

-- 4. Verificar políticas RLS nas tabelas principais
-- (As políticas devem permitir acesso para usuários autenticados)

-- Exemplo: Verificar políticas da tabela tasks
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
WHERE tablename IN ('tasks', 'comunidades', 'grupos_chat', 'mensagens')
ORDER BY tablename, policyname;

-- 5. Se necessário, atualizar políticas para permitir usuários autenticados
-- (Ajuste conforme suas necessidades de segurança)

-- Exemplo para tabela tasks (se ainda não tiver políticas adequadas):
/*
DROP POLICY IF EXISTS "Permitir usuários autenticados" ON tasks;
CREATE POLICY "Permitir usuários autenticados" ON tasks
  FOR ALL 
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');
*/

-- 6. Verificar se o provider de email está habilitado
-- (Isso deve ser feito no Dashboard: Authentication → Providers → Email)

-- 7. Verificar configuração de JWT
SELECT 
  current_setting('app.settings.jwt_secret', true) as jwt_secret_exists,
  current_setting('app.settings.jwt_expiry', true) as jwt_expiry;

-- NOTA: A maioria das configurações de autenticação deve ser feita
-- através do Dashboard do Supabase, não via SQL.

