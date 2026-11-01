import '../features/media_albums/data/models/media_image.dart';

/// Nível de confiança e proximidade da correspondência histórica visual.
enum HistoricoVisualNivel {
  /// Nível A: Correspondência exata de equipamento SAP (maior especificidade técnica).
  equipamento(
    label: 'Equipamento',
    badgeText: 'Mesmo Equipamento',
    descricao: 'Fotografia com vínculo direto ao equipamento técnico da nota',
    prioridade: 1,
  ),

  /// Nível B: Correspondência de torre, vão, bay ou sala física dentro do mesmo local.
  sala(
    label: 'Sala / Estrutura',
    badgeText: 'Mesma Sala / Estrutura',
    descricao: 'Fotografia registrada na mesma torre, vão, bay ou estrutura física',
    prioridade: 2,
  ),

  /// Nível C: Correspondência ampla de contexto da Linha de Transmissão ou Subestação.
  local(
    label: 'Mesmo Local',
    badgeText: 'Mesmo Local',
    descricao: 'Fotografia panorâmica ou contextual do mesmo ativo técnico',
    prioridade: 3,
  );

  final String label;
  final String badgeText;
  final String descricao;
  final int prioridade;

  const HistoricoVisualNivel({
    required this.label,
    required this.badgeText,
    required this.descricao,
    required this.prioridade,
  });
}

/// Item individual do histórico visual contextual (Read-Only).
class HistoricoVisualItem {
  final MediaImage mediaImage;
  final HistoricoVisualNivel nivel;
  final String motivoCorrespondencia;
  final String? localNome;
  final String? sala;
  final String? equipamento;
  final DateTime createdAt;

  HistoricoVisualItem({
    required this.mediaImage,
    required this.nivel,
    required this.motivoCorrespondencia,
    this.localNome,
    this.sala,
    this.equipamento,
    required this.createdAt,
  });

  /// ID único da imagem na tabela media_images
  String get id => mediaImage.id;

  /// URL de exibição (signed URL do bucket taskflow-media)
  String? get imageUrl => mediaImage.annotatedFileUrl ?? mediaImage.fileUrl;

  /// Título do registro de campo
  String get title => mediaImage.title.trim().isNotEmpty ? mediaImage.title : 'Registro de Campo';

  /// Descrição complementar se houver
  String? get description => mediaImage.description;

  /// Formatação legível da data absoluta (dd/MM/yyyy)
  String get dataFormatada {
    final dia = createdAt.day.toString().padLeft(2, '0');
    final mes = createdAt.month.toString().padLeft(2, '0');
    final ano = createdAt.year.toString();
    return '$dia/$mes/$ano';
  }

  /// Formatação de idade relativa (ex: "há 3 meses", "há 1 ano")
  String get idadeFormatada {
    final agora = DateTime.now();
    final diff = agora.difference(createdAt);

    if (diff.inDays < 1) {
      return 'Hoje';
    } else if (diff.inDays == 1) {
      return 'Ontem';
    } else if (diff.inDays < 30) {
      return 'há ${diff.inDays} dias';
    } else if (diff.inDays < 365) {
      final meses = (diff.inDays / 30).floor();
      return meses <= 1 ? 'há 1 mês' : 'há $meses meses';
    } else {
      final anos = (diff.inDays / 365).floor();
      return anos <= 1 ? 'há 1 ano' : 'há $anos anos';
    }
  }
}

/// Resultado consolidado da consulta de histórico visual com contadores globais.
class HistoricoVisualResultado {
  /// Lista deduplicada de itens classificados e ordenados (A > B > C, created_at DESC).
  final List<HistoricoVisualItem> itens;

  /// Contagem total de fotografias por nível no ativo (independentemente do limite de paginação).
  final int totalEquipamento;
  final int totalSala;
  final int totalLocal;

  /// Raiz técnica do ativo SAP identificada (ex: H-L-SIBDSSBD-RB4L01).
  final String? raizSapIdentificada;

  /// Nome legível do local identificado.
  final String? localNome;

  /// Nome legível da sala filtrada (se aplicável).
  final String? salaNome;

  /// Indica se a busca aplicou filtro estrito de sala da Nota.
  final bool filtroSalaAplicado;

  const HistoricoVisualResultado({
    required this.itens,
    required this.totalEquipamento,
    required this.totalSala,
    required this.totalLocal,
    this.raizSapIdentificada,
    this.localNome,
    this.salaNome,
    this.filtroSalaAplicado = false,
  });

  /// Total global de fotografias históricas encontradas no ativo
  int get totalGlobal => totalEquipamento + totalSala + totalLocal;

  /// Indica se encontrou alguma foto no ativo
  bool get temFotos => totalGlobal > 0;

  /// Indica se encontrou correspondência de alta relevância (A ou B)
  bool get temCorrespondenciaEspecifica => (totalEquipamento + totalSala) > 0;

  /// Retorna apenas os itens de Nível A
  List<HistoricoVisualItem> get itensEquipamento =>
      itens.where((i) => i.nivel == HistoricoVisualNivel.equipamento).toList();

  /// Retorna apenas os itens de Nível B
  List<HistoricoVisualItem> get itensSala =>
      itens.where((i) => i.nivel == HistoricoVisualNivel.sala).toList();

  /// Retorna apenas os itens de Nível C
  List<HistoricoVisualItem> get itensLocal =>
      itens.where((i) => i.nivel == HistoricoVisualNivel.local).toList();

  /// Construtor para estado vazio
  factory HistoricoVisualResultado.vazio({
    String? localNome,
    String? salaNome,
    bool filtroSalaAplicado = false,
  }) {
    return HistoricoVisualResultado(
      itens: const [],
      totalEquipamento: 0,
      totalSala: 0,
      totalLocal: 0,
      localNome: localNome,
      salaNome: salaNome,
      filtroSalaAplicado: filtroSalaAplicado,
    );
  }
}
