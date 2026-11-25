import '../enums/task_apoio_enums.dart';

/// Ações de negócio possíveis sobre uma solicitação de apoio.
enum TaskApoioAcao {
  encaminharAnalise('Encaminhar para análise', false, false),
  aceitar('Aceitar solicitação', false, true),
  recusar('Recusar solicitação', true, true),
  enviarContraproposta('Apresentar contraproposta', true, true),
  aceitarContraproposta('Aceitar contraproposta', false, true),
  recusarContraproposta('Recusar contraproposta', true, true),
  cancelar('Cancelar solicitação', true, true),
  solicitarReconfirmacao('Solicitar reconfirmação', true, true);

  final String label;
  final bool exigeJustificativa;
  final bool exigeConfirmacaoServidor;
  const TaskApoioAcao(
    this.label,
    this.exigeJustificativa,
    this.exigeConfirmacaoServidor,
  );
}

/// Máquina de estados oficial da solicitação de apoio, alinhada 1:1 com
/// `fn_before_solicitacao_apoio()` no PostgreSQL.
class TaskApoioStateMachine {
  static const Map<TaskApoioStatus, Set<TaskApoioStatus>> transicoesPermitidas =
      {
    TaskApoioStatus.pendente: {
      TaskApoioStatus.emAnalise,
      TaskApoioStatus.contraproposta,
      TaskApoioStatus.aceita,
      TaskApoioStatus.recusada,
      TaskApoioStatus.cancelada,
    },
    TaskApoioStatus.emAnalise: {
      TaskApoioStatus.contraproposta,
      TaskApoioStatus.aceita,
      TaskApoioStatus.recusada,
      TaskApoioStatus.cancelada,
    },
    TaskApoioStatus.contraproposta: {
      TaskApoioStatus.aceita,
      TaskApoioStatus.recusada,
      TaskApoioStatus.cancelada,
      TaskApoioStatus.emAnalise,
    },
    TaskApoioStatus.aceita: {
      TaskApoioStatus.cancelada,
      TaskApoioStatus.emAnalise, // reconfirmação
    },
    TaskApoioStatus.recusada: {},
    TaskApoioStatus.cancelada: {},
    TaskApoioStatus.desconhecido: {},
  };

  static bool podeTransicionar(
    TaskApoioStatus atual,
    TaskApoioStatus destino,
  ) {
    if (atual == destino) return true;
    return transicoesPermitidas[atual]?.contains(destino) ?? false;
  }

  static List<TaskApoioAcao> acoesDisponiveis({
    required TaskApoioStatus statusAtual,
    required TaskApoioPapelAtor papel,
  }) {
    switch (statusAtual) {
      case TaskApoioStatus.pendente:
        return papel == TaskApoioPapelAtor.solicitante
            ? const [TaskApoioAcao.cancelar]
            : const [
                TaskApoioAcao.encaminharAnalise,
                TaskApoioAcao.aceitar,
                TaskApoioAcao.enviarContraproposta,
                TaskApoioAcao.recusar,
              ];
      case TaskApoioStatus.emAnalise:
        return papel == TaskApoioPapelAtor.solicitante
            ? const [TaskApoioAcao.cancelar]
            : const [
                TaskApoioAcao.aceitar,
                TaskApoioAcao.enviarContraproposta,
                TaskApoioAcao.recusar,
              ];
      case TaskApoioStatus.contraproposta:
        return papel == TaskApoioPapelAtor.solicitante
            ? const [
                TaskApoioAcao.aceitarContraproposta,
                TaskApoioAcao.recusarContraproposta,
                TaskApoioAcao.cancelar,
              ]
            : const [
                TaskApoioAcao.encaminharAnalise,
              ];
      case TaskApoioStatus.aceita:
        return papel == TaskApoioPapelAtor.solicitante
            ? const [
                TaskApoioAcao.solicitarReconfirmacao,
                TaskApoioAcao.cancelar,
              ]
            : const [
                TaskApoioAcao.solicitarReconfirmacao,
              ];
      case TaskApoioStatus.recusada:
      case TaskApoioStatus.cancelada:
      case TaskApoioStatus.desconhecido:
        return const [];
    }
  }

  static TaskApoioStatus statusDestinoParaAcao(TaskApoioAcao acao) {
    switch (acao) {
      case TaskApoioAcao.encaminharAnalise:
      case TaskApoioAcao.solicitarReconfirmacao:
        return TaskApoioStatus.emAnalise;
      case TaskApoioAcao.aceitar:
      case TaskApoioAcao.aceitarContraproposta:
        return TaskApoioStatus.aceita;
      case TaskApoioAcao.recusar:
      case TaskApoioAcao.recusarContraproposta:
        return TaskApoioStatus.recusada;
      case TaskApoioAcao.enviarContraproposta:
        return TaskApoioStatus.contraproposta;
      case TaskApoioAcao.cancelar:
        return TaskApoioStatus.cancelada;
    }
  }

  static void validarTransicao({
    required TaskApoioStatus atual,
    required TaskApoioStatus destino,
    String? justificativa,
    DateTime? contrapropostaInicio,
    DateTime? contrapropostaFim,
  }) {
    if (!podeTransicionar(atual, destino)) {
      throw StateError(
        'Transição de status inválida: ${atual.dbValue} -> ${destino.dbValue}.',
      );
    }

    if (destino == TaskApoioStatus.recusada &&
        (justificativa == null || justificativa.trim().isEmpty)) {
      throw ArgumentError(
        'Justificativa é obrigatória ao recusar uma solicitação.',
      );
    }

    if (destino == TaskApoioStatus.cancelada &&
        (justificativa == null || justificativa.trim().isEmpty)) {
      throw ArgumentError('Motivo do cancelamento é obrigatório.');
    }

    if (destino == TaskApoioStatus.contraproposta) {
      if (contrapropostaInicio == null || contrapropostaFim == null) {
        throw ArgumentError(
          'Contraproposta exige período proposto (início e fim).',
        );
      }
      if (contrapropostaFim.isBefore(contrapropostaInicio)) {
        throw ArgumentError(
          'Data fim da contraproposta não pode ser anterior à data início.',
        );
      }
      if (justificativa == null || justificativa.trim().isEmpty) {
        throw ArgumentError('Contraproposta exige justificativa.');
      }
    }
  }
}

