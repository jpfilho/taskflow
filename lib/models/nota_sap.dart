import 'dart:convert' show latin1, utf8;

class NotaSAP {
  final String id;
  final String? tipo; // NM, NP, etc.
  final DateTime? criadoEm;
  final String? textPrioridade; // Por oportunidade, Alta, Média, Baixa, Monitoramento
  final String nota; // Número da nota (chave única)
  final String? ordem;
  final String? descricao;
  final String? localInstalacao;
  final String? sala;
  final String? statusSistema; // MSPN, MSPR, MSPR ORDA, etc.
  final DateTime? inicioDesejado;
  final DateTime? conclusaoDesejada;
  final String? horaCriacao; // TIME como string
  final String? statusUsuario; // REGI, ANLS, etc.
  final String? equipamento;
  final DateTime? data;
  final String? notificacao;
  final String? centroTrabalhoResponsavel; // CenTrabRes
  final String? centro; // Cen.
  final DateTime? fimAvaria;
  final String? de;
  final DateTime? encerramento;
  final String? denominacaoExecutor;
  final DateTime? dataReferencia;
  final String? gpm;
  final DateTime? inicioAvaria;
  final DateTime? modificadoEm;
  final String? campoOrdenacao; // Cpo.orden.
  final DateTime? dataImportacao;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  NotaSAP({
    required this.id,
    this.tipo,
    this.criadoEm,
    this.textPrioridade,
    required this.nota,
    this.ordem,
    this.descricao,
    this.localInstalacao,
    this.sala,
    this.statusSistema,
    this.inicioDesejado,
    this.conclusaoDesejada,
    this.horaCriacao,
    this.statusUsuario,
    this.equipamento,
    this.data,
    this.notificacao,
    this.centroTrabalhoResponsavel,
    this.centro,
    this.fimAvaria,
    this.de,
    this.encerramento,
    this.denominacaoExecutor,
    this.dataReferencia,
    this.gpm,
    this.inicioAvaria,
    this.modificadoEm,
    this.campoOrdenacao,
    this.dataImportacao,
    this.createdAt,
    this.updatedAt,
  });

  // Função auxiliar para normalizar strings com problemas de encoding
  // Tenta corrigir caracteres que foram corrompidos durante a importação
  static String? _normalizeString(String? value) {
    if (value == null || value.isEmpty) return value;
    
    // Mapeamento de caracteres corrompidos comuns para seus valores corretos
    // Estes são caracteres que aparecem quando Latin-1 é lido como UTF-8
    final Map<String, String> replacements = {
      'TENSO': 'TENSÃO',
      'PASSARO': 'PÁSSARO',
      'opera': 'operação',
      'operacao': 'operação',
      'Med': 'Méd',
      'Media': 'Média',
      'MEDIA': 'MÉDIA',
      'MED': 'MÉD',
      // Adicionar mais conforme necessário
    };
    
    String result = value;
    
    // Aplicar substituições
    replacements.forEach((wrong, correct) {
      result = result.replaceAll(wrong, correct);
    });
    
    // Se a string contém caracteres de substituição (), tentar decodificar novamente
    if (result.contains('')) {
      try {
        // Tentar converter assumindo que foi salvo como Latin-1 mas lido como UTF-8
        final bytes = latin1.encode(result);
        final decoded = utf8.decode(bytes, allowMalformed: true);
        if (!decoded.contains('')) {
          return decoded;
        }
      } catch (e) {
        // Se falhar, continuar com o resultado das substituições
      }
    }
    
    return result;
  }

  // Converter de Map (do Supabase)
  factory NotaSAP.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) {
        try {
          // Tentar formatos comuns
          if (value.contains('T')) {
            return DateTime.parse(value);
          }
          // Formato DD.MM.YYYY
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

    return NotaSAP(
      id: map['id'] as String,
      tipo: _normalizeString(map['tipo'] as String?),
      criadoEm: parseDate(map['criado_em']),
      textPrioridade: _normalizeString(map['text_prioridade'] as String?),
      nota: _normalizeString(map['nota'] as String) ?? '',
      ordem: _normalizeString(map['ordem'] as String?),
      descricao: _normalizeString(map['descricao'] as String?),
      localInstalacao: _normalizeString(map['local_instalacao'] as String?),
      sala: _normalizeString(map['sala'] as String?),
      statusSistema: _normalizeString(map['status_sistema'] as String?),
      inicioDesejado: parseDate(map['inicio_desejado']),
      conclusaoDesejada: parseDate(map['conclusao_desejada']),
      horaCriacao: _normalizeString(map['hora_criacao'] as String?),
      statusUsuario: _normalizeString(map['status_usuario'] as String?),
      equipamento: _normalizeString(map['equipamento'] as String?),
      data: parseDate(map['data']),
      notificacao: _normalizeString(map['notificacao'] as String?),
      centroTrabalhoResponsavel: _normalizeString(map['centro_trabalho_responsavel'] as String?),
      centro: _normalizeString(map['centro'] as String?),
      fimAvaria: parseDate(map['fim_avaria']),
      de: _normalizeString(map['de'] as String?),
      encerramento: parseDate(map['encerramento']),
      denominacaoExecutor: _normalizeString(map['denominacao_executor'] as String?),
      dataReferencia: parseDate(map['data_referencia']),
      gpm: _normalizeString(map['gpm'] as String?),
      inicioAvaria: parseDate(map['inicio_avaria']),
      modificadoEm: parseDate(map['modificado_em']),
      campoOrdenacao: _normalizeString(map['campo_ordenacao'] as String?),
      dataImportacao: parseDate(map['data_importacao']),
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
    );
  }

  // Função auxiliar para garantir que strings estão em UTF-8 válido
  static String? _ensureUtf8(String? value) {
    if (value == null || value.isEmpty) return value;
    
    // Verificar se contém caracteres de substituição
    if (value.contains('')) {
      // Tentar corrigir assumindo que foi lido incorretamente
      try {
        final bytes = latin1.encode(value);
        final corrected = utf8.decode(bytes, allowMalformed: true);
        if (!corrected.contains('')) {
          return corrected;
        }
      } catch (e) {
        // Se falhar, retornar original
      }
    }
    
    // Verificar se a string é UTF-8 válida
    try {
      utf8.decode(utf8.encode(value));
      return value;
    } catch (e) {
      // Se não for UTF-8 válido, tentar corrigir
      try {
        final bytes = latin1.encode(value);
        return utf8.decode(bytes, allowMalformed: true);
      } catch (e2) {
        return value; // Retornar original se tudo falhar
      }
    }
  }

  // Converter para Map (para Supabase)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tipo': _ensureUtf8(tipo),
      'criado_em': criadoEm?.toIso8601String(),
      'text_prioridade': _ensureUtf8(textPrioridade),
      'nota': _ensureUtf8(nota) ?? '',
      'ordem': _ensureUtf8(ordem),
      'descricao': _ensureUtf8(descricao),
      'local_instalacao': _ensureUtf8(localInstalacao),
      'sala': _ensureUtf8(sala),
      'status_sistema': _ensureUtf8(statusSistema),
      'inicio_desejado': inicioDesejado?.toIso8601String(),
      'conclusao_desejada': conclusaoDesejada?.toIso8601String(),
      'hora_criacao': _ensureUtf8(horaCriacao),
      'status_usuario': _ensureUtf8(statusUsuario),
      'equipamento': _ensureUtf8(equipamento),
      'data': data?.toIso8601String(),
      'notificacao': _ensureUtf8(notificacao),
      'centro_trabalho_responsavel': _ensureUtf8(centroTrabalhoResponsavel),
      'centro': _ensureUtf8(centro),
      'fim_avaria': fimAvaria?.toIso8601String(),
      'de': _ensureUtf8(de),
      'encerramento': encerramento?.toIso8601String(),
      'denominacao_executor': _ensureUtf8(denominacaoExecutor),
      'data_referencia': dataReferencia?.toIso8601String(),
      'gpm': _ensureUtf8(gpm),
      'inicio_avaria': inicioAvaria?.toIso8601String(),
      'modificado_em': modificadoEm?.toIso8601String(),
      'campo_ordenacao': _ensureUtf8(campoOrdenacao),
      'data_importacao': dataImportacao?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  NotaSAP copyWith({
    String? id,
    String? tipo,
    DateTime? criadoEm,
    String? textPrioridade,
    String? nota,
    String? ordem,
    String? descricao,
    String? localInstalacao,
    String? sala,
    String? statusSistema,
    DateTime? inicioDesejado,
    DateTime? conclusaoDesejada,
    String? horaCriacao,
    String? statusUsuario,
    String? equipamento,
    DateTime? data,
    String? notificacao,
    String? centroTrabalhoResponsavel,
    String? centro,
    DateTime? fimAvaria,
    String? de,
    DateTime? encerramento,
    String? denominacaoExecutor,
    DateTime? dataReferencia,
    String? gpm,
    DateTime? inicioAvaria,
    DateTime? modificadoEm,
    String? campoOrdenacao,
    DateTime? dataImportacao,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotaSAP(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      criadoEm: criadoEm ?? this.criadoEm,
      textPrioridade: textPrioridade ?? this.textPrioridade,
      nota: nota ?? this.nota,
      ordem: ordem ?? this.ordem,
      descricao: descricao ?? this.descricao,
      localInstalacao: localInstalacao ?? this.localInstalacao,
      sala: sala ?? this.sala,
      statusSistema: statusSistema ?? this.statusSistema,
      inicioDesejado: inicioDesejado ?? this.inicioDesejado,
      conclusaoDesejada: conclusaoDesejada ?? this.conclusaoDesejada,
      horaCriacao: horaCriacao ?? this.horaCriacao,
      statusUsuario: statusUsuario ?? this.statusUsuario,
      equipamento: equipamento ?? this.equipamento,
      data: data ?? this.data,
      notificacao: notificacao ?? this.notificacao,
      centroTrabalhoResponsavel: centroTrabalhoResponsavel ?? this.centroTrabalhoResponsavel,
      centro: centro ?? this.centro,
      fimAvaria: fimAvaria ?? this.fimAvaria,
      de: de ?? this.de,
      encerramento: encerramento ?? this.encerramento,
      denominacaoExecutor: denominacaoExecutor ?? this.denominacaoExecutor,
      dataReferencia: dataReferencia ?? this.dataReferencia,
      gpm: gpm ?? this.gpm,
      inicioAvaria: inicioAvaria ?? this.inicioAvaria,
      modificadoEm: modificadoEm ?? this.modificadoEm,
      campoOrdenacao: campoOrdenacao ?? this.campoOrdenacao,
      dataImportacao: dataImportacao ?? this.dataImportacao,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

