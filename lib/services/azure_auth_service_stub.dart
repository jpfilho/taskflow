/// Stub para plataformas não-web, evitando dependência de `package:js`.
class AzureAuthServiceWeb {
  Future<AzureWebLoginResult> signInInteractive() async =>
      AzureWebLoginResult(
        sucesso: false,
        erro: 'Login Microsoft via Web não suportado nesta plataforma.',
      );
}

class AzureWebLoginResult {
  final bool sucesso;
  final String? email;
  final String? idToken;
  final String? accessToken;
  final String? erro;

  AzureWebLoginResult({
    required this.sucesso,
    this.email,
    this.idToken,
    this.accessToken,
    this.erro,
  });
}
