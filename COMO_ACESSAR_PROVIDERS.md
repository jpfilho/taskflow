# 📍 Como Acessar a Configuração de Providers no Supabase

## Navegação Passo a Passo

### Opção 1: Pelo Menu Lateral (Mais Comum)

1. **No menu lateral esquerdo**, você está em **Authentication** (com ícone de cadeado)
2. **Clique em "Authentication"** para expandir (se não estiver expandido)
3. Procure por uma das seguintes opções:
   - **"Providers"** (pode estar logo abaixo de "Users")
   - **"Configuration"** ou **"Config"**
   - **"Settings"** ou **"Auth Settings"**

### Opção 2: Pela Barra Superior

1. Na parte superior da tela, procure por abas ou botões:
   - **"Users"** (onde você está agora)
   - **"Providers"** ou **"Email"**
   - **"Settings"** ou **"Configuration"**
   - **"Policies"** (que você viu no menu)

### Opção 3: URL Direta

Se você conseguir ver a URL no navegador, ela deve ser algo como:
- `https://supabase.com/dashboard/project/[SEU_PROJECT_ID]/auth/users`

Para ir para Providers, tente:
- `https://supabase.com/dashboard/project/[SEU_PROJECT_ID]/auth/providers`
- Ou substitua `/users` por `/providers` na URL atual

### Opção 4: Menu de Configuração

1. Procure por um ícone de **engrenagem** ⚙️ ou **configurações** no canto superior direito
2. Ou procure por **"Settings"** no menu lateral
3. Dentro de Settings, procure por **"Authentication"** → **"Providers"**

## O que você deve ver quando encontrar:

Quando encontrar a seção de Providers, você verá:
- Uma lista de provedores de autenticação
- **Email** (deve estar na lista)
- Botões para ativar/desativar cada provider
- Configurações específicas para cada provider

## Se não encontrar:

1. **Tente clicar em "Authentication"** no menu lateral para ver todas as opções
2. **Procure por "Email"** diretamente no menu
3. **Verifique se há um botão "Add Provider"** ou similar
4. **Tente acessar via URL**: adicione `/providers` ao final da URL atual

## Alternativa: Configurar via SQL (Se não encontrar a interface)

Se não conseguir encontrar a interface, você pode verificar/alterar via SQL Editor:

1. Vá em **SQL Editor** no menu lateral
2. Execute:

```sql
-- Verificar configurações de autenticação
SELECT * FROM auth.config;
```

Mas a forma mais fácil é pela interface. Tente expandir o menu "Authentication" no lado esquerdo e procurar por "Providers" ou "Email".






