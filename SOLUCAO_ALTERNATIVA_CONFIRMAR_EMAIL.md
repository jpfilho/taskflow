# 🔧 Solução Alternativa: Confirmar Email via API Admin

Como a configuração do `.env` não está funcionando, vamos usar a API Admin do Supabase para confirmar o email automaticamente após criar o usuário.

## Como Funciona:

1. Usuário tenta se cadastrar
2. Se der erro 500 de email, o usuário é criado mas não confirmado
3. Usamos a API Admin para confirmar o email automaticamente
4. Depois fazemos login normalmente

## ⚠️ IMPORTANTE - Segurança:

Para usar a API Admin, precisamos da **Service Role Key** (não a anon key). Esta chave tem acesso total ao banco e **NUNCA deve ser exposta no código do cliente**.

## Opções:

### Opção 1: Backend/Edge Function (Recomendado)
Criar uma Edge Function no Supabase que:
- Recebe email e senha
- Cria o usuário
- Confirma o email usando Service Role
- Retorna a sessão

### Opção 2: Modificar GoTrue diretamente (Mais simples)
Editar o docker-compose.yml para desabilitar email confirmation diretamente.

### Opção 3: Usar variável de ambiente no docker-compose.yml
Adicionar a variável diretamente no docker-compose.yml ao invés do .env

## Qual você prefere?

**Recomendo a Opção 2 ou 3** - são mais simples e não expõem a Service Role Key.

**Execute no servidor:**
```bash
cd /root/supabase/docker
cat docker-compose.yml | grep -A 20 "supabase-auth"
```

Me mostre o resultado para eu te ajudar a editar diretamente!






