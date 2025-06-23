import 'package:cloud_firestore/cloud_firestore.dart';

class MessageRequest {
  final String requestId;
  final String senderId;
  final String recipientId;
  final String message;
  final DateTime timestamp;
  final String status;

  MessageRequest({
    required this.requestId,
    required this.senderId,
    required this.recipientId,
    required this.message,
    required this.timestamp,
    required this.status,
  });

  factory MessageRequest.fromMap(Map<String, dynamic> map) {
    return MessageRequest(
      requestId: map['requestId'] ?? '',
      senderId: map['senderId'] ?? '',
      recipientId: map['recipientId'] ?? '',
      message: map['message'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'senderId': senderId,
      'recipientId': recipientId,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status,
    };
  }
}