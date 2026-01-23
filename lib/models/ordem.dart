import 'dart:convert' show latin1, utf8;

class Ordem {
  final String id;
  final String ordem; // Número da ordem (chave única)
  final DateTime? inicioBase;
  final DateTime? fimBase;
  final DateTime? tolerancia; // Data limite/prazo da ordem
  final String? tipo; // PREV, etc.
  final String? statusSistema; // ABER CAPC DMNV ERRD SCDM, etc.
  final String? denominacaoLocalInstalacao; // 04T3.A - Transformador
  final String? denominacaoObjeto; // TRAFO POTENCIA_TRAFO UNIAO S/A-TUSA_ELUN
  final String? textoBreve; // PREV_TR_CDST_04T3_A
  final String? localInstalacao; // H-S-STSD-RB1K01-4TR1-TR01-A
  final String? local; // Local da tabela locais (calculado automaticamente pela VIEW)
  final String? sala; // Sala da instalação (quando disponível)
  final String? statusUsuario; // REGI
  final String? codigoSI; // Código da SI
  final String? gpm; // 210
  final DateTime? dataImportacao;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Ordem({
    required this.id,
    required this.ordem,
    this.inicioBase,
    this.fimBase,
    this.tolerancia,
    this.tipo,
    this.statusSistema,
    this.denominacaoLocalInstalacao,
    this.denominacaoObjeto,
    this.textoBreve,
    this.localInstalacao,
    this.local,
    this.sala,
    this.statusUsuario,
    this.codigoSI,
    this.gpm,
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

  // Converter do Map (Supabase)
  factory Ordem.fromMap(Map<String, dynamic> map) {
    return Ordem(
      id: map['id'] as String,
      ordem: map['ordem'] as String,
      inicioBase: map['inicio_base'] != null
          ? DateTime.parse(map['inicio_base'] as String)
          : null,
      fimBase: map['fim_base'] != null
          ? DateTime.parse(map['fim_base'] as String)
          : null,
      tolerancia: map['tolerancia'] != null
          ? DateTime.parse(map['tolerancia'] as String)
          : null,
      tipo: map['tipo'] as String?,
      statusSistema: map['status_sistema'] as String?,
      denominacaoLocalInstalacao: map['denominacao_local_instalacao'] as String?,
      denominacaoObjeto: map['denominacao_objeto'] as String?,
      textoBreve: map['texto_breve'] as String?,
      localInstalacao: map['local_instalacao'] as String?,
      local: map['local'] as String?, // Local da tabela locais (calculado pela VIEW)
      sala: map['sala'] as String?, // Sala (opcional)
      statusUsuario: map['status_usuario'] as String?,
      codigoSI: map['codigo_si'] as String?,
      gpm: map['gpm'] as String?,
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
    return {
      'id': id,
      'ordem': ordem,
      'inicio_base': inicioBase?.toIso8601String(),
      'fim_base': fimBase?.toIso8601String(),
      'tolerancia': tolerancia?.toIso8601String(),
      'tipo': tipo,
      'status_sistema': statusSistema,
      'denominacao_local_instalacao': denominacaoLocalInstalacao,
      'denominacao_objeto': denominacaoObjeto,
      'texto_breve': textoBreve,
      'local_instalacao': localInstalacao,
      'sala': sala,
      'status_usuario': statusUsuario,
      'codigo_si': codigoSI,
      'gpm': gpm,
      'data_importacao': dataImportacao?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Factory para criar a partir de uma linha CSV parseada
  factory Ordem.fromCSVParts(List<String> partes) {
    if (partes.length < 13) {
      throw Exception('Número insuficiente de colunas no CSV: ${partes.length} (esperado: 13+)');
    }

    // Validar que a ordem não está vazia
    final ordemNumero = _normalizeString(partes[1]);
    if (ordemNumero == null || ordemNumero.isEmpty) {
      throw Exception('Número da ordem não pode estar vazio');
    }

    // Garantir que temos pelo menos um índice válido para cada campo
    final ordem = ordemNumero;
    final inicioBase = partes.length > 2 ? _parseDate(_normalizeString(partes[2])) : null;
    final fimBase = partes.length > 3 ? _parseDate(_normalizeString(partes[3])) : null;
    final tipo = partes.length > 4 ? _normalizeString(partes[4]) : null;
    final statusSistema = partes.length > 5 ? _normalizeString(partes[5]) : null;
    final denominacaoLocalInstalacao = partes.length > 6 ? _normalizeString(partes[6]) : null;
    final denominacaoObjeto = partes.length > 7 ? _normalizeString(partes[7]) : null;
    final textoBreve = partes.length > 8 ? _normalizeString(partes[8]) : null;
    final localInstalacao = partes.length > 9 ? _normalizeString(partes[9]) : null;
    final statusUsuario = partes.length > 10 ? _normalizeString(partes[10]) : null;
    final codigoSI = partes.length > 11 ? _normalizeString(partes[11]) : null;
    final gpm = partes.length > 12 ? _normalizeString(partes[12]) : null;
    // Caso o CSV passe a trazer a coluna tolerancia, assumimos que ela vem como coluna extra
    final tolerancia = partes.length > 13 ? _parseDate(_normalizeString(partes[13])) : null;

    return Ordem(
      id: '', // Será gerado pelo Supabase
      ordem: ordem,
      inicioBase: inicioBase,
      fimBase: fimBase,
      tolerancia: tolerancia,
      tipo: tipo,
      statusSistema: statusSistema,
      denominacaoLocalInstalacao: denominacaoLocalInstalacao,
      denominacaoObjeto: denominacaoObjeto,
      textoBreve: textoBreve,
      localInstalacao: localInstalacao,
      statusUsuario: statusUsuario,
      codigoSI: codigoSI,
      gpm: gpm,
      dataImportacao: DateTime.now(),
    );
  }

  // Cópia com alterações
  Ordem copyWith({
    String? id,
    String? ordem,
    DateTime? inicioBase,
    DateTime? fimBase,
    DateTime? tolerancia,
    String? tipo,
    String? statusSistema,
    String? denominacaoLocalInstalacao,
    String? denominacaoObjeto,
    String? textoBreve,
    String? localInstalacao,
    String? statusUsuario,
    String? codigoSI,
    String? gpm,
    DateTime? dataImportacao,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Ordem(
      id: id ?? this.id,
      ordem: ordem ?? this.ordem,
      inicioBase: inicioBase ?? this.inicioBase,
      fimBase: fimBase ?? this.fimBase,
      tolerancia: tolerancia ?? this.tolerancia,
      tipo: tipo ?? this.tipo,
      statusSistema: statusSistema ?? this.statusSistema,
      denominacaoLocalInstalacao: denominacaoLocalInstalacao ?? this.denominacaoLocalInstalacao,
      denominacaoObjeto: denominacaoObjeto ?? this.denominacaoObjeto,
      textoBreve: textoBreve ?? this.textoBreve,
      localInstalacao: localInstalacao ?? this.localInstalacao,
      statusUsuario: statusUsuario ?? this.statusUsuario,
      codigoSI: codigoSI ?? this.codigoSI,
      gpm: gpm ?? this.gpm,
      dataImportacao: dataImportacao ?? this.dataImportacao,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
