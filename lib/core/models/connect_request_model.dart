import 'package:cloud_firestore/cloud_firestore.dart';

class ConnectRequest {
  final String id;
  final String senderId;
  final String recipientId;
  final String? messageRequestId;
  final String status;
  final DateTime timestamp;

  ConnectRequest({
    required this.id,
    required this.senderId,
    required this.recipientId,
    this.messageRequestId,
    required this.status,
    required this.timestamp,
  });

  factory ConnectRequest.fromMap(Map<String, dynamic> map) {
    return ConnectRequest(
      id: map['id'] ?? map['requestId'] ?? '',
      senderId: map['senderId'] ?? '',
      recipientId: map['recipientId'] ?? '',
      messageRequestId: map['messageRequestId'],
      status: map['status'] ?? 'pending',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'recipientId': recipientId,
      'messageRequestId': messageRequestId,
      'status': status,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}