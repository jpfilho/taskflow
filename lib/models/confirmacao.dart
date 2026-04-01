class Confirmacao {
  final String id;
  final String? ordem;
  final String? operacao2;
  final String? subOper;
  final String? centroDeTrabalho;
  final String? centro;
  final String? nomes;
  final String? nPessoal;
  final double? trabReal;
  final String? unid;
  final DateTime? datInicioExec;
  final String? horaInicio; // TIME as string (HH:mm:ss)
  final DateTime? datFimExec;
  final String? horaFim; // TIME as string (HH:mm:ss)
  final DateTime? dataLancamento;
  final String? textoConfirmacao;
  final String? confirmacaoFinal;
  final String? sTrabRestante;
  final String? tipoAtividade;
  final String? status; // novo campo opcional (status da confirmação)
  final DateTime? dataImportacao;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Confirmacao({
    required this.id,
    this.ordem,
    this.operacao2,
    this.subOper,
    this.centroDeTrabalho,
    this.centro,
    this.nomes,
    this.nPessoal,
    this.trabReal,
    this.unid,
    this.datInicioExec,
    this.horaInicio,
    this.datFimExec,
    this.horaFim,
    this.dataLancamento,
    this.textoConfirmacao,
    this.confirmacaoFinal,
    this.sTrabRestante,
    this.tipoAtividade,
    this.status,
    this.dataImportacao,
    this.createdAt,
    this.updatedAt,
  });

  // Converter de Map (do Supabase)
  factory Confirmacao.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) {
        try {
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

    String? normalizeString(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        final trimmed = value.trim();
        return trimmed.isEmpty ? null : trimmed;
      }
      if (value is int || value is double) {
        return value.toString().trim();
      }
      return value.toString().trim();
    }

    // Verificar se id existe
    final id = map['id'];
    if (id == null) {
      throw Exception('Confirmacao sem id: $map');
    }

    return Confirmacao(
      id: id is String ? id : id.toString(),
      ordem: normalizeString(map['ordem']),
      operacao2: normalizeString(map['operacao_2']),
      subOper: normalizeString(map['sub_oper']),
      centroDeTrabalho: normalizeString(map['centro_de_trab']),
      centro: normalizeString(map['centro']),
      nomes: normalizeString(map['nomes']),
      nPessoal: normalizeString(map['n_pessoal']),
      trabReal: parseDouble(map['trab_real']),
      unid: normalizeString(map['unid']),
      datInicioExec: parseDate(map['dat_inicio_exec']),
      horaInicio: normalizeString(map['hora_inicio']),
      datFimExec: parseDate(map['dat_fim_exec']),
      horaFim: normalizeString(map['hora_fim']),
      dataLancamento: parseDate(map['data_lancamento']),
      textoConfirmacao: normalizeString(map['texto_confirmacao']),
      confirmacaoFinal: normalizeString(map['confirmacao_final']),
      sTrabRestante: normalizeString(map['s_trab_restante']),
      tipoAtividade: normalizeString(map['tipo_atividade']),
      status: normalizeString(map['status']),
      dataImportacao: parseDate(map['data_importacao']),
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
    );
  }

  // Converter para Map (para enviar ao Supabase)
  Map<String, dynamic> toMap({bool includeId = true}) {
    final map = <String, dynamic>{
      'ordem': ordem,
      'operacao_2': operacao2,
      'sub_oper': subOper,
      'centro_de_trab': centroDeTrabalho,
      'centro': centro,
      'nomes': nomes,
      'n_pessoal': nPessoal,
      'trab_real': trabReal,
      'unid': unid,
      'dat_inicio_exec': datInicioExec != null
          ? '${datInicioExec!.year.toString().padLeft(4, '0')}-${datInicioExec!.month.toString().padLeft(2, '0')}-${datInicioExec!.day.toString().padLeft(2, '0')}'
          : null,
      'hora_inicio': horaInicio,
      'dat_fim_exec': datFimExec != null
          ? '${datFimExec!.year.toString().padLeft(4, '0')}-${datFimExec!.month.toString().padLeft(2, '0')}-${datFimExec!.day.toString().padLeft(2, '0')}'
          : null,
      'hora_fim': horaFim,
      'data_lancamento': dataLancamento != null
          ? '${dataLancamento!.year.toString().padLeft(4, '0')}-${dataLancamento!.month.toString().padLeft(2, '0')}-${dataLancamento!.day.toString().padLeft(2, '0')}'
          : null,
      'texto_confirmacao': textoConfirmacao,
      'confirmacao_final': confirmacaoFinal,
      's_trab_restante': sTrabRestante,
      'tipo_atividade': tipoAtividade,
      'status': status,
    };

    if (includeId) {
      map['id'] = id;
    }

    return map;
  }

  Confirmacao copyWith({
    String? id,
    String? ordem,
    String? operacao2,
    String? subOper,
    String? centroDeTrabalho,
    String? centro,
    String? nomes,
    String? nPessoal,
    double? trabReal,
    String? unid,
    DateTime? datInicioExec,
    String? horaInicio,
    DateTime? datFimExec,
    String? horaFim,
    DateTime? dataLancamento,
    String? textoConfirmacao,
    String? confirmacaoFinal,
    String? sTrabRestante,
    String? tipoAtividade,
    String? status,
    DateTime? dataImportacao,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Confirmacao(
      id: id ?? this.id,
      ordem: ordem ?? this.ordem,
      operacao2: operacao2 ?? this.operacao2,
      subOper: subOper ?? this.subOper,
      centroDeTrabalho: centroDeTrabalho ?? this.centroDeTrabalho,
      centro: centro ?? this.centro,
      nomes: nomes ?? this.nomes,
      nPessoal: nPessoal ?? this.nPessoal,
      trabReal: trabReal ?? this.trabReal,
      unid: unid ?? this.unid,
      datInicioExec: datInicioExec ?? this.datInicioExec,
      horaInicio: horaInicio ?? this.horaInicio,
      datFimExec: datFimExec ?? this.datFimExec,
      horaFim: horaFim ?? this.horaFim,
      dataLancamento: dataLancamento ?? this.dataLancamento,
      textoConfirmacao: textoConfirmacao ?? this.textoConfirmacao,
      confirmacaoFinal: confirmacaoFinal ?? this.confirmacaoFinal,
      sTrabRestante: sTrabRestante ?? this.sTrabRestante,
      tipoAtividade: tipoAtividade ?? this.tipoAtividade,
      status: status ?? this.status,
      dataImportacao: dataImportacao ?? this.dataImportacao,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper para formatar data como dd/MM/yyyy
  String formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // Helper para formatar hora como HH:mm
  String formatTime(String? time) {
    if (time == null || time.isEmpty) return '-';
    // Se já está no formato HH:mm:ss, extrair apenas HH:mm
    if (time.contains(':')) {
      final parts = time.split(':');
      if (parts.length >= 2) {
        return '${parts[0]}:${parts[1]}';
      }
    }
    return time;
  }

  // Helper para formatar número com 2 casas decimais
  String formatTrabReal() {
    if (trabReal == null) return '-';
    return trabReal!.toStringAsFixed(2);
  }
}
