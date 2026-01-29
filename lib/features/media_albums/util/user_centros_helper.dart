import '../../../services/usuario_service.dart';
import '../../../services/centro_trabalho_service.dart';

/// Retorna os nomes dos centros de trabalho permitidos para o usuário
/// (mesma regional, divisão e segmento do perfil).
/// Retorna lista vazia se usuário for null, root ou sem perfil configurado.
Future<List<String>> getUserCentrosTrabalho(Usuario? usuario) async {
  if (usuario == null || usuario.isRoot || !usuario.temPerfilConfigurado()) {
    return [];
  }
  try {
    final todosCentros = await CentroTrabalhoService().getAllCentrosTrabalho();
    final permitidos = todosCentros.where((centro) {
      final okRegional =
          usuario.regionalIds.isEmpty || usuario.regionalIds.contains(centro.regionalId);
      final okDivisao =
          usuario.divisaoIds.isEmpty || usuario.divisaoIds.contains(centro.divisaoId);
      final okSegmento =
          usuario.segmentoIds.isEmpty || usuario.segmentoIds.contains(centro.segmentoId);
      return okRegional && okDivisao && okSegmento;
    }).toList();
    return permitidos.map((c) => c.centroTrabalho.trim()).toList();
  } catch (e) {
    return [];
  }
}
