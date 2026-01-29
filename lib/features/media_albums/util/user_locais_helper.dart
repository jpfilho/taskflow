import '../../../services/usuario_service.dart';
import '../../../services/local_service.dart';
import '../../../models/local.dart';

/// Retorna os LOCAIS (tabela locais) permitidos para o usuário (regional, divisão, segmento).
/// Use para exibir as opções da coluna "local" (locais.local) no dropdown.
Future<List<Local>> getLocaisForUsuario(Usuario? usuario) async {
  if (usuario == null || usuario.isRoot || !usuario.temPerfilConfigurado()) {
    return [];
  }
  try {
    final todosLocais = await LocalService().getAllLocais();
    final permitidos = <Local>[];

    for (final local in todosLocais) {
      bool deveIncluir = false;

      if (local.paraTodaRegional && local.regionalId != null) {
        if (usuario.regionalIds.contains(local.regionalId)) deveIncluir = true;
      }
      if (!deveIncluir && local.paraTodaDivisao && local.divisaoId != null) {
        if (usuario.divisaoIds.contains(local.divisaoId)) deveIncluir = true;
      }
      if (!deveIncluir && local.segmentoId != null && local.segmentoId!.isNotEmpty) {
        if (usuario.segmentoIds.contains(local.segmentoId)) deveIncluir = true;
      }
      if (!deveIncluir && local.divisaoId != null && local.divisaoId!.isNotEmpty) {
        if (usuario.divisaoIds.contains(local.divisaoId)) deveIncluir = true;
      }
      if (!deveIncluir && local.regionalId != null && local.regionalId!.isNotEmpty) {
        if (usuario.regionalIds.contains(local.regionalId)) deveIncluir = true;
      }

      if (deveIncluir) permitidos.add(local);
    }

    return permitidos;
  } catch (e) {
    return [];
  }
}

/// Retorna os valores de local_instalacao_sap dos locais do usuário.
/// Usado para filtrar equipamentos_sap: equipamentos_sap.local_instalacao deve
/// corresponder a um desses valores (locais.local_instalacao_sap).
Future<List<String>> getLocaisNomesForUsuario(Usuario? usuario) async {
  final locais = await getLocaisForUsuario(usuario);
  final sap = <String>{};
  for (final local in locais) {
    if (local.localInstalacaoSap != null && local.localInstalacaoSap!.trim().isNotEmpty) {
      sap.add(local.localInstalacaoSap!.trim());
    }
  }
  return sap.toList();
}
