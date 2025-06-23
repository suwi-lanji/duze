import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:duze/core/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationProvider extends ChangeNotifier {
  Position? _currentPosition;
  DateTime? _lastUpdated; // Add this field
  bool _hasPermission = false;
  bool _isLoading = false;
  String? _errorMessage;

  Position? get currentPosition => _currentPosition;
  DateTime? get lastUpdated => _lastUpdated; // Add getter
  bool get hasPermission => _hasPermission;
  bool get isLoading => _isLoading;
  LocationProvider() {
    _loadCachedLocation();
  }

  get errorMessage => null;

  Future<void> _loadCachedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final latitude = prefs.getDouble('last_latitude');
    final longitude = prefs.getDouble('last_longitude');
    final lastUpdatedMs = prefs.getInt('last_updated'); // Load cached lastUpdated
    if (latitude != null && longitude != null) {
      _currentPosition = Position(
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
      if (lastUpdatedMs != null) {
        _lastUpdated = DateTime.fromMillisecondsSinceEpoch(lastUpdatedMs);
      }
      print('Loaded cached location: $latitude, $longitude, lastUpdated: $_lastUpdated');
      notifyListeners();
    }
  }

  Future<void> _cacheLocation(Position position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('last_latitude', position.latitude);
    await prefs.setDouble('last_longitude', position.longitude);
    await prefs.setInt('last_updated', DateTime.now().millisecondsSinceEpoch); // Cache lastUpdated
    print('Cached location: ${position.latitude}, ${position.longitude}, lastUpdated: ${DateTime.now()}');
  }

  Future<void> initializeLocation() async {
    if (_isLoading) return;
    _setLoading(true);
    try {
      print('Checking location permission...');
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setError('Location services are disabled');
        _hasPermission = false;
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _setError('Location permission denied');
          _hasPermission = false;
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _setError('Location permission permanently denied');
        _hasPermission = false;
        return;
      }

      print('Getting current position');
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _lastUpdated = DateTime.now(); // Set lastUpdated
      await _cacheLocation(_currentPosition!);
      _hasPermission = true;
      _clearError();

      // Start listening for location updates
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(
        (Position position) {
          print('Location updated: ${position.latitude}, ${position.longitude}');
          _currentPosition = position;
          _lastUpdated = DateTime.now(); // Update lastUpdated
          _cacheLocation(position);
          notifyListeners();
        },
        onError: (e) {
          print('Location stream error: $e');
          _setError('Location update failed: $e');
        },
      );
    } catch (e) {
      print('Error initializing location: $e');
      _setError('Failed to get location: $e');
      _hasPermission = false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateUserLocation(String uid) async {
    if (_currentPosition == null) {
      print('Cannot update user location: currentPosition is null');
      _setError('No location available');
      return;
    }

    try {
      print('Updating user location in Firestore for UID: $uid');
      _lastUpdated = DateTime.now(); // Update local lastUpdated
      final userLocation = UserLocation(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        lastUpdated: _lastUpdated!,
      );

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'location': userLocation.toMap(),
        'shareLocation': true,
      });
      await _cacheLocation(_currentPosition!); // Ensure cache is updated
      print('User location updated successfully');
    } catch (e) {
      print('Error updating user location: $e');
      _setError('Failed to update location: $e');
    }
  }

  void stopLocationUpdates() {
    print('Stopping location updates');
    _currentPosition = null;
    _lastUpdated = null; // Clear lastUpdated
    _hasPermission = false;
    _errorMessage = null;
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