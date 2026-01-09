# 📋 Como Usar a Tabela de Usuários (Sem Confirmação de Email)

## 1. Criar a Tabela no Supabase

Execute o script SQL no Supabase Dashboard (SQL Editor):

```sql
-- Execute o arquivo: criar_tabela_usuarios.sql
```

## 2. Criar um Usuário de Teste

No SQL Editor do Supabase, execute:

```sql
-- Criar usuário de teste (senha: "123456")
-- ATENÇÃO: Em produção, use hash bcrypt!
INSERT INTO usuarios (email, senha_hash, nome) VALUES 
  ('admin@example.com', '123456', 'Administrador');
```

## 3. Atualizar o Código para Usar o Novo Sistema

### Opção A: Substituir AuthService (Recomendado)

1. Renomear `auth_service.dart` para `auth_service_old.dart`
2. Renomear `auth_service_simples.dart` para `auth_service.dart`
3. Atualizar imports no `main.dart` e `login_screen.dart`

### Opção B: Usar AuthServiceSimples Diretamente

Atualizar `main.dart` e `login_screen.dart` para usar `AuthServiceSimples` em vez de `AuthService`.

## 4. Vantagens

✅ **Sem confirmação de email** - Usuários são criados instantaneamente
✅ **Controle total** - Você gerencia os usuários diretamente no banco
✅ **Simples** - Não depende do Supabase Auth
✅ **Flexível** - Pode adicionar campos customizados facilmente

## 5. Segurança

⚠️ **IMPORTANTE**: O código atual armazena senhas em texto plano (NÃO SEGURO!)

Para produção, você deve:
1. Usar bcrypt ou outra função de hash
2. Implementar hash no backend (Edge Function do Supabase)
3. Ou usar uma biblioteca Dart para bcrypt

## 6. Exemplo de Uso

```dart
final authService = AuthServiceSimples();

// Criar usuário
final response = await authService.signUpWithEmail(
  email: 'usuario@example.com',
  password: 'senha123',
  nome: 'Nome do Usuário',
);

if (response.sucesso) {
  print('Usuário criado e logado!');
} else {
  print('Erro: ${response.erro}');
}

// Fazer login
final loginResponse = await authService.signInWithEmail(
  email: 'usuario@example.com',
  password: 'senha123',
);

// Verificar se está autenticado
if (authService.isAuthenticated) {
  print('Usuário logado: ${authService.getUserName()}');
}
```






