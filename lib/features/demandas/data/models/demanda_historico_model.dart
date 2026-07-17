class DemandaHistorico {
  final String id;
  final String demandaId;
  final String? campo;
  final String? valorAnterior;
  final String? valorNovo;
  final String? observacao;
  final String? createdBy;
  final DateTime? createdAt;

  DemandaHistorico({
    required this.id,
    required this.demandaId,
    this.campo,
    this.valorAnterior,
    this.valorNovo,
    this.observacao,
    this.createdBy,
    this.createdAt,
  });

  factory DemandaHistorico.fromMap(Map<String, dynamic> map) {
    return DemandaHistorico(
      id: map['id'] as String,
      demandaId: map['demanda_id'] as String,
      campo: map['campo'] as String?,
      valorAnterior: map['valor_anterior'] as String?,
      valorNovo: map['valor_novo'] as String?,
      observacao: map['observacao'] as String?,
      createdBy: map['created_by'] as String?,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'demanda_id': demandaId,
      'campo': campo,
      'valor_anterior': valorAnterior,
      'valor_novo': valorNovo,
      'observacao': observacao,
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    if (createdBy != null) {
      map['created_by'] = createdBy;
    }
    return map;
  }
}
