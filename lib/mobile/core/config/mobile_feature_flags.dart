
/// Configurações e Feature Flags do TaskFlow Mobile.
/// Permite rollout controlado e ativação segura da nova experiência mobile.
abstract class TFMobileFeatureFlags {
  /// Controla a ativação do novo Mobile Shell V2.
  /// Por padrão, ativo em ambiente de desenvolvimento (kDebugMode) e desativado em release.
  /// Pode ser forçado programaticamente para testes em iPhone físico.
  /// Desativado para manter a experiência oficial unificada do TaskFlow com o Desktop.
  static bool enableMobileShellV2 = false;

  /// Permite alternar o status manualmente para testes controlados.
  static void setMobileShellV2Enabled(bool enabled) {
    enableMobileShellV2 = enabled;
  }
}
