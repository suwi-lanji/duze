import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:duze/features/discovery/models/event_model.dart';
import 'package:duze/core/models/user_model.dart';
import 'package:duze/core/services/social_service.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'dart:math';

class DiscoveryProvider extends ChangeNotifier {
  final SocialService _socialService = SocialService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<UserModel> _discoveredUsers = [];
  bool _isLoading = false;
  String? _errorMessage;
  List<EventModel> _nearbyEvents = [];
  DocumentSnapshot? _lastDocument;
  bool _hasMoreUsers = true;
  static const int _limit = 10;

  List<EventModel> get nearbyEvents => _nearbyEvents;
  List<UserModel> get discoveredUsers => _discoveredUsers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasMoreUsers => _hasMoreUsers;

  Future<void> createEvent({
    required String title,
    required String description,
    required DateTime startTime,
    DateTime? endTime,
    required double latitude,
    required double longitude,
    required String address,
    required String userId,
    required String visibility,
    required String category,
  }) async {
    _setLoading(true);
    try {
      print('Creating event: $title');
      final eventRef = _firestore.collection('events').doc();
      final event = EventModel(
        id: eventRef.id,
        title: title,
        description: description,
        startTime: startTime,
        endTime: endTime,
        latitude: latitude,
        longitude: longitude,
        address: address,
        creatorId: userId,
        visibility: visibility,
        category: category,
        createdAt: DateTime.now(),
      );
      await eventRef.set(event.toMap());
      print('Event created: ${eventRef.id}');
      _clearError();
      notifyListeners();
    } catch (e) {
      print('Error creating event: $e');
      _setError('Failed to create event: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadNearbyEvents(
    double latitude,
    double longitude,
    double radiusKm,
    String currentUserId,
    List<String> friendIds,
  ) async {
    _setLoading(true);
    try {
      print('Fetching events within $radiusKm km from ($latitude, $longitude) for user $currentUserId');
      final snapshot = await _firestore
          .collection('events')
          .where('isActive', isEqualTo: true)
          .get();
      print('Retrieved ${snapshot.docs.length} active events: ${snapshot.docs.map((d) => d.id).toList()}');

      List<EventModel> events = [];
      final distanceCalculator = const latlong.Distance();

      for (var doc in snapshot.docs) {
        try {
          final event = EventModel.fromMap({...doc.data(), 'id': doc.id});
          print('Processing event: ID: ${event.id}, Title: ${event.title}, Visibility: ${event.visibility}');

          // Visibility check
          if (event.visibility == 'private' &&
              event.creatorId != currentUserId &&
              !friendIds.contains(event.creatorId)) {
            print('Skipping private event ${event.id} (not friend or creator)');
            continue;
          }
          if (event.visibility == 'friends' &&
              event.creatorId != currentUserId &&
              !friendIds.contains(event.creatorId)) {
            print('Skipping friends-only event ${event.id} (not friend or creator)');
            continue;
          }

          // Distance calculation
          final distance = distanceCalculator(
                latlong.LatLng(latitude, longitude),
                latlong.LatLng(event.latitude, event.longitude),
              ) /
              1000; // Convert to km
          print('Distance to event ${event.id}: $distance km');

          if (distance <= radiusKm) {
            print('Adding event ${event.id}');
            events.add(event);
          } else {
            print('Event ${event.id} too far: $distance km > $radiusKm km');
          }
        } catch (e) {
          print('Error parsing event ${doc.id}: $e');
          continue;
        }
      }

      _nearbyEvents = events..sort((a, b) => a.startTime.compareTo(b.startTime));
      print('Loaded ${_nearbyEvents.length} nearby events: ${_nearbyEvents.map((e) => e.id).toList()}');
      _clearError();
      notifyListeners();
    } catch (e, stackTrace) {
      print('Error loading events: $e\n$stackTrace');
      _setError('Failed to load events: $e');
      notifyListeners();
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> rsvpToEvent(String eventId, String userId, bool isAttending) async {
    _setLoading(true);
    try {
      print('RSVP to event $eventId for user $userId: isAttending=$isAttending');
      final eventRef = _firestore.collection('events').doc(eventId);
      if (isAttending) {
        await eventRef.update({
          'attendees': FieldValue.arrayUnion([userId]),
        });
      } else {
        await eventRef.update({
          'attendees': FieldValue.arrayRemove([userId]),
        });
      }
      print('RSVP updated for event $eventId');
      _clearError();
      notifyListeners();
    } catch (e) {
      print('Error RSVPing to event $eventId: $e');
      _setError('Failed to RSVP: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> discoverNearbyUsers(
    String currentUserId,
    double latitude,
    double longitude,
    double radiusKm,
  ) async {
    if (_isLoading || !_hasMoreUsers) return;
    _setLoading(true);
    try {
      print('Fetching users within $radiusKm km from ($latitude, $longitude)');

      const double kmPerDegree = 111.0;
      final latDelta = radiusKm / kmPerDegree;
      final lonDelta = radiusKm / (kmPerDegree * cos(latitude * pi / 180));

      Query<Map<String, dynamic>> query = _firestore
          .collection('users')
          .where('shareLocation', isEqualTo: true)
          .where('location.latitude', isGreaterThanOrEqualTo: latitude - latDelta)
          .where('location.latitude', isLessThanOrEqualTo: latitude + latDelta)
          .where('location.longitude', isGreaterThanOrEqualTo: longitude - lonDelta)
          .where('location.longitude', isLessThanOrEqualTo: longitude + lonDelta)
          .limit(_limit);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();
      print('Found ${snapshot.docs.length} users with shareLocation: true');

      List<UserModel> users = [];
      final distanceCalculator = const latlong.Distance();

      for (var doc in snapshot.docs) {
        if (doc.id == currentUserId) {
          print('Skipping current user: ${doc.id}');
          continue;
        }

        try {
          final rawData = {...doc.data(), 'uid': doc.id};
          final user = UserModel.fromMap(rawData);
          print(
            'Parsed user: ${user.uid}, '
            'Location: ${user.location?.latitude}, ${user.location?.longitude}, '
            'ShareLocation: ${user.shareLocation}, '
            'VisibilityRadius: ${user.visibilityRadius}',
          );

          if (user.location != null) {
            final distance = distanceCalculator(
                  latlong.LatLng(latitude, longitude),
                  latlong.LatLng(user.location!.latitude, user.location!.longitude),
                ) /
                1000; // Convert meters to kilometers
            print('Distance to ${user.uid}: $distance km');

            final effectiveRadius = user.visibilityRadius ?? radiusKm;
            if (distance <= effectiveRadius && distance <= radiusKm) {
              users.add(user.copyWith());
            } else {
              print('User ${user.uid} outside radius: $distance km > $effectiveRadius km');
            }
          } else {
            print('User ${user.uid} has no location, skipping');
          }
        } catch (e, stackTrace) {
          print('Error parsing user ${doc.id}: $e\n$stackTrace');
        }
      }

      _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      _hasMoreUsers = snapshot.docs.length == _limit;
      _discoveredUsers = _lastDocument == null ? users : [..._discoveredUsers, ...users];

      _discoveredUsers.sort((a, b) {
        final distA = distanceCalculator(
          latlong.LatLng(latitude, longitude),
          latlong.LatLng(a.location!.latitude, a.location!.longitude),
        );
        final distB = distanceCalculator(
          latlong.LatLng(latitude, longitude),
          latlong.LatLng(b.location!.latitude, b.location!.longitude),
        );
        return distA.compareTo(distB);
      });
      print('Fetched ${_discoveredUsers.length} nearby users, hasMore: $_hasMoreUsers');

      _clearError();
    } catch (e, stackTrace) {
      print('Error fetching users: $e\n$stackTrace');
      _setError('Failed to discover nearby users: $e');
    } finally {
      _setLoading(false);
    }
  }

  void resetUsers() {
    _discoveredUsers = [];
    _lastDocument = null;
    _hasMoreUsers = true;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}