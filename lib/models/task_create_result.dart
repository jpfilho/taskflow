import 'task.dart';

/// Resultado estruturado da criação de uma tarefa no TaskFlow.
/// 
/// Diferencia explicitamente o sucesso da criação da [Task] em relação
/// ao sucesso da vinculação secundária de [tasks_notas_sap].
class TaskCreateResult {
  /// Tarefa persistida no Supabase (com id oficial gerado).
  final Task task;

  /// Indica se o registro da Task foi persistido com sucesso na tabela `tasks`.
  final bool taskCriada;

  /// IDs das notas SAP solicitadas para vínculo na criação.
  final List<String> notasSolicitadas;

  /// IDs das notas SAP que foram vinculadas com sucesso à tarefa em `tasks_notas_sap`.
  final List<String> notasVinculadas;

  /// IDs das notas SAP cuja vinculação falhou ou ficou pendente.
  final List<String> notasComFalha;

  /// Indica se todas as notas solicitadas foram vinculadas com sucesso.
  final bool vinculacaoCompleta;

  /// Erro lançado durante a vinculação das notas, se houver.
  final Object? erroVinculacao;

  const TaskCreateResult({
    required this.task,
    this.taskCriada = true,
    this.notasSolicitadas = const [],
    this.notasVinculadas = const [],
    this.notasComFalha = const [],
    this.vinculacaoCompleta = true,
    this.erroVinculacao,
  });

  /// True se houve falha parcial: task foi criada mas alguma nota falhou ao vincular.
  bool get hasFalhaParcial => taskCriada && !vinculacaoCompleta;

  @override
  String toString() {
    return 'TaskCreateResult(taskId: ${task.id}, criada: $taskCriada, vinculadas: ${notasVinculadas.length}/${notasSolicitadas.length}, falhas: ${notasComFalha.length})';
  }
}

/// Exceção especializada para quando a Task é criada no banco com sucesso,
/// mas a vinculação secundária de Notas SAP falha.
/// 
/// Permite que chamadores que usam try/catch tradicional capturem o erro
/// mas tenham acesso imediato ao [result] e à [result.task] já persistida,
/// impedindo recriação indevida da tarefa.
class TaskCreatedWithVinculoException implements Exception {
  final TaskCreateResult result;
  final String message;

  TaskCreatedWithVinculoException(this.result, [String? message])
      : message = message ??
            'A tarefa "${result.task.tarefa}" foi criada com sucesso, mas ocorreu um erro ao vincular as Notas SAP.';

  @override
  String toString() => 'TaskCreatedWithVinculoException: $message ($result)';
}
