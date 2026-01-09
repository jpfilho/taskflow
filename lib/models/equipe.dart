import 'equipe_executor.dart';

class Equipe {
  final String id;
  final String nome;
  final String? descricao;
  final String tipo; // 'FIXA' ou 'FLEXIVEL'
  final String? regionalId; // ID da regional (opcional)
  final String? regional; // Nome da regional (carregado via join)
  final String? divisaoId; // ID da divisão (opcional)
  final String? divisao; // Nome da divisão (carregado via join)
  final String? segmentoId; // ID do segmento (opcional)
  final String? segmento; // Nome do segmento (carregado via join)
  final bool ativo;
  final List<EquipeExecutor> executores; // Lista de executores com seus papéis
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Equipe({
    required this.id,
    required this.nome,
    this.descricao,
    required this.tipo,
    this.regionalId,
    this.regional,
    this.divisaoId,
    this.divisao,
    this.segmentoId,
    this.segmento,
    this.ativo = true,
    this.executores = const [],
    this.createdAt,
    this.updatedAt,
  });

  // Método para criar cópia com alterações
  Equipe copyWith({
    String? id,
    String? nome,
    String? descricao,
    String? tipo,
    String? regionalId,
    String? regional,
    String? divisaoId,
    String? divisao,
    String? segmentoId,
    String? segmento,
    bool? ativo,
    List<EquipeExecutor>? executores,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Equipe(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
      tipo: tipo ?? this.tipo,
      regionalId: regionalId ?? this.regionalId,
      regional: regional ?? this.regional,
      divisaoId: divisaoId ?? this.divisaoId,
      divisao: divisao ?? this.divisao,
      segmentoId: segmentoId ?? this.segmentoId,
      segmento: segmento ?? this.segmento,
      ativo: ativo ?? this.ativo,
      executores: executores ?? this.executores,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Converter para Map (para Supabase)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'descricao': descricao,
      'tipo': tipo,
      'regional_id': regionalId,
      'divisao_id': divisaoId,
      'segmento_id': segmentoId,
      'ativo': ativo,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  // Criar a partir de Map (do Supabase)
  factory Equipe.fromMap(Map<String, dynamic> map) {
    // Extrair nome da regional do join
    String? regionalNome;
    if (map['regionais'] != null) {
      final regionaisMap = map['regionais'];
      if (regionaisMap is Map<String, dynamic>) {
        regionalNome = regionaisMap['regional'] as String?;
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

    // Extrair nome do segmento do join
    String? segmentoNome;
    if (map['segmentos'] != null) {
      final segmentosMap = map['segmentos'];
      if (segmentosMap is Map<String, dynamic>) {
        segmentoNome = segmentosMap['segmento'] as String?;
      }
    }

    // Extrair lista de executores do join many-to-many
    List<EquipeExecutor> executoresList = [];
    
    if (map['equipes_executores'] != null) {
      final executoresData = map['equipes_executores'];
      
      if (executoresData is List) {
        for (var item in executoresData) {
          if (item is Map<String, dynamic>) {
            executoresList.add(EquipeExecutor.fromMap(item));
          }
        }
      } else if (executoresData is Map<String, dynamic>) {
        // Caso seja um único objeto ao invés de lista
        executoresList.add(EquipeExecutor.fromMap(executoresData));
      }
    }

    return Equipe(
      id: map['id'] as String,
      nome: map['nome'] as String,
      descricao: map['descricao'] as String?,
      tipo: map['tipo'] as String,
      regionalId: map['regional_id'] as String?,
      regional: regionalNome,
      divisaoId: map['divisao_id'] as String?,
      divisao: divisaoNome,
      segmentoId: map['segmento_id'] as String?,
      segmento: segmentoNome,
      ativo: map['ativo'] as bool? ?? true,
      executores: executoresList,
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
    return 'Equipe(id: $id, nome: $nome, tipo: $tipo, executores: ${executores.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Equipe && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

