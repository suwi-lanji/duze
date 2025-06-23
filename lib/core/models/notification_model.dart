import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String type; // e.g., 'message_request', 'post'
  final String content;
  final String itemId;
  final DateTime timestamp;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.content,
    required this.itemId,
    required this.timestamp,
    required this.isRead,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      type: map['type'] ?? '',
      content: map['content'] ?? '',
      itemId: map['itemId'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'content': content,
      'itemId': itemId,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
    };
  }

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      userId: userId,
      type: type,
      content: content,
      itemId: itemId,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}