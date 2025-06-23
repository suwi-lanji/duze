import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  static const LocationSettings locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10, // Update every 10 meters
  );

  Future<bool> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    
    return permission == LocationPermission.whileInUse || 
           permission == LocationPermission.always;
  }

  Future<Position?> getCurrentLocation() async {
    try {
      bool hasPermission = await requestLocationPermission();
      if (!hasPermission) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  Future<void> updateUserLocation(String uid, Position position) async {
    try {
      final locationData = UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        lastUpdated: DateTime.now(),
      );

      await _firestore.collection('users').doc(uid).update({
        'location': locationData.toMap(),
      });
    } catch (e) {
      print('Error updating location: $e');
    }
  }

  Future<List<UserModel>> getNearbyUsers(
    Position userPosition, 
    double radiusInKm,
    String currentUserId,
  ) async {
    try {
      // Get all users with location data
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('shareLocation', isEqualTo: true)
          .get();

      List<UserModel> nearbyUsers = [];

      for (QueryDocumentSnapshot doc in snapshot.docs) {
        if (doc.id == currentUserId) continue; // Skip current user
        
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        UserModel user = UserModel.fromMap(data);
        
        if (user.location != null) {
          double distance = Geolocator.distanceBetween(
            userPosition.latitude,
            userPosition.longitude,
            user.location!.latitude,
            user.location!.longitude,
          ) / 1000; // Convert to kilometers

          if (distance <= radiusInKm) {
            nearbyUsers.add(user);
          }
        }
      }

      // Sort by distance
      nearbyUsers.sort((a, b) {
        double distanceA = Geolocator.distanceBetween(
          userPosition.latitude,
          userPosition.longitude,
          a.location!.latitude,
          a.location!.longitude,
        );
        double distanceB = Geolocator.distanceBetween(
          userPosition.latitude,
          userPosition.longitude,
          b.location!.latitude,
          b.location!.longitude,
        );
        return distanceA.compareTo(distanceB);
      });

      return nearbyUsers;
    } catch (e) {
      print('Error getting nearby users: $e');
      return [];
    }
  }

  double calculateDistance(Position pos1, UserLocation pos2) {
    return Geolocator.distanceBetween(
      pos1.latitude,
      pos1.longitude,
      pos2.latitude,
      pos2.longitude,
    ) / 1000; // Convert to kilometers
  }
}
