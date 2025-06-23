import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String photoURL;
  final DateTime createdAt;
  final UserLocation? location;
  final bool shareLocation;
  final bool shareConnections;
  final double visibilityRadius;
  final List<String> friends;
  final List<String> facebookFriends;
  final List<String> twitterFollowers;
  final List<String> twitterFollowing;
  final Map<String, SocialAccount> socialAccounts;
  final String? facebookUsername;
  final int? facebookFollowerCount;
  final int? facebookFriendCount;
  final String? twitterUsername;
  final String? tiktokUsername;
  final int? tiktokFollowerCount;
  final int? tiktokFollowingCount;
  final String? mood;
  final DateTime? moodExpires;
  final String? visibility;
  final DateTime? visibilityExpires;
  final bool? notificationsEnabled;
  final String? profileScope;
  final bool? activitySharingEnabled;
  final String status; // Added for online indicator
  final DateTime? lastActive; // Added for last seen

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoURL = '',
    required this.createdAt,
    this.location,
    this.shareLocation = true,
    this.shareConnections = true,
    this.visibilityRadius = 10.0,
    this.friends = const [],
    this.facebookFriends = const [],
    this.twitterFollowers = const [],
    this.twitterFollowing = const [],
    this.socialAccounts = const {},
    this.facebookUsername,
    this.facebookFollowerCount,
    this.facebookFriendCount,
    this.twitterUsername,
    this.tiktokUsername,
    this.tiktokFollowerCount,
    this.tiktokFollowingCount,
    this.mood,
    this.moodExpires,
    this.visibility,
    this.visibilityExpires,
    this.notificationsEnabled,
    this.profileScope,
    this.activitySharingEnabled,
    this.status = 'offline',
    this.lastActive,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      photoURL: map['photoURL'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      location: map['location'] != null ? UserLocation.fromMap(map['location']) : null,
      shareLocation: map['shareLocation'] ?? true,
      shareConnections: map['shareConnections'] ?? true,
      visibilityRadius: (map['visibilityRadius'] as num?)?.toDouble() ?? 10.0,
      friends: List<String>.from(map['friends'] ?? []),
      facebookFriends: List<String>.from(map['facebookFriends'] ?? []),
      twitterFollowers: List<String>.from(map['twitterFollowers'] ?? []),
      twitterFollowing: List<String>.from(map['twitterFollowing'] ?? []),
      socialAccounts: (map['socialAccounts'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, SocialAccount.fromMap(value)),
          ) ?? {},
      facebookUsername: map['facebookUsername'],
      facebookFollowerCount: map['facebookFollowerCount'],
      facebookFriendCount: map['facebookFriendCount'],
      twitterUsername: map['twitterUsername'],
      tiktokUsername: map['tiktokUsername'],
      tiktokFollowerCount: map['tiktokFollowerCount'],
      tiktokFollowingCount: map['tiktokFollowingCount'],
      mood: map['mood'],
      moodExpires: (map['moodExpires'] as Timestamp?)?.toDate(),
      visibility: map['visibility'],
      visibilityExpires: (map['visibilityExpires'] as Timestamp?)?.toDate(),
      notificationsEnabled: map['notificationsEnabled'],
      profileScope: map['profileScope'],
      activitySharingEnabled: map['activitySharingEnabled'],
      status: map['status'] ?? 'offline',
      lastActive: (map['lastActive'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'createdAt': Timestamp.fromDate(createdAt),
      'location': location?.toMap(),
      'shareLocation': shareLocation,
      'shareConnections': shareConnections,
      'visibilityRadius': visibilityRadius,
      'friends': friends,
      'facebookFriends': facebookFriends,
      'twitterFollowers': twitterFollowers,
      'twitterFollowing': twitterFollowing,
      'socialAccounts': socialAccounts.map((key, value) => MapEntry(key, value.toMap())),
      'facebookUsername': facebookUsername,
      'facebookFollowerCount': facebookFollowerCount,
      'facebookFriendCount': facebookFriendCount,
      'twitterUsername': twitterUsername,
      'tiktokUsername': tiktokUsername,
      'tiktokFollowerCount': tiktokFollowerCount,
      'tiktokFollowingCount': tiktokFollowingCount,
      'mood': mood,
      'moodExpires': moodExpires != null ? Timestamp.fromDate(moodExpires!) : null,
      'visibility': visibility,
      'visibilityExpires': visibilityExpires != null ? Timestamp.fromDate(visibilityExpires!) : null,
      'notificationsEnabled': notificationsEnabled,
      'profileScope': profileScope,
      'activitySharingEnabled': activitySharingEnabled,
      'status': status,
      'lastActive': lastActive != null ? Timestamp.fromDate(lastActive!) : null,
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoURL,
    DateTime? createdAt,
    UserLocation? location,
    bool? shareLocation,
    bool? shareConnections,
    double? visibilityRadius,
    List<String>? friends,
    List<String>? facebookFriends,
    List<String>? twitterFollowers,
    List<String>? twitterFollowing,
    Map<String, SocialAccount>? socialAccounts,
    String? facebookUsername,
    int? facebookFollowerCount,
    int? facebookFriendCount,
    String? twitterUsername,
    String? tiktokUsername,
    int? tiktokFollowerCount,
    int? tiktokFollowingCount,
    String? mood,
    DateTime? moodExpires,
    String? visibility,
    DateTime? visibilityExpires,
    bool? notificationsEnabled,
    String? profileScope,
    bool? activitySharingEnabled,
    String? status,
    DateTime? lastActive,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      createdAt: createdAt ?? this.createdAt,
      location: location ?? this.location,
      shareLocation: shareLocation ?? this.shareLocation,
      shareConnections: shareConnections ?? this.shareConnections,
      visibilityRadius: visibilityRadius ?? this.visibilityRadius,
      friends: friends ?? this.friends,
      facebookFriends: facebookFriends ?? this.facebookFriends,
      twitterFollowers: twitterFollowers ?? this.twitterFollowers,
      twitterFollowing: twitterFollowing ?? this.twitterFollowing,
      socialAccounts: socialAccounts ?? this.socialAccounts,
      facebookUsername: facebookUsername ?? this.facebookUsername,
      facebookFollowerCount: facebookFollowerCount ?? this.facebookFollowerCount,
      facebookFriendCount: facebookFriendCount ?? this.facebookFriendCount,
      twitterUsername: twitterUsername ?? this.twitterUsername,
      tiktokUsername: tiktokUsername ?? this.tiktokUsername,
      tiktokFollowerCount: tiktokFollowerCount ?? this.tiktokFollowerCount,
      tiktokFollowingCount: tiktokFollowingCount ?? this.tiktokFollowingCount,
      mood: mood ?? this.mood,
      moodExpires: moodExpires ?? this.moodExpires,
      visibility: visibility ?? this.visibility,
      visibilityExpires: visibilityExpires ?? this.visibilityExpires,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      profileScope: profileScope ?? this.profileScope,
      activitySharingEnabled: activitySharingEnabled ?? this.activitySharingEnabled,
      status: status ?? this.status,
      lastActive: lastActive ?? this.lastActive,
    );
  }
}

class UserLocation {
  final double latitude;
  final double longitude;
  final DateTime lastUpdated;

  UserLocation({
    required this.latitude,
    required this.longitude,
    required this.lastUpdated,
  });

  factory UserLocation.fromMap(Map<String, dynamic> map) {
    return UserLocation(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      lastUpdated: (map['lastUpdated'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }
}

class SocialAccount {
  final String id;
  final String accessToken;
  final String platform;

  SocialAccount({
    required this.id,
    required this.accessToken,
    required this.platform,
  });

  factory SocialAccount.fromMap(Map<String, dynamic> map) {
    return SocialAccount(
      id: map['id'] ?? '',
      accessToken: map['accessToken'] ?? '',
      platform: map['platform'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'accessToken': accessToken,
      'platform': platform,
    };
  }
}