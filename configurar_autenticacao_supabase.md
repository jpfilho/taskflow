# Configuração de Autenticação no Supabase

Este guia explica como configurar a autenticação no Supabase para o sistema de login funcionar corretamente.

## 1. Habilitar Autenticação por Email (IMPORTANTE - RESOLVE O ERRO)

1. Acesse o **Supabase Dashboard**: https://supabase.com/dashboard
2. Selecione seu projeto
3. Vá em **Authentication** → **Providers**
4. Clique em **Email** para configurar
5. Configure as opções:
   - ✅ **Enable Email provider**: Ativado
   - ❌ **Confirm email**: **DESATIVAR** (isso resolve o erro "Error sending confirmation email")
   - ✅ **Secure email change**: Opcional
   - ✅ **Enable sign ups**: Ativado

**⚠️ IMPORTANTE:** Desative "Confirm email" para desenvolvimento. Isso evita o erro 500 ao cadastrar usuários.

## 2. Configurar Políticas de Autenticação (RLS)

Execute o seguinte script SQL no **SQL Editor** do Supabase:

```sql
-- Verificar se a tabela auth.users existe (ela é criada automaticamente pelo Supabase)
-- Não precisamos criar, apenas configurar políticas se necessário

-- Habilitar autenticação anônima temporariamente para desenvolvimento
-- (Pode ser desabilitado em produção)
-- Isso já deve estar configurado por padrão no Supabase

-- Verificar configurações de autenticação
SELECT 
  name,
  value
FROM pg_settings
WHERE name LIKE '%auth%'
ORDER BY name;
```

## 3. Configurar Site URL e Redirect URLs

1. No Supabase Dashboard, vá em **Authentication** → **URL Configuration**
2. Configure:
   - **Site URL**: `http://localhost:3000` (para desenvolvimento web) ou sua URL de produção
   - **Redirect URLs**: Adicione:
     - `http://localhost:3000/**`
     - `https://seu-dominio.com/**`
     - Para Flutter Web: `http://localhost:*/**`
     - Para Flutter Mobile: `com.example.task2026://**` (ou seu bundle ID)

## 4. Verificar Configuração de Email (Opcional)

Se você quiser que os usuários confirmem o email:

1. Vá em **Authentication** → **Email Templates**
2. Configure os templates de email conforme necessário
3. Ou desative a confirmação de email para desenvolvimento (recomendado)

## 5. Testar Autenticação

Após configurar, teste criando um usuário:

1. No app, clique em "Cadastre-se"
2. Preencha email e senha
3. Se der erro, verifique:
   - Se o Email provider está habilitado
   - Se há políticas RLS bloqueando
   - Se a Site URL está configurada corretamente

## 6. Solução de Problemas Comuns

### Erro: "Email rate limit exceeded"
- Aguarde alguns minutos e tente novamente
- Ou aumente o limite em **Authentication** → **Settings**

### Erro: "Invalid login credentials"
- Verifique se o email está correto
- Verifique se a senha está correta
- Se acabou de criar a conta, pode precisar confirmar o email

### Erro: "Email not confirmed"
- **Solução:** Desative a confirmação de email em **Authentication** → **Providers** → **Email** → **Confirm email** (toggle OFF)

### Erro: "500: Error sending confirmation email" ⚠️ **ERRO ATUAL**
- **Causa:** Confirmação de email está ativada mas SMTP não está configurado
- **Solução RÁPIDA:** Desative "Confirm email" em **Authentication** → **Providers** → **Email**
- **Solução COMPLETA:** Configure SMTP em **Authentication** → **Settings** → **SMTP Settings**

### Erro: "User already registered"
- O email já está cadastrado
- Tente fazer login ao invés de cadastrar

## 7. Configuração para Produção

Para produção, certifique-se de:

1. ✅ Habilitar confirmação de email
2. ✅ Configurar Site URL correta
3. ✅ Configurar Redirect URLs corretas
4. ✅ Revisar políticas RLS
5. ✅ Configurar templates de email personalizados
6. ✅ Configurar rate limits apropriados

## 8. Verificar Status da Autenticação

Execute no SQL Editor para ver usuários cadastrados:

```sql
-- Ver usuários autenticados (apenas para verificação, não use em produção)
SELECT 
  id,
  email,
  created_at,
  email_confirmed_at,
  last_sign_in_at
FROM auth.users
ORDER BY created_at DESC
LIMIT 10;
```

