class ChatUnreadSnapshot {
  final int totalUnread;
  final Map<String, int> unreadByCommunity;
  final Map<String, int> unreadByGroup;
  final Map<String, String> groupToCommunity;
  final DateTime timestamp;

  const ChatUnreadSnapshot({
    required this.totalUnread,
    required this.unreadByCommunity,
    required this.unreadByGroup,
    required this.groupToCommunity,
    required this.timestamp,
  });

  static ChatUnreadSnapshot empty() => ChatUnreadSnapshot(
    totalUnread: 0,
    unreadByCommunity: const {},
    unreadByGroup: const {},
    groupToCommunity: const {},
    timestamp: DateTime.fromMillisecondsSinceEpoch(0),
  );
}
