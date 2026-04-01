import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;

  // Obter usuário atual
  User? get currentUser => _supabase.auth.currentUser;

  // Verificar se está autenticado
  bool get isAuthenticated => currentUser != null;

  // Stream de mudanças de autenticação
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Fazer login com email e senha
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Registrar novo usuário
  // TEMPORÁRIO: Estratégia simplificada - tenta criar e, se der erro de email, tenta login direto
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? nome,
  }) async {
    try {
      // Tentar criar o usuário
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: nome != null ? {'nome': nome} : null,
        emailRedirectTo: null,
      );
      
      // Se já tem sessão, retornar
      if (response.session != null) {
        print('✅ Usuário criado e logado automaticamente');
        return response;
      }
      
      // Se não tem sessão, aguardar e tentar login
      print('ℹ️ Usuário criado sem sessão. Aguardando 5 segundos e tentando login...');
      await Future.delayed(const Duration(seconds: 5));
      
      // Tentar login direto
      return await _tryLoginAfterSignup(email, password);
      
    } catch (e) {
      print('⚠️ Erro ao registrar: $e');
      
      // Verificar PRIMEIRO se é erro de conectividade (503) - PARAR IMEDIATAMENTE
      bool isConnectionError = false;
      
      if (e is AuthRetryableFetchException) {
        // Verificar statusCode 503 PRIMEIRO
        if (e.statusCode == 503) {
          print('🚫 Erro 503 detectado - Serviço não acessível. Parando imediatamente.');
          isConnectionError = true;
        } else {
          // Verificar mensagem mesmo se não for 503
          final message = e.message.toLowerCase();
          if (message.contains('name resolution') || 
              message.contains('connection') ||
              message.contains('network')) {
            print('🚫 Erro de conectividade detectado na mensagem. Parando imediatamente.');
            isConnectionError = true;
          }
        }
      }
      
      // Obter string do erro para verificações adicionais
      final errorString = e.toString().toLowerCase();
      
      // Verificar também pela string do erro (fallback)
      if (!isConnectionError) {
        if (errorString.contains('statuscode: 503') ||
            errorString.contains('statuscode 503') ||
            errorString.contains('"statuscode":503') ||
            errorString.contains('name resolution') ||
            (errorString.contains('503') && errorString.contains('authretryable'))) {
          print('🚫 Erro 503 detectado na string. Parando imediatamente.');
          isConnectionError = true;
        }
      }
      
      // Se for erro de conectividade, PARAR IMEDIATAMENTE
      if (isConnectionError) {
        throw Exception(
          'Serviço de autenticação não está acessível. '
          'Verifique se o servidor está rodando e tente novamente.'
        );
      }
      
      // Verificar se é erro de confirmação de email (usuário pode ter sido criado)
      final isEmailError = errorString.contains('confirmation email') || 
          (errorString.contains('500') && !isConnectionError) ||
          (errorString.contains('email') && errorString.contains('error') && !isConnectionError);
      
      if (isEmailError) {
        print('⚠️ Erro relacionado a email. Aguardando 5 segundos e tentando login direto...');
        await Future.delayed(const Duration(seconds: 5));
        
        try {
          return await _tryLoginAfterSignup(email, password);
        } catch (loginError) {
          print('❌ Login também falhou: $loginError');
          
          // Verificar se o erro de login também é de conectividade
          bool isLoginConnectionError = false;
          if (loginError is AuthRetryableFetchException) {
            if (loginError.statusCode == 503 || 
                loginError.message.toLowerCase().contains('name resolution')) {
              isLoginConnectionError = true;
            }
          }
          
          final loginErrorStr = loginError.toString().toLowerCase();
          if (!isLoginConnectionError) {
            isLoginConnectionError = loginErrorStr.contains('503') || 
                loginErrorStr.contains('name resolution');
          }
          
          if (isLoginConnectionError) {
            throw Exception(
              'Serviço de autenticação não está acessível. '
              'Verifique se o servidor está rodando e tente novamente.'
            );
          }
          
          throw Exception(
            'Não foi possível criar a conta. '
            'O servidor pode estar com problemas de configuração. '
            'Tente novamente em alguns instantes ou entre em contato com o suporte.'
          );
        }
      }
      
      // Se não for erro conhecido, lançar o erro original
      rethrow;
    }
  }

  // Método auxiliar para tentar login após signup
  Future<AuthResponse> _tryLoginAfterSignup(String email, String password) async {
    // Tentar login até 5 vezes com intervalos crescentes
    for (int tentativa = 1; tentativa <= 5; tentativa++) {
      try {
        print('🔄 Tentativa $tentativa de login após signup...');
        final loginResponse = await _supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
        
        if (loginResponse.session != null) {
          print('✅ Login bem-sucedido após signup!');
          return loginResponse;
        }
      } catch (loginError) {
        print('❌ Tentativa $tentativa falhou: $loginError');
        
        // Verificar se é erro de conectividade pelo tipo de exceção
        bool isConnectionError = false;
        if (loginError is AuthRetryableFetchException) {
          if (loginError.statusCode == 503 || 
              loginError.message.toLowerCase().contains('name resolution') ||
              loginError.message.toLowerCase().contains('connection')) {
            isConnectionError = true;
          }
        }
        
        // Verificar também pela string do erro
        final errorStr = loginError.toString().toLowerCase();
        if (!isConnectionError) {
          isConnectionError = errorStr.contains('503') || 
              errorStr.contains('name resolution') ||
              errorStr.contains('connection') ||
              errorStr.contains('network');
        }
        
        // Se for erro de conectividade, parar imediatamente
        if (isConnectionError) {
          throw Exception(
            'Serviço de autenticação não está acessível. '
            'Verifique se o servidor está rodando.'
          );
        }
        
        // Se for erro de credenciais inválidas, pode ser que o usuário não foi criado
        // Continuar tentando pode ajudar se o usuário está sendo criado
        if (errorStr.contains('invalid') && errorStr.contains('credentials')) {
          // Se já tentou 3 vezes e ainda dá erro de credenciais, provavelmente o usuário não foi criado
          if (tentativa >= 3) {
            throw Exception(
              'Não foi possível fazer login. '
              'O usuário pode não ter sido criado. Tente criar novamente.'
            );
          }
        }
        
        // Se não for a última tentativa, aguardar mais
        if (tentativa < 5) {
          final delay = tentativa * 2; // 2, 4, 6, 8 segundos
          print('⏳ Aguardando $delay segundos antes da próxima tentativa...');
          await Future.delayed(Duration(seconds: delay));
        } else {
          // Na última tentativa, lançar erro
          rethrow;
        }
      }
    }
    
    throw Exception('Não foi possível fazer login após criar a conta.');
  }

  // Fazer logout
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  // Redefinir senha
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      rethrow;
    }
  }

  // Atualizar perfil do usuário
  Future<UserResponse> updateProfile({
    String? nome,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (nome != null) {
        updates['nome'] = nome;
      }
      if (metadata != null) {
        updates.addAll(metadata);
      }

      final response = await _supabase.auth.updateUser(
        UserAttributes(data: updates),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Obter nome do usuário (do metadata ou email)
  String? getUserName() {
    final user = currentUser;
    if (user == null) return null;
    
    // Tentar obter do metadata
    final nome = user.userMetadata?['nome'] as String?;
    if (nome != null && nome.isNotEmpty) {
      return nome;
    }
    
    // Fallback para email (sem o domínio)
    final email = user.email;
    if (email != null) {
      return email.split('@').first;
    }
    
    return null;
  }

  // Obter email do usuário
  String? getUserEmail() {
    return currentUser?.email;
  }
}

