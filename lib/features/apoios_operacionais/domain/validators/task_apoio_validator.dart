import '../enums/task_apoio_enums.dart';
import '../models/task_apoio_solicitacao.dart';
import '../models/task_apoio_vinculo.dart';

/// Validadores de domínio para solicitações e vínculos de apoios operacionais.
/// Nota: validações no Flutter auxiliam UX e integridade local; o backend permanece
/// como autoridade final para permissões e consistência.
class TaskApoioValidator {
  static List<String> validarSolicitacao(TaskApoioSolicitacao s) {
    final erros = <String>[];

    if (s.taskSolicitanteTituloSnapshot.trim().isEmpty) {
      erros.add('Título da atividade solicitante é obrigatório.');
    }
    if (s.regionalSolicitanteId.trim().isEmpty ||
        s.divisaoSolicitanteId.trim().isEmpty) {
      erros.add('Regional e divisão solicitantes são obrigatórias.');
    }
    if (s.regionalDestinoId.trim().isEmpty ||
        s.divisaoDestinoId.trim().isEmpty) {
      erros.add('Regional e divisão de destino são obrigatórias.');
    }
    if (s.tipoApoioId.trim().isEmpty) {
      erros.add('Tipo de apoio é obrigatório.');
    }
    if (s.descricao.trim().isEmpty) {
      erros.add('Descrição da necessidade é obrigatória.');
    }
    if (s.solicitanteUsuarioId.trim().isEmpty) {
      erros.add('Usuário solicitante é obrigatório.');
    }
    if (s.dataFimSolicitada.isBefore(s.dataInicioSolicitada)) {
      erros.add('Data fim solicitada não pode ser anterior à data início.');
    }
    if (s.versao < 1) {
      erros.add('Versão deve ser maior ou igual a 1.');
    }
    if (s.status == TaskApoioStatus.desconhecido) {
      erros.add('Status da solicitação inválido.');
    }
    for (final p in s.periodos) {
      if (!p.isValid) {
        erros.add('Existe período com data fim anterior à data início.');
        break;
      }
    }
    return erros;
  }

  static List<String> validarVinculo(TaskApoioVinculo v) {
    final erros = <String>[];

    if (v.ativo &&
        (v.taskPrincipalId == null ||
            v.taskPrincipalId!.trim().isEmpty ||
            v.taskApoioId == null ||
            v.taskApoioId!.trim().isEmpty)) {
      erros.add(
        'Vínculo ativo exige atividade principal e atividade de apoio.',
      );
    }
    if (v.taskPrincipalId != null &&
        v.taskApoioId != null &&
        v.taskPrincipalId == v.taskApoioId) {
      erros.add('Não é permitido vincular uma atividade a ela mesma.');
    }
    if (v.coberturaInicio != null &&
        v.coberturaFim != null &&
        v.coberturaFim!.isBefore(v.coberturaInicio!)) {
      erros.add('Cobertura fim não pode ser anterior à cobertura início.');
    }
    if (v.createdBy.trim().isEmpty) {
      erros.add('Autor da criação do vínculo é obrigatório.');
    }
    if (v.versao < 1) {
      erros.add('Versão do vínculo deve ser maior ou igual a 1.');
    }
    return erros;
  }

  static bool isMesmaCombinacaoOrganizacional({
    required String regionalId,
    required String divisaoId,
    required Map<String, Set<String>> divisoesPorRegional,
  }) {
    final divisoes = divisoesPorRegional[regionalId];
    if (divisoes == null) return false;
    return divisoes.contains(divisaoId);
  }
}

