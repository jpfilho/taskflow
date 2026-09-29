/// Índices das 4 abas de conteúdo persistidas no IndexedStack do MobileShell.
/// Nota de Arquitetura: O botão central 'Campo' é uma AÇÃO MODAL e não possui índice aqui.
enum TFMobileTab {
  today('Hoje'),
  tasks('Atividades'),
  feed('Feed'),
  more('Mais');

  final String label;

  const TFMobileTab(this.label);
}

/// Rotas de navegação interna do TaskFlow Mobile para evitar chamadas Navigator.push soltas.
enum TFMobileInternalRoute {
  today,
  tasks,
  feed,
  chat,
  community,
  more,
  fieldActions,
  taskDetail,
  schedule,
  checklist,
  apr,
  mediaUpload,
  sapNotas,
  sapOrdens,
  timesheet,
}

/// Catálogo de eventos para instrumentação e telemetria futura de adoção (Item 36).
abstract class TFMobileAnalyticsEvents {
  static const String openToday = 'mobile_open_today';
  static const String openTasks = 'mobile_open_tasks';
  static const String openFeed = 'mobile_open_feed';
  static const String openChat = 'mobile_open_chat';
  static const String openMore = 'mobile_open_more';
  static const String fieldAction = 'mobile_field_action';
  static const String feedPostClick = 'mobile_feed_post_click';
  static const String chatOpen = 'mobile_chat_open';
}
