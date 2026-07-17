enum ChatFeedbackSessionStatus {
  draft,
  submitted,
  cancelled,
  syncPending,
  syncFailed;

  static ChatFeedbackSessionStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return ChatFeedbackSessionStatus.draft;
      case 'submitted':
        return ChatFeedbackSessionStatus.submitted;
      case 'cancelled':
        return ChatFeedbackSessionStatus.cancelled;
      case 'sync_pending':
        return ChatFeedbackSessionStatus.syncPending;
      case 'sync_failed':
        return ChatFeedbackSessionStatus.syncFailed;
      default:
        return ChatFeedbackSessionStatus.draft;
    }
  }

  String toMapValue() {
    switch (this) {
      case ChatFeedbackSessionStatus.draft:
        return 'draft';
      case ChatFeedbackSessionStatus.submitted:
        return 'submitted';
      case ChatFeedbackSessionStatus.cancelled:
        return 'cancelled';
      case ChatFeedbackSessionStatus.syncPending:
        return 'sync_pending';
      case ChatFeedbackSessionStatus.syncFailed:
        return 'sync_failed';
    }
  }
}
