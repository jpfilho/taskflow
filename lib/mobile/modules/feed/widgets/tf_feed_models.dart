/// Tipos conceituais de origem do Feed (Ajuste Obrigatório #2).
enum TFFeedSourceType {
  userPost, // Publicação humana (comentário, foto de serviço, boa prática)
  activityEvent, // Evento operacional automático (iniciada, concluída, etc.)
  systemEvent, // Evento de sistema (demanda encerrada, aprovação)
  safetyNotice, // Alerta/aviso de segurança do trabalho (APR, DDS, bloqueio)
  teamUpdate, // Atualização de escala ou programação de equipe
  projectUpdate, // Marco ou avanço físico de projeto
}

/// Contexto operacional vinculado ao item de feed ou publicação.
enum TFFeedContextType {
  general,
  activity,
  demand,
  project,
  team,
  community,
  asset,
  notaSap,
  ordemSap,
}

/// Modelo conceitual de item do Feed Operacional (apenas em memória/mock nesta fase).
class TFFeedItem {
  final String id;
  final TFFeedSourceType sourceType;
  final String authorName;
  final String? authorRole;
  final String? communityOrTeam;
  final String timestamp;
  final String content;
  final String? imageUrl;
  final TFFeedContextType contextType;
  final String? linkedEntityId;
  final String? linkedEntityTitle;
  final int likesCount;
  final int commentsCount;
  final bool isLikedByMe;
  final bool isOfflinePending;

  const TFFeedItem({
    required this.id,
    required this.sourceType,
    required this.authorName,
    this.authorRole,
    this.communityOrTeam,
    required this.timestamp,
    required this.content,
    this.imageUrl,
    this.contextType = TFFeedContextType.general,
    this.linkedEntityId,
    this.linkedEntityTitle,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLikedByMe = false,
    this.isOfflinePending = false,
  });

  /// Identifica se é um evento operacional automático do sistema.
  bool get isAutomatedEvent =>
      sourceType == TFFeedSourceType.activityEvent ||
      sourceType == TFFeedSourceType.systemEvent ||
      sourceType == TFFeedSourceType.safetyNotice;
}
