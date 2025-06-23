import 'package:cloud_firestore/cloud_firestore.dart';

class Chat {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final DateTime lastMessageTimestamp;
  final Map<String, int> unreadCount;
  final bool isPending;
  final String? senderId;

  Chat({
   required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageTimestamp,
    required this.unreadCount,
    required this.isPending,
    this.senderId,
  });

  factory Chat.fromMap(Map<String, dynamic> map) {
    return Chat(
      id: map['chatId'] ?? map['id'],
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTimestamp: (map['lastMessageTimestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCount: Map<String, int>.from(map['unreadCount'] ?? {}),
      isPending: map['isPending'] ?? false,
      senderId: map['senderId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatId': id,
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTimestamp': Timestamp.fromDate(lastMessageTimestamp),
      'unreadCount': unreadCount,
      'isPending': isPending,
      'senderId': senderId,
    };
  }
}