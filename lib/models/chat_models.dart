import 'package:cloud_firestore/cloud_firestore.dart';

class Chat {
  final String chatId;
  final String castingId;
  final String modelId;
  final String agencyId;
  final String status;
  final Timestamp createdAt;
  final Timestamp? lastUpdated;
  final String? lastMessage;

  Chat({
    required this.chatId,
    required this.castingId,
    required this.modelId,
    required this.agencyId,
    required this.status,
    required this.createdAt,
    this.lastUpdated,
    this.lastMessage,
  });

  Map<String, dynamic> toMap() => {
        'castingId': castingId,
        'modelId': modelId,
        'agencyId': agencyId,
        'status': status,
        'createdAt': createdAt,
        'lastUpdated': lastUpdated,
        'lastMessage': lastMessage,
      };

  static Chat fromDoc(String id, Map<String, dynamic> data) {
    return Chat(
      chatId: id,
      castingId: data['castingId'],
      modelId: data['modelId'],
      agencyId: data['agencyId'],
      status: data['status'] ?? 'NEGOTIATING',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      lastUpdated: data['lastUpdated'],
      lastMessage: data['lastMessage'],
    );
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String encryptedContent;
  final Timestamp timestamp;
  final String type;
  final Map<String, dynamic>? metadata;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.encryptedContent,
    required this.timestamp,
    required this.type,
    this.metadata,
  });

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'encryptedContent': encryptedContent,
        'timestamp': timestamp,
        'type': type,
        'metadata': metadata,
      };

  static ChatMessage fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'],
      encryptedContent: data['encryptedContent'],
      timestamp: data['timestamp'] ?? Timestamp.now(),
      type: data['type'] ?? 'text',
      metadata: data['metadata'] != null ? Map<String, dynamic>.from(data['metadata']) : null,
    );
  }
}
