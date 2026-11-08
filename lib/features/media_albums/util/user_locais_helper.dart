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
      // O local deve atender cumulativamente ao perfil: Regional, Divisão e Segmento
      final temRegionalPermitida = usuario.regionalIds.isEmpty ||
          (local.regionalId != null && usuario.regionalIds.contains(local.regionalId));

      final temDivisaoPermitida = usuario.divisaoIds.isEmpty ||
          (local.divisaoId != null && usuario.divisaoIds.contains(local.divisaoId));

      final temSegmentoPermitido = usuario.segmentoIds.isEmpty ||
          (local.segmentoId != null && usuario.segmentoIds.contains(local.segmentoId));

      if (temRegionalPermitida && temDivisaoPermitida && temSegmentoPermitido) {
        permitidos.add(local);
      }
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
