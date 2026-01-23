import 'usuario_service.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const String _sessionEmailKey = 'session_email';

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
      await _saveSession(usuario);
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
      await _saveSession(usuario);
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
    await _clearSession();
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

  /// Login com Azure AD (via email já autenticado pela Microsoft).
  /// Se o usuário não existir, cria um cadastro básico (sem senha) e retorna logado.
  Future<AuthResponse> signInWithAzureEmail({
    required String email,
    String? nome,
  }) async {
    try {
      final emailLower = email.toLowerCase().trim();
      if (emailLower.isEmpty) {
        return AuthResponse(sucesso: false, erro: 'Informe o email corporativo');
      }

      // Tenta localizar usuário
      final existente = await _usuarioService.obterUsuarioPorEmail(emailLower);
      if (existente != null) {
        _usuarioAtual = existente;
        await _saveSession(existente);
        return AuthResponse(usuario: existente, sucesso: true);
      }

      // Cria usuário com senha aleatória (não usada neste fluxo)
      final randomPass = const Uuid().v4();
      final novo = await _usuarioService.criarUsuario(
        email: emailLower,
        senha: randomPass,
        nome: nome,
      );
      _usuarioAtual = novo;
      await _saveSession(novo);
      return AuthResponse(usuario: novo, sucesso: true);
    } catch (e) {
      return AuthResponse(sucesso: false, erro: e.toString());
    }
  }

  // Persistência simples de sessão (email) para restaurar login
  Future<void> _saveSession(Usuario usuario) async {
    final email = usuario.email;
    // Tenta secure storage (mobile/https) e também shared_preferences (web/http)
    try {
      await _secureStorage.write(key: _sessionEmailKey, value: email);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionEmailKey, email);
    } catch (_) {}
  }

  Future<String?> _readSavedSessionEmail() async {
    String? email;
    try {
      email = await _secureStorage.read(key: _sessionEmailKey);
    } catch (_) {
      email = null;
    }
    if (email != null && email.isNotEmpty) return email;
    try {
      final prefs = await SharedPreferences.getInstance();
      email = prefs.getString(_sessionEmailKey);
    } catch (_) {
      email = null;
    }
    return email;
  }

  Future<void> _clearSession() async {
    try {
      await _secureStorage.delete(key: _sessionEmailKey);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionEmailKey);
    } catch (_) {}
  }

  Future<bool> restoreSession() async {
    try {
      final savedEmail = await _readSavedSessionEmail();
      if (savedEmail == null || savedEmail.isEmpty) return false;

      final usuario = await _usuarioService.obterUsuarioPorEmail(savedEmail);
      if (usuario == null) {
        await _clearSession();
        return false;
      }
      _usuarioAtual = usuario;
      return true;
    } catch (e) {
      return false;
    }
  }
}

