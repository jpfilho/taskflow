import 'package:flutter/foundation.dart';
import 'nota_sap_analise.dart';
import '../features/media_albums/data/models/media_image.dart';

/// Tipos de fonte suportados para evidências técnicas da análise
enum NotaEvidenciaTipoFonte {
  anexoNota('anexo_nota', 'Anexo da Nota', '📎 Anexo'),
  fotoAlbum('foto_album', 'Foto do Álbum', '📷 Álbum'),
  anexoNotaHistorica('anexo_nota_historica', 'Anexo Histórico', '🏛️ Histórico');

  final String value;
  final String label;
  final String tagAbreviada;

  const NotaEvidenciaTipoFonte(this.value, this.label, this.tagAbreviada);

  static NotaEvidenciaTipoFonte fromDbString(String? val) {
    if (val == 'foto_album') return NotaEvidenciaTipoFonte.fotoAlbum;
    if (val == 'anexo_nota_historica') return NotaEvidenciaTipoFonte.anexoNotaHistorica;
    return NotaEvidenciaTipoFonte.anexoNota;
  }

  String toDbString() => value;
}

/// Seções da análise técnica que podem ser sustentadas por evidências
enum NotaTipoVinculoEvidencia {
  diagnostico('diagnostico', 'Diagnóstico Prévio', 'Diagnóstico'),
  escopo('escopo', 'Escopo Detalhado', 'Escopo'),
  materiais('materiais', 'Materiais & Peças', 'Materiais'),
  seguranca('seguranca', 'Requisitos de Segurança', 'Segurança'),
  desligamento('desligamento', 'Desligamento & PV', 'Desligamento'),
  acesso('acesso', 'Acesso & Logística', 'Acesso'),
  outro('outro', 'Evidência Complementar', 'Outros');

  final String value;
  final String label;
  final String tagAbreviada;

  const NotaTipoVinculoEvidencia(this.value, this.label, this.tagAbreviada);

  /// Getters de conveniência
  String get valor => value;
  String get labelCurto => tagAbreviada;

  static NotaTipoVinculoEvidencia? fromValor(String? val) {
    if (val == null || val.trim().isEmpty) return null;
    final normalized = val.trim().toLowerCase();
    for (final tipo in NotaTipoVinculoEvidencia.values) {
      if (tipo.value == normalized) return tipo;
    }
    return null;
  }

  static NotaTipoVinculoEvidencia fromDbString(String? val) {
    return fromValor(val) ?? NotaTipoVinculoEvidencia.outro;
  }

  String toDbString() => value;
}

/// Representa a vinculação estruturada entre uma evidência (anexo próprio, foto de álbum ou anexo histórico)
/// e uma seção técnica específica da Análise da Nota SAP.
@immutable
class NotaSapAnaliseEvidencia {
  final String? id;
  final String notaSapId;
  final NotaEvidenciaTipoFonte tipoFonte;
  final String? anexoId;
  final String? mediaImageId;
  final NotaTipoVinculoEvidencia tipoVinculo;
  final int? anotacaoVersao; // NULL = original/sem anotações (sempre NULL para foto_album)
  final String? observacao;
  final int ordem;
  final String? criadoPor;
  final String? criadoPorNome;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Propriedades enriquecidas em memória para exibição em UI
  final NotaSapAnexo? anexo;
  final MediaImage? mediaImage;
  final String? numeroNotaHistorica; // Número da Nota SAP de origem recuperado em batch
  final int? _versaoMaisRecenteAnexo;
  int? get versaoMaisRecenteAnexo =>
      _versaoMaisRecenteAnexo ?? anexo?.versaoAnotacao;

  const NotaSapAnaliseEvidencia({
    this.id,
    required this.notaSapId,
    this.tipoFonte = NotaEvidenciaTipoFonte.anexoNota,
    this.anexoId,
    this.mediaImageId,
    required this.tipoVinculo,
    this.anotacaoVersao,
    this.observacao,
    this.ordem = 0,
    this.criadoPor,
    this.criadoPorNome,
    this.createdAt,
    this.updatedAt,
    this.anexo,
    this.mediaImage,
    this.numeroNotaHistorica,
    int? versaoMaisRecenteAnexo,
  }) : _versaoMaisRecenteAnexo = versaoMaisRecenteAnexo;

  /// Indica se a evidência tem origem nos anexos da própria nota SAP
  bool get isAnexo => tipoFonte == NotaEvidenciaTipoFonte.anexoNota;

  /// Indica se a evidência tem origem nas fotos históricas do módulo de álbuns
  bool get isFotoAlbum => tipoFonte == NotaEvidenciaTipoFonte.fotoAlbum;

  /// Indica se a evidência tem origem em anexo de Nota SAP anterior/histórica
  bool get isAnexoHistorico => tipoFonte == NotaEvidenciaTipoFonte.anexoNotaHistorica;

  /// ID de referência física na tabela de origem
  String get sourceId => isFotoAlbum ? (mediaImageId ?? '') : (anexoId ?? '');

  /// Chave lógica polimórfica para contadores distinct e deduplicação
  String get logicalIdentity => '${tipoFonte.value}:$sourceId';

  /// Indica se o vínculo fundamenta-se no arquivo original sem anotações
  bool get isOriginalSemAnotacao => anotacaoVersao == null;

  /// Indica se o vínculo fundamenta-se em uma versão vetorial/derivada de anotação
  bool get isComAnotacao => anotacaoVersao != null && anotacaoVersao! > 0;

  /// Indica se existe uma versão posterior da anotação no anexo (sem atualizar sozinho)
  bool get hasVersaoMaisRecente =>
      versaoMaisRecenteAnexo != null &&
      anotacaoVersao != null &&
      versaoMaisRecenteAnexo! > anotacaoVersao!;

  /// Rótulo descritivo da versão vinculada ('Original' ou 'vN')
  String get rotuloVersao {
    if (isFotoAlbum) return 'Original';
    return (anotacaoVersao != null && anotacaoVersao! > 0)
        ? 'v$anotacaoVersao'
        : 'Original';
  }

  /// Título de exibição unificado para a UI da Análise
  String get tituloExibicao {
    if (isFotoAlbum) {
      if (mediaImage?.title != null && mediaImage!.title.trim().isNotEmpty) {
        return mediaImage!.title.trim();
      }
      if (mediaImage?.description != null && mediaImage!.description!.trim().isNotEmpty) {
        return mediaImage!.description!.trim();
      }
      return 'Fotografia do Álbum';
    }
    if (isAnexoHistorico) {
      final notaRef = (numeroNotaHistorica != null && numeroNotaHistorica!.trim().isNotEmpty)
          ? 'Nota SAP ${numeroNotaHistorica!.trim()}'
          : 'Nota Anterior';
      final nomeArq = anexo?.nomeOriginal ?? anexo?.nomeArquivo ?? 'Anexo Histórico';
      return '$notaRef • $nomeArq';
    }
    return anexo?.nomeOriginal ?? anexo?.nomeArquivo ?? 'Anexo da Nota';
  }

  /// Data de registro do arquivo original (obrigatória para histórico)
  DateTime? get dataRegistro {
    if (isFotoAlbum) {
      return mediaImage?.createdAt;
    }
    return anexo?.createdAt ?? createdAt;
  }

  factory NotaSapAnaliseEvidencia.fromMap(
    Map<String, dynamic> map, {
    NotaSapAnexo? anexoCarregado,
    MediaImage? mediaImageCarregada,
    String? numeroNotaHistoricaCarregado,
    int? maxVersaoDisponivel,
  }) {
    final tipoFonte = NotaEvidenciaTipoFonte.fromDbString(
      map['tipo_fonte']?.toString(),
    );

    return NotaSapAnaliseEvidencia(
      id: map['id']?.toString(),
      notaSapId: map['nota_sap_id']?.toString() ?? '',
      tipoFonte: tipoFonte,
      anexoId: map['anexo_id']?.toString(),
      mediaImageId: map['media_image_id']?.toString(),
      tipoVinculo: NotaTipoVinculoEvidencia.fromDbString(
        map['tipo_vinculo']?.toString(),
      ),
      anotacaoVersao: (map['anotacao_versao'] as num?)?.toInt(),
      observacao: map['observacao']?.toString(),
      ordem: (map['ordem'] as num?)?.toInt() ?? 0,
      criadoPor: map['criado_por']?.toString(),
      criadoPorNome: map['criado_por_nome']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
      anexo: anexoCarregado ??
          (map['anexo'] != null
              ? NotaSapAnexo.fromMap(map['anexo'] as Map<String, dynamic>)
              : null),
      mediaImage: mediaImageCarregada,
      numeroNotaHistorica: numeroNotaHistoricaCarregado,
      versaoMaisRecenteAnexo: maxVersaoDisponivel,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nota_sap_id': notaSapId,
      'tipo_fonte': tipoFonte.toDbString(),
      if (anexoId != null) 'anexo_id': anexoId,
      if (mediaImageId != null) 'media_image_id': mediaImageId,
      'tipo_vinculo': tipoVinculo.toDbString(),
      'anotacao_versao': anotacaoVersao,
      if (observacao != null) 'observacao': observacao,
      'ordem': ordem,
      if (criadoPor != null) 'criado_por': criadoPor,
      if (criadoPorNome != null) 'criado_por_nome': criadoPorNome,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  NotaSapAnaliseEvidencia copyWith({
    String? id,
    String? notaSapId,
    NotaEvidenciaTipoFonte? tipoFonte,
    String? anexoId,
    String? mediaImageId,
    NotaTipoVinculoEvidencia? tipoVinculo,
    int? anotacaoVersao,
    String? observacao,
    int? ordem,
    String? criadoPor,
    String? criadoPorNome,
    DateTime? createdAt,
    DateTime? updatedAt,
    NotaSapAnexo? anexo,
    MediaImage? mediaImage,
    String? numeroNotaHistorica,
    int? versaoMaisRecenteAnexo,
  }) {
    return NotaSapAnaliseEvidencia(
      id: id ?? this.id,
      notaSapId: notaSapId ?? this.notaSapId,
      tipoFonte: tipoFonte ?? this.tipoFonte,
      anexoId: anexoId ?? this.anexoId,
      mediaImageId: mediaImageId ?? this.mediaImageId,
      tipoVinculo: tipoVinculo ?? this.tipoVinculo,
      anotacaoVersao: anotacaoVersao ?? this.anotacaoVersao,
      observacao: observacao ?? this.observacao,
      ordem: ordem ?? this.ordem,
      criadoPor: criadoPor ?? this.criadoPor,
      criadoPorNome: criadoPorNome ?? this.criadoPorNome,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      anexo: anexo ?? this.anexo,
      mediaImage: mediaImage ?? this.mediaImage,
      numeroNotaHistorica: numeroNotaHistorica ?? this.numeroNotaHistorica,
      versaoMaisRecenteAnexo:
          versaoMaisRecenteAnexo ?? this.versaoMaisRecenteAnexo,
    );
  }
}

