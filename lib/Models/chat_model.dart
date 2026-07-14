enum MessageSender { user, ai }

class ChatMessage {
  /// Firestore document ID — null until the doc is created.
  final String? docId;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;

  /// Firebase Storage download URL for an image attached by the user.
  /// Null when no image was sent.
  final String? imageUrl;

  ChatMessage({
    this.docId,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'text': text,
      'sender': sender.name, // 'user' or 'ai'
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
    if (imageUrl != null) map['imageUrl'] = imageUrl;
    return map;
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map, {String? docId}) {
    return ChatMessage(
      docId: docId,
      text: map['text'] as String,
      sender: map['sender'] == 'user' ? MessageSender.user : MessageSender.ai,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      imageUrl: map['imageUrl'] as String?,
    );
  }
}
