# 📋 EXECUTAR MIGRATION SQL

## 🔐 PASSO 1: Abrir Supabase Studio

1. Abra no navegador: **https://212.85.0.249**
2. Aceite o aviso de certificado auto-assinado
3. Faça login com:
   - **Username:** `supabase`
   - **Password:** `Elen@264259281091` (do arquivo supabase_env.txt)

---

## 📝 PASSO 2: Ir para SQL Editor

1. No menu lateral esquerdo, clique em **"SQL Editor"**
2. Clique em **"New query"** (Nova consulta)

---

## 📄 PASSO 3: Copiar o SQL

1. Abra o arquivo: `supabase\migrations\20260124_telegram_integration.sql`
2. **Selecione TODO o conteúdo** (Ctrl+A)
3. **Copie** (Ctrl+C)

---

## ▶️ PASSO 4: Executar no Supabase

1. **Cole** o SQL no editor (Ctrl+V)
2. Clique em **"Run"** (Executar) ou pressione **Ctrl+Enter**
3. Aguarde a execução (deve levar 5-10 segundos)

---

## ✅ PASSO 5: Verificar Sucesso

**Se der certo, você verá:**
- ✅ Mensagens de sucesso no painel inferior
- ✅ "Query executed successfully"

**Se der erro:**
- ❌ Copie a mensagem de erro completa
- ❌ Me envie para eu corrigir

---

## 🔍 VERIFICAÇÃO RÁPIDA

Após executar, rode este SQL para verificar se as tabelas foram criadas:

```sql
SELECT tablename FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename LIKE 'telegram%';
```

**Deve retornar:**
- `telegram_identities`
- `telegram_subscriptions`
- `telegram_delivery_logs`

---

## 💡 DICA

Se precisar executar novamente (resetar), primeiro delete as tabelas:

```sql
DROP TABLE IF EXISTS telegram_delivery_logs CASCADE;
DROP TABLE IF EXISTS telegram_subscriptions CASCADE;
DROP TABLE IF EXISTS telegram_identities CASCADE;
DROP TYPE IF EXISTS telegram_thread_type CASCADE;
DROP TYPE IF EXISTS telegram_mode_type CASCADE;
DROP FUNCTION IF EXISTS can_access_thread CASCADE;
DROP FUNCTION IF EXISTS get_task_id_from_grupo_chat CASCADE;
DROP FUNCTION IF EXISTS get_comunidade_id_from_grupo_chat CASCADE;
ALTER TABLE mensagens DROP COLUMN IF EXISTS source CASCADE;
ALTER TABLE mensagens DROP COLUMN IF EXISTS telegram_metadata CASCADE;
```

Depois execute a migration completa novamente.
