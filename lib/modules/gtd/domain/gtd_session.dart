import '../../../services/auth_service_simples.dart';

/// Fonte única do usuário atual para o módulo GTD.
/// Usa o usuário da tabela [usuarios] (AuthServiceSimples), não Supabase Auth.
/// Autorização é feita no Flutter; cada usuário só vê os próprios dados GTD (filtro por user_id).
class GtdSession {
  /// ID do usuário logado (tabela usuarios): preferir id, senão email. Nunca Supabase auth.uid().
  static String? get currentUserId {
    final user = AuthServiceSimples().currentUser;
    if (user == null) return null;
    final id = user.id?.trim();
    if (id != null && id.isNotEmpty) return id;
    final email = user.email.trim();
    if (email.isNotEmpty) return email;
    return null;
  }

  /// Acesso ao GTD apenas para root e jpfilho@axia.com.br.
  static bool get canAccessGtd {
    final user = AuthServiceSimples().currentUser;
    if (user == null) return false;
    if (user.isRoot) return true;
    final email = user.email.trim().toLowerCase();
    return email == 'jpfilho@axia.com.br';
  }
}
