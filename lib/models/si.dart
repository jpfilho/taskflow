import 'dart:convert' show latin1, utf8;

class SI {
  final String id;
  final String solicitacao; // Número da solicitação (chave única) - ex: 00001299/25H
  final String? tipo; // Tp (T5, T1, T7, etc.)
  final String? textoBreve; // Texto breve
  final String? local; // Local calculado pela view sis_com_local
  final DateTime? dataCriacao; // DtCriação
  final String? localInstalacao; // Local de instalação
  final String? criadoPor; // Criado por
  final DateTime? dataInicio; // Dt Início
  final DateTime? dataFim; // Data Fim
  final String? statusUsuario; // St.usuário (CRSI, CONC, CANC, etc.)
  final String? statusSistema; // Status do sistema (CRI., PREP, etc.)
  final String? cntrTrab; // CntrTrab (MNSE.TSA, etc.)
  final String? cen; // Cen. (HF5C, etc.)
  final String? valido; // Válido
  final String? horaInicio; // Hora iníc.
  final String? horaFim; // Hora fim
  final String? atribAT; // Atrib. AT
  final DateTime? dataImportacao;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SI({
    required this.id,
    required this.solicitacao,
    this.tipo,
    this.textoBreve,
    this.local,
    this.dataCriacao,
    this.localInstalacao,
    this.criadoPor,
    this.dataInicio,
    this.dataFim,
    this.statusUsuario,
    this.statusSistema,
    this.cntrTrab,
    this.cen,
    this.valido,
    this.horaInicio,
    this.horaFim,
    this.atribAT,
    this.dataImportacao,
    this.createdAt,
    this.updatedAt,
  });

  // Função auxiliar para normalizar strings com problemas de encoding
  static String? _normalizeString(String? value) {
    if (value == null || value.isEmpty) return value;
    
    String result = value.trim();
    
    // Se a string contém caracteres de substituição, tentar decodificar novamente
    if (result.contains('')) {
      try {
        final bytes = latin1.encode(result);
        result = utf8.decode(bytes, allowMalformed: true);
      } catch (e) {
        // Se falhar, manter o original
      }
    }
    
    return result.isEmpty ? null : result;
  }

  // Parse de data no formato DD.MM.YYYY
  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    
    try {
      final partes = value.trim().split('.');
      if (partes.length == 3) {
        final dia = int.parse(partes[0]);
        final mes = int.parse(partes[1]);
        final ano = int.parse(partes[2]);
        return DateTime(ano, mes, dia);
      }
    } catch (e) {
      print('⚠️ Erro ao parsear data: $value - $e');
    }
    return null;
  }

  // Parse de hora no formato HH:MM:SS
  static String? _parseHora(String? value) {
    if (value == null || value.isEmpty) return null;
    final trimmed = value.trim();
    if (trimmed == '00:00:00') return null; // Ignorar horas padrão
    return trimmed;
  }

  // Criar SI a partir de partes do CSV
  factory SI.fromCSVParts(List<String> valores) {
    // Índices esperados (baseado no cabeçalho):
    // 0: vazio (antes do primeiro |)
    // 1: Solicitação
    // 2: Tp
    // 3: Texto breve
    // 4: DtCriação
    // 5: Local de instalação
    // 6: Criado por
    // 7: Dt Início
    // 8: Data Fim
    // 9: St.usuário
    // 10: Status do sistema
    // 11: CntrTrab
    // 12: Cen.
    // 13: Válido
    // 14: Hora iníc.
    // 15: Hora fim
    // 16: Atrib. AT

    final solicitacao = _normalizeString(valores.length > 1 ? valores[1] : null) ?? '';
    
    return SI(
      id: '', // Será gerado pelo banco
      solicitacao: solicitacao,
      tipo: _normalizeString(valores.length > 2 ? valores[2] : null),
      textoBreve: _normalizeString(valores.length > 3 ? valores[3] : null),
      dataCriacao: _parseDate(valores.length > 4 ? valores[4] : null),
      localInstalacao: _normalizeString(valores.length > 5 ? valores[5] : null),
      criadoPor: _normalizeString(valores.length > 6 ? valores[6] : null),
      dataInicio: _parseDate(valores.length > 7 ? valores[7] : null),
      dataFim: _parseDate(valores.length > 8 ? valores[8] : null),
      statusUsuario: _normalizeString(valores.length > 9 ? valores[9] : null),
      statusSistema: _normalizeString(valores.length > 10 ? valores[10] : null),
      cntrTrab: _normalizeString(valores.length > 11 ? valores[11] : null),
      cen: _normalizeString(valores.length > 12 ? valores[12] : null),
      valido: _normalizeString(valores.length > 13 ? valores[13] : null),
      horaInicio: _parseHora(valores.length > 14 ? valores[14] : null),
      horaFim: _parseHora(valores.length > 15 ? valores[15] : null),
      atribAT: _normalizeString(valores.length > 16 ? valores[16] : null),
      dataImportacao: DateTime.now(),
    );
  }

  // Criar SI a partir de um Map (do Supabase)
  factory SI.fromMap(Map<String, dynamic> map) {
    return SI(
      id: map['id'] as String,
      solicitacao: map['solicitacao'] as String? ?? '',
      tipo: map['tipo'] as String?,
      textoBreve: map['texto_breve'] as String?,
      local: map['local'] as String?,
      dataCriacao: map['data_criacao'] != null 
          ? DateTime.parse(map['data_criacao'] as String)
          : null,
      localInstalacao: map['local_instalacao'] as String?,
      criadoPor: map['criado_por'] as String?,
      dataInicio: map['data_inicio'] != null 
          ? DateTime.parse(map['data_inicio'] as String)
          : null,
      dataFim: map['data_fim'] != null 
          ? DateTime.parse(map['data_fim'] as String)
          : null,
      statusUsuario: map['status_usuario'] as String?,
      statusSistema: map['status_sistema'] as String?,
      cntrTrab: map['cntr_trab'] as String?,
      cen: map['cen'] as String?,
      valido: map['valido'] as String?,
      horaInicio: map['hora_inicio'] as String?,
      horaFim: map['hora_fim'] as String?,
      atribAT: map['atrib_at'] as String?,
      dataImportacao: map['data_importacao'] != null 
          ? DateTime.parse(map['data_importacao'] as String)
          : null,
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  // Converter SI para Map (para Supabase)
  Map<String, dynamic> toMap() {
    return {
      'solicitacao': solicitacao,
      'tipo': tipo,
      'texto_breve': textoBreve,
      'data_criacao': dataCriacao?.toIso8601String(),
      'local_instalacao': localInstalacao,
      'criado_por': criadoPor,
      'data_inicio': dataInicio?.toIso8601String(),
      'data_fim': dataFim?.toIso8601String(),
      'status_usuario': statusUsuario,
      'status_sistema': statusSistema,
      'cntr_trab': cntrTrab,
      'cen': cen,
      'valido': valido,
      'hora_inicio': horaInicio,
      'hora_fim': horaFim,
      'atrib_at': atribAT,
      'data_importacao': dataImportacao?.toIso8601String(),
    };
  }

  SI copyWith({
    String? id,
    String? solicitacao,
    String? tipo,
    String? textoBreve,
    DateTime? dataCriacao,
    String? localInstalacao,
    String? criadoPor,
    DateTime? dataInicio,
    DateTime? dataFim,
    String? statusUsuario,
    String? statusSistema,
    String? cntrTrab,
    String? cen,
    String? valido,
    String? horaInicio,
    String? horaFim,
    String? atribAT,
    DateTime? dataImportacao,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SI(
      id: id ?? this.id,
      solicitacao: solicitacao ?? this.solicitacao,
      tipo: tipo ?? this.tipo,
      textoBreve: textoBreve ?? this.textoBreve,
      dataCriacao: dataCriacao ?? this.dataCriacao,
      localInstalacao: localInstalacao ?? this.localInstalacao,
      criadoPor: criadoPor ?? this.criadoPor,
      dataInicio: dataInicio ?? this.dataInicio,
      dataFim: dataFim ?? this.dataFim,
      statusUsuario: statusUsuario ?? this.statusUsuario,
      statusSistema: statusSistema ?? this.statusSistema,
      cntrTrab: cntrTrab ?? this.cntrTrab,
      cen: cen ?? this.cen,
      valido: valido ?? this.valido,
      horaInicio: horaInicio ?? this.horaInicio,
      horaFim: horaFim ?? this.horaFim,
      atribAT: atribAT ?? this.atribAT,
      dataImportacao: dataImportacao ?? this.dataImportacao,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
