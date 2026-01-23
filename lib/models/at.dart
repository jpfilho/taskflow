import 'dart:convert' show latin1, utf8;

class AT {
  final String id;
  final String autorzTrab; // Número da AT (chave única)
  final String? edificacao; // H-S-SSBD, etc.
  final String? local; // Local calculado pela view ats_com_local
  final String? localInstalacao; // H-S-SSBD-RB4T03, etc.
  final String? textoBreve; // Texto breve da atividade
  final DateTime? dataCriacao; // DtCriação
  final DateTime? dataInicio; // Dt Início
  final String? validoDesde; // Vál.desde (hora)
  final DateTime? dataFim; // Data Fim
  final String? validoAte; // Válido até (hora)
  final String? valido; // Válido
  final String? statusUsuario; // St.usuário (CONC, CRSI, CANC, etc.)
  final String? statusSistema; // Status do sistema (PREP ENCE, CRI., etc.)
  final String? lisObjs; // LisObjs
  final String? atrib1; // Atrib. (primeira coluna)
  final String? atrib2; // Atrib. (segunda coluna)
  final String? cntrTrab; // CntrTrab (MNSE.FTZ, etc.)
  final String? cen; // Cen. (HL8C, etc.)
  final String? si; // SI
  final String? criadoPor; // Criado por
  final String? modifPor; // Modif.por
  final DateTime? dataModifc; // DataModifc
  final String? tpRet; // tp Ret.
  final DateTime? dataImportacao;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AT({
    required this.id,
    required this.autorzTrab,
    this.edificacao,
    this.local,
    this.localInstalacao,
    this.textoBreve,
    this.dataCriacao,
    this.dataInicio,
    this.validoDesde,
    this.dataFim,
    this.validoAte,
    this.valido,
    this.statusUsuario,
    this.statusSistema,
    this.lisObjs,
    this.atrib1,
    this.atrib2,
    this.cntrTrab,
    this.cen,
    this.si,
    this.criadoPor,
    this.modifPor,
    this.dataModifc,
    this.tpRet,
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
    if (trimmed.isEmpty || trimmed == '-') return null;
    return trimmed;
  }

  // Converter do Map (Supabase)
  factory AT.fromMap(Map<String, dynamic> map) {
    return AT(
      id: map['id'] as String,
      autorzTrab: map['autorz_trab'] as String,
      edificacao: map['edificacao'] as String?,
      local: map['local'] as String?,
      localInstalacao: map['local_instalacao'] as String?,
      textoBreve: map['texto_breve'] as String?,
      dataCriacao: map['data_criacao'] != null
          ? DateTime.parse(map['data_criacao'] as String)
          : null,
      dataInicio: map['data_inicio'] != null
          ? DateTime.parse(map['data_inicio'] as String)
          : null,
      validoDesde: map['valido_desde'] as String?,
      dataFim: map['data_fim'] != null
          ? DateTime.parse(map['data_fim'] as String)
          : null,
      validoAte: map['valido_ate'] as String?,
      valido: map['valido'] as String?,
      statusUsuario: map['status_usuario'] as String?,
      statusSistema: map['status_sistema'] as String?,
      lisObjs: map['lis_objs'] as String?,
      atrib1: map['atrib1'] as String?,
      atrib2: map['atrib2'] as String?,
      cntrTrab: map['cntr_trab'] as String?,
      cen: map['cen'] as String?,
      si: map['si'] as String?,
      criadoPor: map['criado_por'] as String?,
      modifPor: map['modif_por'] as String?,
      dataModifc: map['data_modifc'] != null
          ? DateTime.parse(map['data_modifc'] as String)
          : null,
      tpRet: map['tp_ret'] as String?,
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

  // Converter para Map (Supabase)
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'autorz_trab': autorzTrab,
      'edificacao': _normalizeString(edificacao),
      'local_instalacao': _normalizeString(localInstalacao),
      'texto_breve': _normalizeString(textoBreve),
      'data_criacao': dataCriacao?.toIso8601String(),
      'data_inicio': dataInicio?.toIso8601String(),
      'valido_desde': _parseHora(validoDesde),
      'data_fim': dataFim?.toIso8601String(),
      'valido_ate': _parseHora(validoAte),
      'valido': _normalizeString(valido),
      'status_usuario': _normalizeString(statusUsuario),
      'status_sistema': _normalizeString(statusSistema),
      'lis_objs': _normalizeString(lisObjs),
      'atrib1': _normalizeString(atrib1),
      'atrib2': _normalizeString(atrib2),
      'cntr_trab': _normalizeString(cntrTrab),
      'cen': _normalizeString(cen),
      'si': _normalizeString(si),
      'criado_por': _normalizeString(criadoPor),
      'modif_por': _normalizeString(modifPor),
      'data_modifc': dataModifc?.toIso8601String(),
      'tp_ret': _normalizeString(tpRet),
      'data_importacao': DateTime.now().toIso8601String(),
    };

    // Remover campos nulos ou vazios
    map.removeWhere((key, value) => value == null || value == '');
    
    return map;
  }

  // Criar a partir de partes do CSV (parse de linha)
  factory AT.fromCSVParts(List<String> partes) {
    // Validar que temos pelo menos o número da AT (partes[1])
    if (partes.length < 2 || partes[1].trim().isEmpty) {
      throw Exception('Linha CSV inválida: número da AT não encontrado');
    }

    return AT(
      id: '', // Será gerado pelo banco
      autorzTrab: _normalizeString(partes[1]) ?? '',
      edificacao: _normalizeString(partes.length > 2 ? partes[2] : null),
      localInstalacao: _normalizeString(partes.length > 3 ? partes[3] : null),
      textoBreve: _normalizeString(partes.length > 4 ? partes[4] : null),
      dataCriacao: _parseDate(partes.length > 5 ? partes[5] : null),
      dataInicio: _parseDate(partes.length > 6 ? partes[6] : null),
      validoDesde: _parseHora(partes.length > 7 ? partes[7] : null),
      dataFim: _parseDate(partes.length > 8 ? partes[8] : null),
      validoAte: _parseHora(partes.length > 9 ? partes[9] : null),
      valido: _normalizeString(partes.length > 10 ? partes[10] : null),
      statusUsuario: _normalizeString(partes.length > 11 ? partes[11] : null),
      statusSistema: _normalizeString(partes.length > 12 ? partes[12] : null),
      lisObjs: _normalizeString(partes.length > 13 ? partes[13] : null),
      atrib1: _normalizeString(partes.length > 14 ? partes[14] : null),
      atrib2: _normalizeString(partes.length > 15 ? partes[15] : null),
      cntrTrab: _normalizeString(partes.length > 16 ? partes[16] : null),
      cen: _normalizeString(partes.length > 17 ? partes[17] : null),
      si: _normalizeString(partes.length > 18 ? partes[18] : null),
      criadoPor: _normalizeString(partes.length > 19 ? partes[19] : null),
      modifPor: _normalizeString(partes.length > 20 ? partes[20] : null),
      dataModifc: _parseDate(partes.length > 21 ? partes[21] : null),
      tpRet: _normalizeString(partes.length > 22 ? partes[22] : null),
    );
  }
}
