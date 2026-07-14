class ChatConversation {
  final String id;
  final String title;
  final String lastMessage;
  final DateTime updatedAt;
  final int messageCount;

  ChatConversation({
    required this.id,
    required this.title,
    required this.lastMessage,
    required this.updatedAt,
    required this.messageCount,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'lastMessage': lastMessage,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'messageCount': messageCount,
      };

  factory ChatConversation.fromMap(Map<String, dynamic> map, String id) {
    return ChatConversation(
      id: id,
      title: map['title'] as String? ?? 'Untitled',
      lastMessage: map['lastMessage'] as String? ?? '',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        map['updatedAt'] as int? ?? 0,
      ),
      messageCount: map['messageCount'] as int? ?? 0,
    );
  }
}
