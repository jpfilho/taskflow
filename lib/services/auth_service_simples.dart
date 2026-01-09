import 'usuario_service.dart';

// Classe simples para simular AuthResponse
class AuthResponse {
  final Usuario? usuario;
  final bool sucesso;
  final String? erro;

  AuthResponse({
    this.usuario,
    this.sucesso = false,
    this.erro,
  });
}

class AuthServiceSimples {
  static final AuthServiceSimples _instance = AuthServiceSimples._internal();
  factory AuthServiceSimples() => _instance;
  AuthServiceSimples._internal();

  final UsuarioService _usuarioService = UsuarioService();
  Usuario? _usuarioAtual;

  // Obter usuário atual
  Usuario? get currentUser => _usuarioAtual;

  // Verificar se está autenticado
  bool get isAuthenticated => _usuarioAtual != null;

  // Fazer login com email e senha
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final usuario = await _usuarioService.fazerLogin(
        email: email,
        senha: password,
      );

      if (usuario == null) {
        return AuthResponse(
          sucesso: false,
          erro: 'Email ou senha incorretos',
        );
      }

      _usuarioAtual = usuario;
      return AuthResponse(
        usuario: usuario,
        sucesso: true,
      );
    } catch (e) {
      return AuthResponse(
        sucesso: false,
        erro: e.toString(),
      );
    }
  }

  // Registrar novo usuário
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? nome,
  }) async {
    try {
      // Verificar se o usuário já existe
      final usuarioExistente = await _usuarioService.obterUsuarioPorEmail(email);
      if (usuarioExistente != null) {
        return AuthResponse(
          sucesso: false,
          erro: 'Este email já está cadastrado',
        );
      }

      // Criar novo usuário
      final usuario = await _usuarioService.criarUsuario(
        email: email,
        senha: password,
        nome: nome,
      );

      // Fazer login automaticamente após cadastro
      _usuarioAtual = usuario;
      return AuthResponse(
        usuario: usuario,
        sucesso: true,
      );
    } catch (e) {
      return AuthResponse(
        sucesso: false,
        erro: e.toString(),
      );
    }
  }

  // Fazer logout
  Future<void> signOut() async {
    _usuarioAtual = null;
  }

  // Atualizar usuário atual (usado após atualizar perfil)
  void atualizarUsuarioAtual(Usuario usuario) {
    _usuarioAtual = usuario;
  }

  // Obter nome do usuário
  String? getUserName() {
    return _usuarioAtual?.nome ?? _usuarioAtual?.email.split('@').first;
  }

  // Obter email do usuário
  String? getUserEmail() {
    return _usuarioAtual?.email;
  }

  // Redefinir senha (implementação simples - sem envio de email)
  Future<void> resetPassword(String email) async {
    // Por enquanto, apenas verificar se o usuário existe
    // Em produção, você pode implementar envio de email ou token de redefinição
    final usuario = await _usuarioService.obterUsuarioPorEmail(email);
    if (usuario == null) {
      throw Exception('Usuário não encontrado');
    }
    // Em produção, aqui você enviaria um email com link de redefinição
    // Por enquanto, apenas retorna sucesso (o usuário precisará alterar manualmente no banco)
  }
}

