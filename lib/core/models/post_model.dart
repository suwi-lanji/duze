import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String postId;
  final String userId;
  final String content;
  final String? mediaUrl;
  final String? mediaType;
  final GeoPoint location;
  final String geohash;
  final DateTime timestamp;
  final double visibilityRadiusKm;
  final List<String> likes;
  final int commentsCount;
  final bool isLive;
  final String visibility;
  final String geotagPrecision;
  final String postType;
  final String? placeId;
  final String? placeName;
  final int? invitationDuration;
  final List<String> rsvpList;
  final String? arModelUrl; // Changed from arModelType to store GLB model URL
  final String? arModelType; // Add this

  PostModel({
    required this.postId,
    required this.userId,
    required this.content,
    this.mediaUrl,
    this.mediaType,
    required this.location,
    required this.geohash,
    required this.timestamp,
    this.visibilityRadiusKm = 2.0,
    this.likes = const [],
    this.commentsCount = 0,
    this.isLive = false,
    this.visibility = 'public',
    this.geotagPrecision = 'precise',
    this.postType = 'geotagged',
    this.placeId,
    this.placeName,
    this.invitationDuration,
    this.rsvpList = const [],
    this.arModelUrl,
    this.arModelType,
  });

  factory PostModel.fromMap(Map<String, dynamic> map) {
    return PostModel(
      postId: map['postId'] as String,
      userId: map['userId'] as String,
      content: map['content'] as String,
      mediaUrl: map['mediaUrl'] as String?,
      mediaType: map['mediaType'] as String?,
      location: map['location'] as GeoPoint,
      geohash: map['geohash'] as String,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      visibilityRadiusKm: (map['visibilityRadiusKm'] as num).toDouble(),
      likes: List<String>.from(map['likes'] ?? []),
      commentsCount: map['commentsCount'] as int? ?? 0,
      isLive: map['isLive'] as bool? ?? false,
      visibility: map['visibility'] as String? ?? 'public',
      geotagPrecision: map['geotagPrecision'] as String? ?? 'precise',
      postType: map['postType'] as String? ?? 'geotagged',
      placeId: map['placeId'] as String?,
      placeName: map['placeName'] as String?,
      invitationDuration: map['invitationDuration'] as int?,
      rsvpList: List<String>.from(map['rsvpList'] ?? []),
      arModelUrl: map['arModelUrl'] as String?,
       arModelType: map['arModelType'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'userId': userId,
      'content': content,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'location': location,
      'geohash': geohash,
      'timestamp': Timestamp.fromDate(timestamp),
      'visibilityRadiusKm': visibilityRadiusKm,
      'likes': likes,
      'commentsCount': commentsCount,
      'isLive': isLive,
      'visibility': visibility,
      'geotagPrecision': geotagPrecision,
      'postType': postType,
      'placeId': placeId,
      'placeName': placeName,
      'invitationDuration': invitationDuration,
      'rsvpList': rsvpList,
      'arModelUrl': arModelUrl,
       'arModelType': arModelType,
    };
  }



  
}