import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime? endTime;
  final double latitude;
  final double longitude;
  final String address;
  final String creatorId;
  final List<String> attendees;
  final String visibility; // 'public', 'friends', 'private'
  final String category; // 'Party', 'Sports', 'Study', etc.
  final DateTime createdAt;
  final bool isActive;

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    this.endTime,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.creatorId,
    this.attendees = const [],
    required this.visibility,
    required this.category,
    required this.createdAt,
    this.isActive = true,
  });

  factory EventModel.fromMap(Map<String, dynamic> map) {
    try {
      return EventModel(
        id: map['id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        description: map['description']?.toString() ?? '',
        startTime: (map['startTime'] is Timestamp)
            ? (map['startTime'] as Timestamp).toDate()
            : DateTime.now(),
        endTime: map['endTime'] != null && map['endTime'] is Timestamp
            ? (map['endTime'] as Timestamp).toDate()
            : null,
        latitude: _parseDouble(map['latitude']),
        longitude: _parseDouble(map['longitude']),
        address: map['address']?.toString() ?? '',
        creatorId: map['creatorId']?.toString() ?? '',
        attendees: List<String>.from(map['attendees'] ?? []),
        visibility: map['visibility']?.toString() ?? 'public',
        category: map['category']?.toString() ?? '',
        createdAt: (map['createdAt'] is Timestamp)
            ? (map['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        isActive: map['isActive'] as bool? ?? true,
      );
    } catch (e) {
      print('Error parsing EventModel from map: $e');
      rethrow;
    }
  }

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'creatorId': creatorId,
      'attendees': attendees,
      'visibility': visibility,
      'category': category,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }
}