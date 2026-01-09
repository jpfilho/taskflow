-- Script para desabilitar confirmação de email no Supabase self-hosted
-- Execute este script no SQL Editor do Supabase

-- 1. Verificar configurações atuais de autenticação
SELECT 
  name,
  value
FROM auth.config
WHERE name LIKE '%email%' OR name LIKE '%confirm%';

-- 2. Desabilitar confirmação de email
-- Atualizar a configuração para não exigir confirmação de email
UPDATE auth.config
SET value = 'false'
WHERE name = 'SITE_URL' OR name = 'ENABLE_SIGNUP';

-- 3. Verificar se existe tabela de configurações do auth
-- Se a tabela auth.config não existir, tente estas alternativas:

-- Alternativa 1: Verificar variáveis de ambiente (se acessível)
-- SELECT * FROM pg_settings WHERE name LIKE '%auth%email%';

-- Alternativa 2: Verificar se há uma tabela de settings
SELECT 
  table_name
FROM information_schema.tables
WHERE table_schema = 'auth'
ORDER BY table_name;

-- 4. Se não conseguir via SQL, você pode precisar editar o arquivo .env
-- do Supabase no servidor VPS da Hostinger
-- Procure por: ENABLE_EMAIL_CONFIRMATION=false

-- 5. Verificar configuração atual de signup
SELECT 
  'Email signup enabled' as setting,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM auth.config WHERE name = 'ENABLE_SIGNUP' AND value = 'true'
    ) THEN 'SIM'
    ELSE 'NÃO'
  END as status;






