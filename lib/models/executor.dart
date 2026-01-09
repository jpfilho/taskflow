class Executor {
  final String id;
  final String nome;
  final String? nomeCompleto;
  final String? matricula;
  final String? login;
  final String? ramal;
  final String? telefone;
  final String? empresaId; // ID da empresa (opcional)
  final String? empresa; // Nome da empresa (carregado via join)
  final String? funcaoId; // ID da função (opcional)
  final String? funcao; // Nome da função (carregado via join)
  final String? divisaoId; // ID da divisão (opcional)
  final String? divisao; // Nome da divisão (carregado via join)
  final List<String> segmentoIds; // IDs dos segmentos (many-to-many)
  final List<String> segmentos; // Nomes dos segmentos (carregado via join)
  final bool ativo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Executor({
    required this.id,
    required this.nome,
    this.nomeCompleto,
    this.matricula,
    this.login,
    this.ramal,
    this.telefone,
    this.empresaId,
    this.empresa,
    this.funcaoId,
    this.funcao,
    this.divisaoId,
    this.divisao,
    this.segmentoIds = const [],
    this.segmentos = const [],
    this.ativo = true,
    this.createdAt,
    this.updatedAt,
  });

  // Método para criar cópia com alterações
  Executor copyWith({
    String? id,
    String? nome,
    String? nomeCompleto,
    String? matricula,
    String? login,
    String? ramal,
    String? telefone,
    String? empresaId,
    String? empresa,
    String? funcaoId,
    String? funcao,
    String? divisaoId,
    String? divisao,
    List<String>? segmentoIds,
    List<String>? segmentos,
    bool? ativo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Executor(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      nomeCompleto: nomeCompleto ?? this.nomeCompleto,
      matricula: matricula ?? this.matricula,
      login: login ?? this.login,
      ramal: ramal ?? this.ramal,
      telefone: telefone ?? this.telefone,
      empresaId: empresaId ?? this.empresaId,
      empresa: empresa ?? this.empresa,
      funcaoId: funcaoId ?? this.funcaoId,
      funcao: funcao ?? this.funcao,
      divisaoId: divisaoId ?? this.divisaoId,
      divisao: divisao ?? this.divisao,
      segmentoIds: segmentoIds ?? this.segmentoIds,
      segmentos: segmentos ?? this.segmentos,
      ativo: ativo ?? this.ativo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Converter para Map (para Supabase)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'nome_completo': nomeCompleto,
      'matricula': matricula,
      'login': login,
      'ramal': ramal,
      'telefone': telefone,
      'empresa_id': empresaId,
      'funcao_id': funcaoId,
      'divisao_id': divisaoId,
      'ativo': ativo,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  // Criar a partir de Map (do Supabase)
  factory Executor.fromMap(Map<String, dynamic> map) {
    // Extrair nome da empresa do join
    String? empresaNome;
    if (map['empresas'] != null) {
      final empresasMap = map['empresas'];
      if (empresasMap is Map<String, dynamic>) {
        empresaNome = empresasMap['empresa'] as String?;
      }
    }

    // Extrair nome da função do join
    String? funcaoNome;
    if (map['funcoes'] != null) {
      final funcoesMap = map['funcoes'];
      if (funcoesMap is Map<String, dynamic>) {
        funcaoNome = funcoesMap['funcao'] as String?;
      }
    }

    // Extrair nome da divisão do join
    String? divisaoNome;
    if (map['divisoes'] != null) {
      final divisoesMap = map['divisoes'];
      if (divisoesMap is Map<String, dynamic>) {
        divisaoNome = divisoesMap['divisao'] as String?;
      }
    }

    // Extrair lista de segmentos do join many-to-many
    List<String> segmentoIdsList = [];
    List<String> segmentosNomesList = [];
    
    if (map['executores_segmentos'] != null) {
      final segmentosData = map['executores_segmentos'];
      
      if (segmentosData is List) {
        for (var item in segmentosData) {
          if (item is Map<String, dynamic> && item['segmentos'] != null) {
            final segmentoData = item['segmentos'];
            if (segmentoData is Map<String, dynamic>) {
              final segmentoId = segmentoData['id'] as String?;
              final segmentoNome = segmentoData['segmento'] as String?;
              if (segmentoId != null) {
                segmentoIdsList.add(segmentoId);
                if (segmentoNome != null) {
                  segmentosNomesList.add(segmentoNome);
                }
              }
            }
          }
        }
      } else if (segmentosData is Map<String, dynamic>) {
        // Caso seja um único objeto ao invés de lista
        if (segmentosData['segmentos'] != null) {
          final segmentoData = segmentosData['segmentos'];
          if (segmentoData is Map<String, dynamic>) {
            final segmentoId = segmentoData['id'] as String?;
            final segmentoNome = segmentoData['segmento'] as String?;
            if (segmentoId != null) {
              segmentoIdsList.add(segmentoId);
              if (segmentoNome != null) {
                segmentosNomesList.add(segmentoNome);
              }
            }
          }
        }
      }
    }
    
    // Fallback: se não houver executores_segmentos, tentar segmento_id antigo
    if (segmentoIdsList.isEmpty && map['segmento_id'] != null) {
      final segmentoId = map['segmento_id'] as String?;
      if (segmentoId != null) {
        segmentoIdsList.add(segmentoId);
      }
    }

    return Executor(
      id: map['id'] as String,
      nome: map['nome'] as String,
      nomeCompleto: map['nome_completo'] as String?,
      matricula: map['matricula'] as String?,
      login: map['login'] as String?,
      ramal: map['ramal'] as String?,
      telefone: map['telefone'] as String?,
      empresaId: map['empresa_id'] as String?,
      empresa: empresaNome,
      funcaoId: map['funcao_id'] as String?,
      funcao: funcaoNome,
      divisaoId: map['divisao_id'] as String?,
      divisao: divisaoNome,
      segmentoIds: segmentoIdsList,
      segmentos: segmentosNomesList,
      ativo: map['ativo'] as bool? ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  @override
  String toString() {
    return 'Executor(id: $id, nome: $nome, matricula: $matricula, empresa: $empresa, funcao: $funcao)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Executor && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

