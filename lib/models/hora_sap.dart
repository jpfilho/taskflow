class HoraSAP {
  final String id;
  final DateTime? inicioReal;
  final DateTime? dataFimReal;
  final String? tipoOrdem;
  final String? ordem;
  final String? operacao;
  final double? trabalhoReal;
  final String? tipoAtividadeReal;
  final String? numeroPessoa;
  final String? nomeEmpregado;
  final String? statusSistema;
  final String? textoConfirmacao;
  final String? confirmacao;
  final String? std;
  final double? trabalhoPlanejado;
  final String? finalizado;
  final String? campoS;
  final String? centroTrabalhoReal;
  final double? trabalhoRestante;
  final String? horaInicioReal; // TIME como string
  final DateTime? dataLancamento;
  final DateTime? dataImportacao;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  HoraSAP({
    required this.id,
    this.inicioReal,
    this.dataFimReal,
    this.tipoOrdem,
    this.ordem,
    this.operacao,
    this.trabalhoReal,
    this.tipoAtividadeReal,
    this.numeroPessoa,
    this.nomeEmpregado,
    this.statusSistema,
    this.textoConfirmacao,
    this.confirmacao,
    this.std,
    this.trabalhoPlanejado,
    this.finalizado,
    this.campoS,
    this.centroTrabalhoReal,
    this.trabalhoRestante,
    this.horaInicioReal,
    this.dataLancamento,
    this.dataImportacao,
    this.createdAt,
    this.updatedAt,
  });

  // Converter de Map (do Supabase)
  factory HoraSAP.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) {
        try {
          if (value.contains('T')) {
            return DateTime.parse(value);
          }
          if (value.contains('.')) {
            final parts = value.split('.');
            if (parts.length == 3) {
              return DateTime(
                int.parse(parts[2]),
                int.parse(parts[1]),
                int.parse(parts[0]),
              );
            }
          }
          return DateTime.parse(value);
        } catch (e) {
          print('⚠️ Erro ao parsear data: $value - $e');
          return null;
        }
      }
      return null;
    }

    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        try {
          return double.parse(value);
        } catch (e) {
          return null;
        }
      }
      return null;
    }

    String? _normalizeString(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        final trimmed = value.trim();
        return trimmed.isEmpty ? null : trimmed;
      }
      // Converter número para string
      if (value is int || value is double) {
        return value.toString().trim();
      }
      return value.toString().trim();
    }

    // Verificar se id existe
    final id = map['id'];
    if (id == null) {
      throw Exception('HoraSAP sem id: $map');
    }

    return HoraSAP(
      id: id is String ? id : id.toString(),
      inicioReal: parseDate(map['inicio_real']),
      dataFimReal: parseDate(map['data_fim_real']),
      tipoOrdem: _normalizeString(map['tipo_ordem']),
      ordem: _normalizeString(map['ordem']),
      operacao: _normalizeString(map['operacao']),
      trabalhoReal: parseDouble(map['trabalho_real']),
      tipoAtividadeReal: _normalizeString(map['tipo_atividade_real']),
      numeroPessoa: _normalizeString(map['numero_pessoa']),
      nomeEmpregado: _normalizeString(map['nome_empregado']),
      statusSistema: _normalizeString(map['status_sistema']),
      textoConfirmacao: _normalizeString(map['texto_confirmacao']),
      confirmacao: _normalizeString(map['confirmacao']),
      std: _normalizeString(map['std']),
      trabalhoPlanejado: parseDouble(map['trabalho_planejado']),
      finalizado: _normalizeString(map['finalizado']),
      campoS: _normalizeString(map['campo_s']),
      centroTrabalhoReal: _normalizeString(map['centro_trabalho_real']),
      trabalhoRestante: parseDouble(map['trabalho_restante']),
      horaInicioReal: _normalizeString(map['hora_inicio_real']),
      dataLancamento: parseDate(map['data_lancamento']),
      dataImportacao: parseDate(map['data_importacao']),
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
    );
  }

  // Converter para Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'inicio_real': inicioReal?.toIso8601String(),
      'data_fim_real': dataFimReal?.toIso8601String(),
      'tipo_ordem': tipoOrdem,
      'ordem': ordem,
      'operacao': operacao,
      'trabalho_real': trabalhoReal,
      'tipo_atividade_real': tipoAtividadeReal,
      'numero_pessoa': numeroPessoa,
      'nome_empregado': nomeEmpregado,
      'status_sistema': statusSistema,
      'texto_confirmacao': textoConfirmacao,
      'confirmacao': confirmacao,
      'std': std,
      'trabalho_planejado': trabalhoPlanejado,
      'finalizado': finalizado,
      'campo_s': campoS,
      'centro_trabalho_real': centroTrabalhoReal,
      'trabalho_restante': trabalhoRestante,
      'hora_inicio_real': horaInicioReal,
      'data_lancamento': dataLancamento?.toIso8601String(),
      'data_importacao': dataImportacao?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  HoraSAP copyWith({
    String? id,
    DateTime? inicioReal,
    DateTime? dataFimReal,
    String? tipoOrdem,
    String? ordem,
    String? operacao,
    double? trabalhoReal,
    String? tipoAtividadeReal,
    String? numeroPessoa,
    String? nomeEmpregado,
    String? statusSistema,
    String? textoConfirmacao,
    String? confirmacao,
    String? std,
    double? trabalhoPlanejado,
    String? finalizado,
    String? campoS,
    String? centroTrabalhoReal,
    double? trabalhoRestante,
    String? horaInicioReal,
    DateTime? dataLancamento,
    DateTime? dataImportacao,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HoraSAP(
      id: id ?? this.id,
      inicioReal: inicioReal ?? this.inicioReal,
      dataFimReal: dataFimReal ?? this.dataFimReal,
      tipoOrdem: tipoOrdem ?? this.tipoOrdem,
      ordem: ordem ?? this.ordem,
      operacao: operacao ?? this.operacao,
      trabalhoReal: trabalhoReal ?? this.trabalhoReal,
      tipoAtividadeReal: tipoAtividadeReal ?? this.tipoAtividadeReal,
      numeroPessoa: numeroPessoa ?? this.numeroPessoa,
      nomeEmpregado: nomeEmpregado ?? this.nomeEmpregado,
      statusSistema: statusSistema ?? this.statusSistema,
      textoConfirmacao: textoConfirmacao ?? this.textoConfirmacao,
      confirmacao: confirmacao ?? this.confirmacao,
      std: std ?? this.std,
      trabalhoPlanejado: trabalhoPlanejado ?? this.trabalhoPlanejado,
      finalizado: finalizado ?? this.finalizado,
      campoS: campoS ?? this.campoS,
      centroTrabalhoReal: centroTrabalhoReal ?? this.centroTrabalhoReal,
      trabalhoRestante: trabalhoRestante ?? this.trabalhoRestante,
      horaInicioReal: horaInicioReal ?? this.horaInicioReal,
      dataLancamento: dataLancamento ?? this.dataLancamento,
      dataImportacao: dataImportacao ?? this.dataImportacao,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
