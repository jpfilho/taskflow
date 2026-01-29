# 📱 Como Vincular um Contato que Está no Grupo do Telegram

Este guia explica como vincular um contato/usuário que já está participando do grupo do Telegram ao sistema TaskFlow.

## 🎯 Passo a Passo

### 1️⃣ Obter o Telegram User ID do Contato

Existem várias formas de obter o Telegram User ID de alguém que está no grupo:

#### Método A: Pedir para o Contato Enviar uma Mensagem (Mais Fácil)

1. **Peça para o contato enviar uma mensagem no grupo** (pode ser qualquer coisa, como "Olá")
2. **Execute o script para obter o User ID dos logs:**
   ```powershell
   .\obter_telegram_user_id.ps1
   ```
3. O script vai mostrar o Telegram User ID de quem enviou mensagens recentes

#### Método B: Usar Bot Auxiliar no Telegram

1. **Adicione o bot [@userinfobot](https://t.me/userinfobot) ao grupo**
2. **Peça para o contato mencionar o bot** (ex: `@userinfobot`)
3. O bot vai responder com o User ID do contato

#### Método C: Verificar Logs do Webhook Manualmente

1. **Peça para o contato enviar uma mensagem no grupo**
2. **Acesse o servidor e verifique os logs:**
   ```powershell
   ssh root@212.85.0.249
   docker logs supabase-functions --tail 100 | grep "from.id"
   ```
3. Procure por `"from": { "id": 1234567890 }` nos logs

#### Método D: Usar API do Telegram (Avançado)

Se você tem acesso ao token do bot:

```powershell
$token = "SEU_BOT_TOKEN"
$chatId = "-1001234567890"  # ID do grupo

# Listar membros do grupo (requer que o bot seja admin)
Invoke-RestMethod -Uri "https://api.telegram.org/bot$token/getChatMembersCount?chat_id=$chatId"
```

### 2️⃣ Identificar o Executor/Usuário no Sistema

Antes de vincular, você precisa saber qual executor/usuário do sistema corresponde ao contato do Telegram:

#### Opção A: Listar Executores Disponíveis

```powershell
# Conectar ao servidor e listar executores
ssh root@212.85.0.249 "docker exec supabase-db psql -U postgres -d postgres -c \"SELECT id, nome, matricula, telefone FROM executores WHERE ativo = true ORDER BY nome;\""
```

#### Opção B: Buscar por Matrícula ou Nome

Se você sabe a matrícula ou nome do executor:

```powershell
ssh root@212.85.0.249 "docker exec supabase-db psql -U postgres -d postgres -c \"SELECT id, nome, matricula FROM executores WHERE matricula = '123456' OR nome ILIKE '%João%';\""
```

### 3️⃣ Vincular o Contato ao Sistema

Agora que você tem:
- ✅ **Telegram User ID** (ex: `7807721517`)
- ✅ **ID do Executor** no sistema (UUID)
- ✅ **Nome do contato** no Telegram (opcional)
- ✅ **Username do Telegram** (opcional, ex: `@joao_silva`)

#### Opção A: Usar Script Interativo (Recomendado)

```powershell
# Windows PowerShell
.\vincular_telegram_interativo.ps1
```

O script vai perguntar:
1. Matrícula do executor
2. Telegram User ID
3. Telegram Username (opcional)
4. Primeiro Nome no Telegram (opcional)

#### Opção B: Vincular Manualmente via SQL

```sql
-- Substitua os valores abaixo:
-- executor_id: UUID do executor no sistema
-- telegram_user_id: ID do Telegram (número)
-- telegram_username: @username (opcional)
-- telegram_first_name: Nome no Telegram (opcional)

INSERT INTO telegram_identities (
    user_id,
    telegram_user_id,
    telegram_username,
    telegram_first_name,
    linked_at,
    last_active_at
) VALUES (
    'uuid-do-executor-aqui',
    7807721517,  -- Telegram User ID
    'joao_silva',  -- Username (sem @)
    'João Silva',  -- Primeiro nome
    NOW(),
    NOW()
) ON CONFLICT (telegram_user_id) DO UPDATE SET
    user_id = EXCLUDED.user_id,
    telegram_username = COALESCE(EXCLUDED.telegram_username, telegram_identities.telegram_username),
    telegram_first_name = COALESCE(EXCLUDED.telegram_first_name, telegram_identities.telegram_first_name),
    linked_at = NOW();
```

#### Opção C: Script PowerShell Direto

Crie um script personalizado baseado em `vincular_executor_telegram.ps1`:

```powershell
$SERVER = "root@212.85.0.249"

# Dados do contato
$MATRICULA = "123456"  # Matrícula do executor
$TELEGRAM_USER_ID = 7807721517
$TELEGRAM_USERNAME = "joao_silva"
$TELEGRAM_FIRST_NAME = "João"

$sqlVincular = @"
DO `$`$
DECLARE
    executor_id UUID;
    executor_nome VARCHAR;
BEGIN
    -- Buscar executor
    SELECT id, nome INTO executor_id, executor_nome
    FROM executores 
    WHERE matricula = '$MATRICULA';
    
    IF executor_id IS NULL THEN
        RAISE EXCEPTION 'Executor com matricula $MATRICULA nao encontrado!';
    END IF;
    
    -- Vincular Telegram
    INSERT INTO telegram_identities (
        user_id,
        telegram_user_id,
        telegram_username,
        telegram_first_name,
        linked_at
    ) VALUES (
        executor_id,
        $TELEGRAM_USER_ID,
        '$TELEGRAM_USERNAME',
        '$TELEGRAM_FIRST_NAME',
        NOW()
    ) ON CONFLICT (telegram_user_id) DO UPDATE SET
        user_id = EXCLUDED.user_id,
        telegram_username = COALESCE(EXCLUDED.telegram_username, telegram_identities.telegram_username),
        telegram_first_name = COALESCE(EXCLUDED.telegram_first_name, telegram_identities.telegram_first_name),
        linked_at = NOW();
    
    RAISE NOTICE 'Telegram vinculado com sucesso!';
END `$`$;
"@

ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -c `"$sqlVincular`""
```

### 4️⃣ Verificar se a Vinculação Funcionou

```sql
SELECT 
    ti.telegram_user_id,
    ti.telegram_first_name,
    ti.telegram_username,
    e.matricula,
    e.nome,
    ti.linked_at
FROM telegram_identities ti
JOIN executores e ON e.id = ti.user_id
WHERE ti.telegram_user_id = 7807721517;  -- Substitua pelo User ID
```

Ou via PowerShell:

```powershell
ssh root@212.85.0.249 "docker exec supabase-db psql -U postgres -d postgres -c \"SELECT ti.telegram_user_id, ti.telegram_first_name, e.nome, e.matricula FROM telegram_identities ti JOIN executores e ON e.id = ti.user_id WHERE ti.telegram_user_id = 7807721517;\""
```

### 5️⃣ Testar a Vinculação

1. **Peça para o contato enviar uma mensagem no grupo do Telegram**
2. **Verifique se a mensagem aparece no app Flutter** (deve aparecer com o nome do executor vinculado)
3. **Verifique no banco de dados:**

```sql
SELECT 
    m.id,
    m.conteudo,
    m.criado_em,
    e.nome as executor_nome,
    ti.telegram_first_name
FROM mensagens m
JOIN executores e ON e.id = m.executor_id
LEFT JOIN telegram_identities ti ON ti.user_id = e.id
WHERE m.criado_em > NOW() - INTERVAL '5 minutes'
ORDER BY m.criado_em DESC
LIMIT 10;
```

## 📋 Resumo Rápido

1. **Obter Telegram User ID:**
   - Contato envia mensagem no grupo
   - Execute: `.\obter_telegram_user_id.ps1`

2. **Identificar Executor:**
   - Liste executores: `SELECT * FROM executores WHERE ativo = true;`
   - Anote o UUID do executor

3. **Vincular:**
   - Use: `.\vincular_telegram_interativo.ps1`
   - Ou execute SQL manualmente

4. **Testar:**
   - Contato envia mensagem no grupo
   - Verifica se aparece no app Flutter

## ⚠️ Observações Importantes

- **Telegram User ID é único**: Cada conta Telegram tem um ID único (número)
- **Um executor pode ter apenas um Telegram vinculado**: Se tentar vincular outro Telegram ao mesmo executor, o anterior será substituído
- **Um Telegram pode estar vinculado a apenas um executor**: Se o Telegram User ID já estiver vinculado, será atualizado para o novo executor
- **O contato precisa estar no grupo**: Para que as mensagens sejam processadas, o contato precisa estar no grupo onde o bot está presente

## 🔧 Troubleshooting

### Erro: "Executor não encontrado"
- Verifique se a matrícula está correta
- Verifique se o executor está ativo (`ativo = true`)

### Erro: "Telegram User ID já vinculado"
- O Telegram User ID já está vinculado a outro executor
- Use `ON CONFLICT` para atualizar ou desvincule primeiro

### Mensagens não aparecem no app
- Verifique se o contato está no grupo correto
- Verifique se o bot está no grupo e é administrador
- Verifique os logs do webhook: `docker logs supabase-functions --tail 50`

### Não consigo obter o Telegram User ID
- Use o bot @userinfobot no grupo
- Verifique os logs do servidor após o contato enviar uma mensagem
- Use a API do Telegram se tiver acesso ao token do bot

## 💡 Dica Pro

Crie uma planilha com:
- Nome do contato
- Telegram User ID
- Matrícula do executor
- Data da vinculação
- Status (ativo/inativo)

Isso facilita o gerenciamento de múltiplos contatos!
