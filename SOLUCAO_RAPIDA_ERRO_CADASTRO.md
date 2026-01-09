# 🚨 Solução Rápida: Erro no Cadastro

## Problema Identificado
O erro nos logs mostra: **"500: Error sending confirmation email"**

Isso acontece porque o Supabase está tentando enviar um email de confirmação, mas o serviço de email não está configurado.

## ✅ Solução Rápida (2 minutos)

### Passo 1: Encontrar a Seção de Providers

**Como acessar:**
1. No menu lateral esquerdo, você está em **Authentication**
2. **Clique em "Authentication"** para ver todas as opções
3. Procure por uma dessas opções:
   - **"Providers"** (pode estar abaixo de "Users")
   - **"Configuration"** ou **"Config"**
   - **"Email"** (pode estar diretamente no menu)
   - Ou procure por abas na parte superior: **"Users"**, **"Providers"**, **"Settings"**

**Se não encontrar:**
- Tente clicar em diferentes itens do menu Authentication
- Procure por um ícone de **engrenagem** ⚙️ ou **configurações**
- Ou tente acessar diretamente: substitua `/users` por `/providers` na URL

### Passo 2: Desabilitar Confirmação de Email

Quando encontrar a seção de Email/Providers:

1. Clique em **Email** (ou no provider de email)
2. **DESATIVE** a opção **"Confirm email"** (toggle OFF)
3. Certifique-se de que:
   - ✅ **Enable Email provider**: Ativado
   - ✅ **Enable sign ups**: Ativado
   - ❌ **Confirm email**: **DESATIVADO**
4. Clique em **Save**

### Passo 2: Verificar Outras Configurações

Na mesma tela, certifique-se de que:
- ✅ **Enable Email provider**: Ativado
- ✅ **Enable sign ups**: Ativado
- ❌ **Confirm email**: **DESATIVADO** (importante!)

### Passo 3: Testar Novamente

1. Volte ao app
2. Tente cadastrar um novo usuário
3. Deve funcionar agora! ✅

## 🔍 Por que isso acontece?

O Supabase tenta enviar um email de confirmação quando você cadastra um usuário. Se o serviço de email (SMTP) não estiver configurado, ocorre o erro 500.

Para desenvolvimento, é mais prático desabilitar a confirmação de email. Em produção, você pode configurar o SMTP depois.

## 📧 Configurar Email (Opcional - para produção)

Se quiser habilitar confirmação de email no futuro:

1. Vá em **Authentication** → **Settings**
2. Configure **SMTP Settings** com suas credenciais de email
3. Ou use um serviço como SendGrid, Mailgun, etc.

## ✅ Após Configurar

O cadastro deve funcionar imediatamente. O usuário será criado e já estará logado automaticamente.

