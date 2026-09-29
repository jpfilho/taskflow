/// Matriz semântica de ações permitidas em uma tarefa mobile.
/// Derivada a partir de regras operacionais reais, permissões de usuário e status atual.
/// Evita a dispersão de condicionais 'if (status == ...)' pela interface.
class MobileTaskAvailableActions {
  final bool canStart;
  final bool canPause;
  final bool canResume;
  final bool canComplete;
  final bool canEdit;
  final bool canAddEvidence;
  final bool canOpenApr;
  final bool canOpenChat;
  final bool isReadOnly;

  const MobileTaskAvailableActions({
    this.canStart = false,
    this.canPause = false,
    this.canResume = false,
    this.canComplete = false,
    this.canEdit = false,
    this.canAddEvidence = false,
    this.canOpenApr = false,
    this.canOpenChat = false,
    this.isReadOnly = false,
  });

  /// Factory para usuário com permissão somente leitura (visitante ou sem vínculo).
  factory MobileTaskAvailableActions.readOnly() {
    return const MobileTaskAvailableActions(
      canStart: false,
      canPause: false,
      canResume: false,
      canComplete: false,
      canEdit: false,
      canAddEvidence: false,
      canOpenApr: false,
      canOpenChat: true,
      isReadOnly: true,
    );
  }

  /// Retorna o rótulo da ação principal a ser exibida no card ou barra inferior.
  String get primaryActionLabel {
    if (isReadOnly) return 'Ver Detalhes';
    if (canStart) return 'Iniciar Atividade';
    if (canResume) return 'Retomar Atividade';
    if (canPause) return 'Continuar'; // No card em execução, convida a abrir/continuar
    if (canComplete) return 'Concluir';
    return 'Ver Detalhes';
  }

  MobileTaskAvailableActions copyWith({
    bool? canStart,
    bool? canPause,
    bool? canResume,
    bool? canComplete,
    bool? canEdit,
    bool? canAddEvidence,
    bool? canOpenApr,
    bool? canOpenChat,
    bool? isReadOnly,
  }) {
    return MobileTaskAvailableActions(
      canStart: canStart ?? this.canStart,
      canPause: canPause ?? this.canPause,
      canResume: canResume ?? this.canResume,
      canComplete: canComplete ?? this.canComplete,
      canEdit: canEdit ?? this.canEdit,
      canAddEvidence: canAddEvidence ?? this.canAddEvidence,
      canOpenApr: canOpenApr ?? this.canOpenApr,
      canOpenChat: canOpenChat ?? this.canOpenChat,
      isReadOnly: isReadOnly ?? this.isReadOnly,
    );
  }
}
