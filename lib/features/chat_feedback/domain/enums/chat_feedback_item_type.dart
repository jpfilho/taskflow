enum ChatFeedbackItemType {
  nota,
  ordem,
  geral;

  static ChatFeedbackItemType fromString(String type) {
    switch (type.toUpperCase()) {
      case 'NOTA':
        return ChatFeedbackItemType.nota;
      case 'ORDEM':
        return ChatFeedbackItemType.ordem;
      case 'GERAL':
      default:
        return ChatFeedbackItemType.geral;
    }
  }

  String toMapValue() {
    switch (this) {
      case ChatFeedbackItemType.nota:
        return 'NOTA';
      case ChatFeedbackItemType.ordem:
        return 'ORDEM';
      case ChatFeedbackItemType.geral:
        return 'GERAL';
    }
  }
}
