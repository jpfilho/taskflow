class EquipeExecutor {
  final String executorId;
  final String executorNome;
  final String papel; // 'FISCAL', 'TST', 'ENCARREGADO', 'EXECUTOR'

  EquipeExecutor({
    required this.executorId,
    required this.executorNome,
    required this.papel,
  });

  Map<String, dynamic> toMap() {
    return {
      'executor_id': executorId,
      'papel': papel,
    };
  }

  factory EquipeExecutor.fromMap(Map<String, dynamic> map) {
    // Extrair nome do executor do join
    String executorNome = '';
    if (map['executores'] != null) {
      final executoresMap = map['executores'];
      if (executoresMap is Map<String, dynamic>) {
        executorNome = executoresMap['nome'] as String? ?? '';
      }
    }

    return EquipeExecutor(
      executorId: map['executor_id'] as String,
      executorNome: executorNome,
      papel: map['papel'] as String,
    );
  }

  @override
  String toString() {
    return 'EquipeExecutor(executorId: $executorId, executorNome: $executorNome, papel: $papel)';
  }
}







