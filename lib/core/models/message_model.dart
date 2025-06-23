import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String messageId;
  final String senderId;
  final String content;
  final DateTime timestamp;
  final String type; // 'text', 'image', 'voice', 'video'
  final String? mediaUrl;

  Message({
    required this.messageId,
    required this.senderId,
    required this.content,
    required this.timestamp,
    required this.type,
    this.mediaUrl,
  });

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      messageId: map['messageId'] ?? '',
      senderId: map['senderId'] ?? '',
      content: map['content'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: map['type'] ?? 'text',
      mediaUrl: map['mediaUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
    };
  }
}