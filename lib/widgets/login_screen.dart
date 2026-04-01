import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:ui';
import '../services/auth_service_simples.dart';
import '../services/biometric_service.dart';
import '../services/azure_auth_service.dart';
import '../services/azure_auth_service_stub.dart'
    if (dart.library.js) '../services/azure_auth_service_web.dart';

// Design System Tokens
class AxiaColors {
  static const primaryBlue = Color(0xFF0000FF);
  static const blue1 = Color(0xFF1726C8);
  static const purple = Color(0xFF0A003C);
  static const neutral = Color(0xFFE8E5E3);
  static const offWhite = Color(0xFFFAF5F0);
  static const grey1 = Color(0xFF1A1F25);
  static const glassOverlay = Color(0x80000000); // 50% opacity black
}

class LoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const LoginScreen({super.key, this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nomeController = TextEditingController(); // Para registro
  final _authService = AuthServiceSimples();
  final _biometricService = BiometricService();
  final _azureAuthService = AzureAuthService();
  final _azureAuthServiceWeb = AzureAuthServiceWeb();
  final bool _azureLoginEnabled =
      false; // Temporariamente desativado até aprovação admin
  final _passwordFocusNode = FocusNode();
  final _nomeFocusNode = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isLoginMode = true; // true = login, false = registro
  bool _showBiometricOption = false;

  late VideoPlayerController _videoController;
  bool _videoInitialized = false;
  late VoidCallback _videoListener;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
    _loadSavedCredentials();
    _initVideo();
  }

  void _initVideo() {
    _videoController = VideoPlayerController.asset('assets/videos/intro.mp4');

    _videoController
        .initialize()
        .then((_) {
          if (!mounted) return;

          setState(() {
            _videoInitialized = true;
          });

          // Configurações garantidas antes do play
          _videoController.setLooping(false);
          _videoController.setVolume(
            0,
          ); // Muted para facilitar o autoplay nos browsers

          // Delay pequeno ou PostFrameCallback para garantir que o widget VideoPlayer já esteja na árvore
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _videoController.play();
            }
          });

          // Esconder o vídeo quando terminar de tocar
          _videoListener = () {
            if (!_videoController.value.isInitialized) return;
            final pos = _videoController.value.position;
            final dur = _videoController.value.duration;
            if (pos >= dur - const Duration(milliseconds: 200)) {
              if (mounted) {
                setState(() {
                  _videoInitialized = false;
                });
              }
              _videoController.removeListener(_videoListener);
            }
          };
          _videoController.addListener(_videoListener);
        })
        .catchError((error) {
          print('❌ Erro ao inicializar vídeo de fundo: $error');
          if (mounted) {
            setState(() {
              _videoInitialized = false;
            });
          }
        });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nomeController.dispose();
    _passwordFocusNode.dispose();
    _nomeFocusNode.dispose();
    try {
      _videoController.removeListener(_videoListener);
    } catch (_) {}
    _videoController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricAvailability() async {
    final shouldShow = await _biometricService.shouldShowBiometricOption();
    if (mounted) {
      setState(() {
        _showBiometricOption = shouldShow;
      });
    }
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final credentials = await _biometricService.getSavedCredentials();
      if (credentials['email'] != null && mounted) {
        _emailController.text = credentials['email']!;
      }
    } catch (e) {
      print('Erro ao carregar credenciais salvas: $e');
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLoginMode) {
        // Login
        final response = await _authService.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (mounted) {
          if (response.sucesso) {
            // Salvar credenciais para autenticação biométrica
            await _biometricService.saveCredentials(
              _emailController.text.trim(),
              _passwordController.text,
            );

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Login realizado com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
            // Notificar sucesso
            widget.onLoginSuccess?.call();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response.erro ?? 'Erro ao fazer login'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        // Registro
        final response = await _authService.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          nome: _nomeController.text.trim().isNotEmpty
              ? _nomeController.text.trim()
              : null,
        );

        if (mounted) {
          if (response.sucesso) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Conta criada e você foi logado automaticamente!',
                ),
                backgroundColor: Colors.green,
              ),
            );
            // Notificar sucesso
            widget.onLoginSuccess?.call();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response.erro ?? 'Erro ao criar conta'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleBiometricAuth() async {
    try {
      setState(() => _isLoading = true);

      // Autenticar com biometria
      final authenticated = await _biometricService.authenticate();

      if (!authenticated) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Autenticação biométrica cancelada ou falhou'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Obter credenciais salvas
      final credentials = await _biometricService.getSavedCredentials();

      if (credentials['email'] == null || credentials['password'] == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Credenciais não encontradas. Faça login manualmente.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Preencher campos
      _emailController.text = credentials['email']!;
      _passwordController.text = credentials['password']!;

      // Fazer login
      final response = await _authService.signInWithEmail(
        email: credentials['email']!,
        password: credentials['password']!,
      );

      if (mounted) {
        setState(() => _isLoading = false);

        if (response.sucesso) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login realizado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onLoginSuccess?.call();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.erro ?? 'Erro ao fazer login'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro na autenticação biométrica: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleResetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite seu email para redefinir a senha'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await _authService.resetPassword(_emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email de redefinição de senha enviado!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar email: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Video
          if (_videoInitialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController.value.size.width,
                  height: _videoController.value.size.height,
                  child: VideoPlayer(_videoController),
                ),
              ),
            )
          else
            Container(color: AxiaColors.grey1),

          // Glass / Blur Overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: AxiaColors.glassOverlay),
            ),
          ),

          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 450 : double.infinity,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Entrance Animation Wrapper could go here
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(seconds: 1),
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 50 * (1 - value)),
                                child: child,
                              ),
                            );
                          },
                          child: Column(
                            children: [
                              // Logo/Ícone
                              const Icon(
                                Icons.task_alt,
                                size: 80,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Task Flow',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isLoginMode
                                    ? 'O novo vem com energia'
                                    : 'Crie sua conta',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.8),
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Form Card with Glassmorphism
                        ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                            child: Container(
                              padding: const EdgeInsets.all(32.0),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Campo Email
                                  _buildTextField(
                                    controller: _emailController,
                                    label: 'Email',
                                    icon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Digite seu email';
                                      }
                                      if (!value.contains('@')) {
                                        return 'Email inválido';
                                      }
                                      return null;
                                    },
                                  ),

                                  if (!_isLoginMode) ...[
                                    const SizedBox(height: 20),
                                    _buildTextField(
                                      controller: _nomeController,
                                      focusNode: _nomeFocusNode,
                                      label: 'Nome (opcional)',
                                      icon: Icons.person_outline,
                                    ),
                                  ],

                                  const SizedBox(height: 20),

                                  // Campo Senha
                                  _buildTextField(
                                    controller: _passwordController,
                                    focusNode: _passwordFocusNode,
                                    label: 'Senha',
                                    icon: Icons.lock_outline,
                                    obscureText: _obscurePassword,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: Colors.white70,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Digite sua senha';
                                      }
                                      if (!_isLoginMode && value.length < 6) {
                                        return 'Senha deve ter pelo menos 6 caracteres';
                                      }
                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 32),

                                  // Botão de ação (Premium Blue)
                                  ElevatedButton(
                                    onPressed: _isLoading
                                        ? null
                                        : _handleSubmit,
                                    style:
                                        ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AxiaColors.primaryBlue,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 20,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          elevation: 0,
                                        ).copyWith(
                                          backgroundColor:
                                              WidgetStateProperty.resolveWith((
                                                states,
                                              ) {
                                                if (states.contains(
                                                  WidgetState.pressed,
                                                )) {
                                                  return AxiaColors.blue1;
                                                }
                                                return AxiaColors.primaryBlue;
                                              }),
                                        ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                            ),
                                          )
                                        : const Text(
                                            'ENTRAR',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 2.0,
                                            ),
                                          ),
                                  ),

                                  const SizedBox(height: 20),

                                  // Link para alternar
                                  TextButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () {
                                            setState(() {
                                              _isLoginMode = !_isLoginMode;
                                              _passwordController.clear();
                                              _nomeController.clear();
                                            });
                                          },
                                    child: Text(
                                      _isLoginMode
                                          ? 'CRIAR UMA CONTA'
                                          : 'JÁ TENHO UMA CONTA',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),

                                  if (_isLoginMode) ...[
                                    TextButton(
                                      onPressed: _isLoading
                                          ? null
                                          : _handleResetPassword,
                                      child: Text(
                                        'ESQUECEU A SENHA?',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Biometric Option
                        if (_isLoginMode && _showBiometricOption) ...[
                          const SizedBox(height: 24),
                          Center(
                            child: IconButton(
                              icon: const Icon(
                                Icons.fingerprint,
                                color: Colors.white,
                                size: 40,
                              ),
                              onPressed: _isLoading
                                  ? null
                                  : _handleBiometricAuth,
                              tooltip: 'Entrar com Biometria',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    FocusNode? focusNode,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AxiaColors.primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
      validator: validator,
    );
  }
}
