import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geohash_plus/geohash_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'dart:math';

import '../../../core/models/post_model.dart';

class Comment {
  final String commentId;
  final String userId;
  final String content;
  final DateTime timestamp;

  Comment({
    required this.commentId,
    required this.userId,
    required this.content,
    required this.timestamp,
  });

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      commentId: map['commentId'] as String,
      userId: map['userId'] as String,
      content: map['content'] as String,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'commentId': commentId,
      'userId': userId,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

class PostProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CloudinaryPublic _cloudinary = CloudinaryPublic('dkltwubbb', 'ml_default');

  List<PostModel> _posts = [];
  String? _errorMessage;
  bool _isLoading = false;
  DocumentSnapshot? _lastDocument;
  bool _hasMorePosts = true;
  Map<String, List<Comment>> _comments = {};
  // Cache for place names to reduce geocoding calls
  final Map<String, String?> _placeNameCache = {};

  PostProvider();

  List<PostModel> get posts => _posts;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get hasMorePosts => _hasMorePosts;
  List<Comment> commentsForPost(String postId) => _comments[postId] ?? [];



Future<String?> _getPlaceName(double latitude, double longitude, {int retries = 2}) async {
  // Generate cache key from rounded coordinates to avoid floating-point issues
  final cacheKey = '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
  if (_placeNameCache.containsKey(cacheKey)) {
    print('Returning cached place name for ($latitude, $longitude): ${_placeNameCache[cacheKey]}');
    return _placeNameCache[cacheKey];
  }

  for (int attempt = 1; attempt <= retries; attempt++) {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        // Log all relevant fields for debugging
        print('Geocoding result for ($latitude, $longitude): '
            'name=${placemark.name}, street=${placemark.street}, '
            'thoroughfare=${placemark.thoroughfare}, subLocality=${placemark.subLocality}, '
            'locality=${placemark.locality}, administrativeArea=${placemark.administrativeArea}');

        // Check if name is a Plus Code (e.g., "MMFC+5J3")
        bool isPlusCode = placemark.name != null &&
            placemark.name!.contains('+') &&
            placemark.name!.length >= 6 &&
            placemark.name!.length <= 10 &&
            RegExp(r'^[A-Z0-9]+\+[A-Z0-9]+$').hasMatch(placemark.name!);

        // Prioritize fields for human-readable name
        String? placeName;
        if (!isPlusCode && placemark.name?.isNotEmpty == true && placemark.name != placemark.street) {
          // Use name if it's not a Plus Code and not identical to street
          placeName = placemark.name;
        } else if (placemark.street?.isNotEmpty == true) {
          // Use street for specific addresses (e.g., "123 Main St")
          placeName = placemark.street;
        } else if (placemark.thoroughfare?.isNotEmpty == true) {
          // Use thoroughfare for main roads
          placeName = placemark.thoroughfare;
        } else if (placemark.subLocality?.isNotEmpty == true) {
          // Use subLocality for neighborhoods
          placeName = placemark.subLocality;
        } else if (placemark.locality?.isNotEmpty == true) {
          // Use locality for cities
          placeName = placemark.locality;
        } else if (placemark.administrativeArea?.isNotEmpty == true) {
          // Use administrativeArea as last resort
          placeName = placemark.administrativeArea;
        }

        if (placeName != null) {
          print('Selected place name for ($latitude, $longitude): $placeName');
          _placeNameCache[cacheKey] = placeName;
          return placeName;
        } else {
          print('No human-readable place name found for ($latitude, $longitude)');
        }
      } else {
        print('No placemarks returned for ($latitude, $longitude)');
      }
    } catch (e) {
      print('Geocoding attempt $attempt failed for ($latitude, $longitude): $e');
      if (attempt == retries) {
        // Avoid caching null to allow future retries
        print('Max retries reached for ($latitude, $longitude), not caching result');
        return null;
      }
      await Future.delayed(Duration(milliseconds: 500 * attempt)); // Exponential backoff
    }
  }
  print('All attempts failed for ($latitude, $longitude), returning null');
  return null;
}

  Future<void> createPost(
    String userId,
    String content, {
    XFile? media,
    String? mediaType,
    double visibilityRadiusKm = 2.0,
    bool isLive = false,
    String visibility = 'public',
    String geotagPrecision = 'precise',
    String postType = 'geotagged',
    String? placeId,
    String? placeName,
    int? invitationDuration,
    String? arModelType,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      double latitude = position.latitude;
      double longitude = position.longitude;
      if (geotagPrecision == 'general') {
        const double offsetMeters = 10.0;
        final random = Random();
        final angle = random.nextDouble() * 2 * pi;
        final offsetLat = (offsetMeters / 111000) * cos(angle);
        final offsetLon = (offsetMeters / (111000 * cos(latitude * pi / 180))) * sin(angle);
        latitude += offsetLat;
        longitude += offsetLon;
      }
      final geohash = GeoHash.encode(latitude, longitude, precision: 9).hash;
      String? mediaUrl;

      // Fetch place name if not provided (except for checkIn, where user inputs it)
      String? resolvedPlaceName = placeName;
      if (resolvedPlaceName == null && postType != 'checkIn') {
        resolvedPlaceName = await _getPlaceName(latitude, longitude);
      }

      if (media != null && mediaType != null) {
        try {
          final response = await _cloudinary.uploadFile(
            CloudinaryFile.fromFile(
              media.path,
              resourceType: mediaType == 'video' || isLive ? CloudinaryResourceType.Video : CloudinaryResourceType.Image,
              folder: isLive ? 'livestreams' : 'posts',
            ),
          );
          mediaUrl = response.secureUrl;
          print('Uploaded media to Cloudinary: $mediaUrl');
        } catch (e) {
          throw Exception('Failed to upload media to Cloudinary: $e');
        }
      }

      final postId = _firestore.collection('posts').doc().id;
      final post = PostModel(
        postId: postId,
        userId: userId,
        content: content,
        mediaType: mediaType,
        mediaUrl: mediaUrl,
        location: GeoPoint(latitude, longitude),
        geohash: geohash,
        timestamp: DateTime.now(),
        visibilityRadiusKm: visibilityRadiusKm,
        visibility: visibility,
        geotagPrecision: geotagPrecision,
        postType: postType,
        placeId: placeId,
        placeName: resolvedPlaceName,
        invitationDuration: invitationDuration,
        arModelUrl: null, // No AR
        arModelType: null,
      );

      await _firestore.collection('posts').doc(postId).set(post.toMap());
      _posts.insert(0, post);
      print('Post created: $postId at ($latitude, $longitude) with radius $visibilityRadiusKm km, type: $postType, placeName: $resolvedPlaceName');
      _clearError();
    } catch (e, stackTrace) {
      _errorMessage = 'Failed to create post: $e';
      print('Error creating post: $e\n$stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> likePost(String postId, String userId) async {
    try {
      final postRef = _firestore.collection('posts').doc(postId);
      await _firestore.runTransaction((transaction) async {
        final postSnapshot = await transaction.get(postRef);
        if (!postSnapshot.exists) throw Exception('Post does not exist');
        final post = PostModel.fromMap(postSnapshot.data()!);
        if (!post.likes.contains(userId)) {
          transaction.update(postRef, {
            'likes': FieldValue.arrayUnion([userId]),
          });
        }
      });
      final postIndex = _posts.indexWhere((p) => p.postId == postId);
      if (postIndex != -1) {
        _posts[postIndex] = _posts[postIndex].copyWith(
          likes: [..._posts[postIndex].likes, userId],
        );
        notifyListeners();
      }
      print('User $userId liked post $postId');
    } catch (e, stackTrace) {
      _errorMessage = 'Failed to like post: $e';
      print('Error liking post: $e\n$stackTrace');
    }
  }

  Future<void> unlikePost(String postId, String userId) async {
    try {
      final postRef = _firestore.collection('posts').doc(postId);
      await _firestore.runTransaction((transaction) async {
        final postSnapshot = await transaction.get(postRef);
        if (!postSnapshot.exists) throw Exception('Post does not exist');
        final post = PostModel.fromMap(postSnapshot.data()!);
        if (post.likes.contains(userId)) {
          transaction.update(postRef, {
            'likes': FieldValue.arrayRemove([userId]),
          });
        }
      });
      final postIndex = _posts.indexWhere((p) => p.postId == postId);
      if (postIndex != -1) {
        _posts[postIndex] = _posts[postIndex].copyWith(
          likes: _posts[postIndex].likes.where((id) => id != userId).toList(),
        );
        notifyListeners();
      }
      print('User $userId unliked post $postId');
    } catch (e, stackTrace) {
      _errorMessage = 'Failed to unlike post: $e';
      print('Error unliking post: $e\n$stackTrace');
    }
  }

  Future<void> addComment(String postId, String userId, String content) async {
    try {
      final commentId = _firestore.collection('posts').doc(postId).collection('comments').doc().id;
      final comment = Comment(
        commentId: commentId,
        userId: userId,
        content: content,
        timestamp: DateTime.now(),
      );
      final postRef = _firestore.collection('posts').doc(postId);
      await _firestore.runTransaction((transaction) async {
        final postSnapshot = await transaction.get(postRef);
        if (!postSnapshot.exists) throw Exception('Post does not exist');
        transaction
          ..set(postRef.collection('comments').doc(commentId), comment.toMap())
          ..update(postRef, {
            'commentsCount': FieldValue.increment(1),
          });
      });
      final postIndex = _posts.indexWhere((p) => p.postId == postId);
      if (postIndex != -1) {
        _posts[postIndex] = _posts[postIndex].copyWith(
          commentsCount: _posts[postIndex].commentsCount + 1,
        );
        _comments[postId] = [...(_comments[postId] ?? []), comment];
        notifyListeners();
      }
      print('Comment added to post $postId by user $userId');
    } catch (e, stackTrace) {
      _errorMessage = 'Failed to add comment: $e';
      print('Error adding comment: $e\n$stackTrace');
    }
  }

  Future<void> fetchComments(String postId) async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();
      _comments[postId] = snapshot.docs
          .where((doc) => doc.data() != null)
          .map((doc) => Comment.fromMap(doc.data()))
          .toList();
      notifyListeners();
      print('Fetched ${_comments[postId]!.length} comments for post $postId');
    } catch (e, stackTrace) {
      _errorMessage = 'Failed to fetch comments: $e';
      print('Error fetching comments: $e\n$stackTrace');
    }
  }

  Future<void> fetchNearbyPosts(
    double latitude,
    double longitude, {
    String? currentUserId,
    double radiusKm = 5.0,
    int limit = 10,
  }) async {
    if (_isLoading || (!_hasMorePosts && !_posts.isEmpty)) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('Fetching posts near ($latitude, $longitude) with radius $radiusKm km');
      const double kmPerDegree = 111.0;
      final latDelta = radiusKm / kmPerDegree;
      final lonDelta = radiusKm / (kmPerDegree * cos(latitude * pi / 180));

      Query<Map<String, dynamic>> query = _firestore
          .collection('posts')
          .where('location', isGreaterThanOrEqualTo: GeoPoint(latitude - latDelta, longitude - lonDelta))
          .where('location', isLessThanOrEqualTo: GeoPoint(latitude + latDelta, longitude + lonDelta))
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();
      print('Query returned ${snapshot.docs.length} documents');

      final distance = latlong.Distance();
      final newPosts = <PostModel>[];
      for (var doc in snapshot.docs) {
        try {
          final post = PostModel.fromMap(doc.data());
          final dist = distance(
            latlong.LatLng(latitude, longitude),
            latlong.LatLng(post.location.latitude, post.location.longitude),
          );
          print('Post ${post.postId}: ${post.content}, Distance: ${dist / 1000} km, Visibility: ${post.visibilityRadiusKm} km');
          // Skip AR posts
          if (post.postType == 'arTag') continue;
          // Update placeName if null
          if (post.placeName == null && post.postType != 'checkIn') {
            final placeName = await _getPlaceName(post.location.latitude, post.location.longitude);
            if (placeName != null) {
              await _firestore.collection('posts').doc(post.postId).update({'placeName': placeName});
              newPosts.add(post.copyWith(placeName: placeName));
              continue;
            }
          }
          newPosts.add(post);
        } catch (e) {
          print('Error parsing post ${doc.id}: $e');
        }
      }

      _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      _hasMorePosts = snapshot.docs.length == limit;
      _posts = _lastDocument == null ? newPosts : [..._posts, ...newPosts];

      if (_posts.isEmpty && radiusKm < 50.0) {
        print('No posts found within $radiusKm km, retrying with ${radiusKm * 2} km');
        await fetchNearbyPosts(
          latitude,
          longitude,
          currentUserId: currentUserId,
          radiusKm: radiusKm * 2,
          limit: limit,
        );
        return;
      }

      print('Fetched ${_posts.length} nearby posts, hasMore: $_hasMorePosts');
      _clearError();
    } catch (e, stackTrace) {
      _errorMessage = 'Failed to fetch posts: $e';
      print('Error fetching posts: $e\n$stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchLocationHistory(
    double latitude,
    double longitude, {
    DateTime? startDate,
    DateTime? endDate,
    int limit = 20,
  }) async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('posts')
          .where('location', isGreaterThan: GeoPoint(latitude - 0.01, longitude - 0.01))
          .where('location', isLessThan: GeoPoint(latitude + 0.01, longitude + 0.01))
          .orderBy('timestamp', descending: true);

      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final snapshot = await query.limit(limit).get();
      final newPosts = <PostModel>[];
      for (var doc in snapshot.docs) {
        try {
          final post = PostModel.fromMap(doc.data());
          if (post.postType == 'arTag') continue;
          if (post.placeName == null && post.postType != 'checkIn') {
            final placeName = await _getPlaceName(post.location.latitude, post.location.longitude);
            if (placeName != null) {
              await _firestore.collection('posts').doc(post.postId).update({'placeName': placeName});
              newPosts.add(post.copyWith(placeName: placeName));
              continue;
            }
          }
          newPosts.add(post);
        } catch (e) {
          print('Error parsing post ${doc.id}: $e');
        }
      }

      _posts = newPosts;
      _lastDocument = null;
      _hasMorePosts = false;
      print('Fetched ${_posts.length} historical posts');
      _clearError();
    } catch (e, stackTrace) {
      _errorMessage = 'Failed to fetch history: $e';
      print('Error fetching history: $e\n$stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void resetPosts() {
    _posts = [];
    _lastDocument = null;
    _hasMorePosts = true;
    notifyListeners();
  }

  void setError(String error) {
    _errorMessage = error;
    _isLoading = false;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

extension PostModelExtension on PostModel {
  PostModel copyWith({
    String? postId,
    String? userId,
    String? content,
    String? mediaUrl,
    String? mediaType,
    GeoPoint? location,
    String? geohash,
    DateTime? timestamp,
    double? visibilityRadiusKm,
    List<String>? likes,
    int? commentsCount,
    bool? isLive,
    String? visibility,
    String? geotagPrecision,
    String? postType,
    String? placeId,
    String? placeName,
    int? invitationDuration,
    List<String>? rsvpList,
    String? arModelUrl,
    String? arModelType,
  }) {
    return PostModel(
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      location: location ?? this.location,
      geohash: geohash ?? this.geohash,
      timestamp: timestamp ?? this.timestamp,
      visibilityRadiusKm: visibilityRadiusKm ?? this.visibilityRadiusKm,
      likes: likes ?? this.likes,
      commentsCount: commentsCount ?? this.commentsCount,
      isLive: isLive ?? this.isLive,
      visibility: visibility ?? this.visibility,
      geotagPrecision: geotagPrecision ?? this.geotagPrecision,
      postType: postType ?? this.postType,
      placeId: placeId ?? this.placeId,
      placeName: placeName ?? this.placeName,
      invitationDuration: invitationDuration ?? this.invitationDuration,
      rsvpList: rsvpList ?? this.rsvpList,
      arModelUrl: arModelUrl ?? this.arModelUrl,
      arModelType: arModelType ?? this.arModelType,
    );
  }
}