import 'package:cloud_firestore/cloud_firestore.dart';

class CheckinModel {
  final String checkinId;
  final String userId;
  final String? venueName;
  final GeoPoint location;
  final Timestamp timestamp;
  final String? photoURL;
  final String? description;

  CheckinModel({
    required this.checkinId,
    required this.userId,
    this.venueName,
    required this.location,
    required this.timestamp,
    this.photoURL,
    this.description,
  });

  factory CheckinModel.fromMap(Map<String, dynamic> map) {
    return CheckinModel(
      checkinId: map['checkinId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      venueName: map['venueName'] as String?,
      location: map['location'] as GeoPoint? ?? const GeoPoint(0, 0),
      timestamp: map['timestamp'] as Timestamp? ?? Timestamp.now(),
      photoURL: map['photoURL'] as String?,
      description: map['description'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'checkinId': checkinId,
      'userId': userId,
      'venueName': venueName,
      'location': location,
      'timestamp': timestamp,
      'photoURL': photoURL,
      'description': description,
    };
  }
}