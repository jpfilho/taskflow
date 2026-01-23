import 'package:js/js.dart';


/// Interop mínimo com a função global window.msalLogin (definida em web/index.html).
/// Ela devolve uma Promise JS com { email, idToken, accessToken } ou lança erro.
@JS('msalLogin')
external Object _msalLogin();

/// Serviço para login Microsoft/Entra ID no Flutter Web (usa MSAL JS via interop).
class AzureAuthServiceWeb {
  Future<AzureWebLoginResult> signInInteractive() async {
    try {
      final promise = _msalLogin();
      final dynamic result = await _promiseToFuture(promise);
      if (result == null || result is! Map) {
        throw Exception('Retorno inválido do MSAL JS');
      }
      final email = result['email']?.toString();
      final idToken = result['idToken']?.toString();
      final accessToken = result['accessToken']?.toString();
      if (email == null || email.isEmpty) {
        throw Exception('Não foi possível obter o email do Microsoft');
      }
      return AzureWebLoginResult(
        sucesso: true,
        email: email,
        idToken: idToken,
        accessToken: accessToken,
      );
    } catch (e) {
      return AzureWebLoginResult(sucesso: false, erro: e.toString());
    }
  }

  /// Converte uma Promise JS em Future Dart.
  Future<dynamic> _promiseToFuture(Object jsPromise) =>
      Future.microtask(() => jsPromise as dynamic);
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
