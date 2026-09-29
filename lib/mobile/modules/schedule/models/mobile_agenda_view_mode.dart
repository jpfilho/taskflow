/// Modos de visualização para a programação diária e agenda mobile.
enum MobileAgendaViewMode {
  /// Linha do tempo cronológica com divisão por blocos de horários do dia.
  timeline('Horário', 'Cronológica'),

  /// Agrupamento das atividades do dia pelas equipes escaladas.
  teams('Equipes', 'Por Equipe'),

  /// Agrupamento das atividades do dia pelos veículos da frota alocados.
  fleet('Frota', 'Por Veículo');

  final String shortLabel;
  final String fullLabel;

  const MobileAgendaViewMode(this.shortLabel, this.fullLabel);
}
