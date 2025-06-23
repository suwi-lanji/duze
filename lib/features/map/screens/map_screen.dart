import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:provider/provider.dart';
import 'package:geocoding/geocoding.dart';
import '../../auth/providers/auth_provider.dart';
import '../../discovery/providers/discovery_provider.dart';
import '../../location/providers/location_provider.dart';
import '../../../core/models/user_model.dart';
import '../../../config/routes.dart';
import '../../../shared/widgets/app_colors.dart';
import 'dart:math' as math;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  String _selectedMapStyle = 'openstreetmap';
  final List<String> _mapStyles = ['openstreetmap', 'opentopomap'];
  String _searchQuery = '';
  bool _isSearching = false;
  bool _isTileLoading = false;
  double _currentZoom = 18.0;
  bool _isMapReady = false;

  final Map<String, Map<String, dynamic>> _mapStyleConfigs = {
    'openstreetmap': {
      'url': 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
      'maxZoom': 20.0,
      'subdomains': ['a', 'b', 'c'],
    },
    'opentopomap': {
      'url': 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
      'maxZoom': 18.0,
      'subdomains': ['a', 'b', 'c'],
    },
  };

  @override
  void initState() {
    super.initState();
  }

  void _onMapReady() {
    if (mounted) {
      setState(() {
        _isMapReady = true;
        _currentZoom = _mapController.zoom;
      });
    }
  }

  Future<String?> _getPlaceName(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        return placemark.name ??
            placemark.subLocality ??
            placemark.locality ??
            placemark.administrativeArea ??
            'Unknown';
      }
    } catch (e) {
      print('Geocoding error: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final locationProvider = Provider.of<LocationProvider>(context);
    final discoveryProvider = Provider.of<DiscoveryProvider>(context);

    final userLocation = authProvider.currentUser?.location;
    final currentPosition = locationProvider.currentPosition;

    final center = currentPosition != null
        ? latlong.LatLng(currentPosition.latitude, currentPosition.longitude)
        : userLocation != null
            ? latlong.LatLng(userLocation.latitude, userLocation.longitude)
            : latlong.LatLng(-33.9249, 18.4241);

    final clusteredMarkers =
        _clusterUsers(discoveryProvider.discoveredUsers, locationProvider, _searchQuery, _currentZoom);

    final selectedStyle = _mapStyleConfigs[_selectedMapStyle]!;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Nearby Users',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black54, Colors.transparent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: AppColors.textPrimary),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchQuery = '';
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.layers, color: AppColors.textPrimary),
            onSelected: (value) {
              setState(() {
                _selectedMapStyle = value;
                _currentZoom =
                    _currentZoom.clamp(8.0, _mapStyleConfigs[value]!['maxZoom'] as double);
              });
            },
            itemBuilder: (context) => _mapStyles
                .map((style) => PopupMenuItem(
                      value: style,
                      child: Text(
                        style == 'openstreetmap' ? 'Street Map' : 'Topographic Map',
                        style: const TextStyle(fontFamily: 'Poppins'),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.profileGradient),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                center: center,
                zoom: _currentZoom,
                minZoom: 8.0,
                maxZoom: selectedStyle['maxZoom'] as double,
                interactiveFlags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                onTap: (_, point) {
                  _mapController.move(point, _currentZoom);
                },
                onMapReady: _onMapReady,
                onMapEvent: (event) {
                  if (event is MapEventMoveStart || event is MapEventFlingAnimationStart) {
                    setState(() => _isTileLoading = true);
                  } else if (event is MapEventMoveEnd || event is MapEventFlingAnimationEnd) {
                    setState(() {
                      _isTileLoading = false;
                      if (_isMapReady) _currentZoom = _mapController.zoom;
                    });
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: selectedStyle['url'] as String,
                  subdomains: selectedStyle['subdomains'] as List<String>,
                  maxZoom: selectedStyle['maxZoom'] as double,
                ),
                MarkerLayer(
                  markers: [
                    if (userLocation != null && authProvider.currentUser != null)
                      Marker(
                        point: latlong.LatLng(userLocation.latitude, userLocation.longitude),
                        width: 60,
                        height: 60,
                        builder: (ctx) => GestureDetector(
                          onTap: () {
                            _showUserDialog(context, authProvider.currentUser!, isCurrentUser: true);
                          },
                          child: _buildUserMarker(
                            authProvider.currentUser!.photoURL,
                            authProvider.currentUser!.displayName,
                            isCurrentUser: true,
                          ),
                        ),
                      ),
                    ...clusteredMarkers.map((marker) => Marker(
                          point: marker.point,
                          width: 60,
                          height: 60,
                          builder: (ctx) => GestureDetector(
                            onTap: () {
                              if (marker.users.length == 1) {
                                _showUserDialog(context, marker.users.first);
                              } else {
                                _showClusterDialog(context, marker.users);
                              }
                            },
                            child: _buildClusterMarker(marker),
                          ),
                        )),
                  ],
                ),
              ],
            ),
            if (_isSearching)
              Positioned(
                top: 80,
                left: 16,
                right: 16,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    filled: true,
                    fillColor: AppColors.white.withOpacity(0.9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.search, color: AppColors.primaryTeal),
                  ),
                  style: const TextStyle(fontFamily: 'Poppins'),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ).animate().fadeIn(duration: 300.ms),
            if (_isTileLoading)
              const Positioned(
                top: 120,
                left: 16,
                child: CircularProgressIndicator(
                  color: AppColors.primaryTeal,
                  strokeWidth: 2,
                ),
              ),
            Positioned(
              right: 16,
              bottom: 16,
              child: Column(
                children: [
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: AppColors.white,
                    child: const Icon(Icons.add, color: AppColors.primaryTeal),
                    onPressed: () {
                      _zoomMap(_currentZoom + 0.1);
                    },
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: AppColors.white,
                    child: const Icon(Icons.remove, color: AppColors.primaryTeal),
                    onPressed: () {
                      _zoomMap(_currentZoom - 0.1);
                    },
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: AppColors.white,
                    child: const Icon(Icons.my_location, color: AppColors.primaryTeal),
                    onPressed: () {
                      _mapController.move(center, 18.0);
                      setState(() => _currentZoom = 18.0);
                    },
                  ),
                ],
              ).animate().slideY(begin: 0.2, end: 0, duration: 300.ms),
            ),
          ],
        ),
      ),
    );
  }

  void _zoomMap(double newZoom) {
    final maxZoom = _mapStyleConfigs[_selectedMapStyle]!['maxZoom'] as double;
    final clampedZoom = newZoom.clamp(8.0, maxZoom);
    _mapController.move(_mapController.center, clampedZoom);
    setState(() => _currentZoom = clampedZoom);
  }

  Widget _buildUserMarker(String photoURL, String displayName, {bool isCurrentUser = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isCurrentUser ? AppColors.primaryTeal : AppColors.accentRed,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            isCurrentUser
                ? 'Me'
                : displayName.length > 10
                    ? '${displayName.substring(0, 10)}...'
                    : displayName,
            style: const TextStyle(
              fontFamily: 'Poppins',
              color: AppColors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),
        Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.location_pin,
              size: 30,
              color: isCurrentUser ? AppColors.primaryTeal : AppColors.accentRed,
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 1.5),
              ),
              child: CircleAvatar(
                radius: 10,
                backgroundImage: photoURL.isNotEmpty ? CachedNetworkImageProvider(photoURL) : null,
                child: photoURL.isEmpty
                    ? const Icon(Icons.person, size: 10, color: AppColors.textSecondary)
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildClusterMarker(_ClusterMarker marker) {
    final isCluster = marker.users.length > 1;
    final displayName = isCluster ? '${marker.users.length} Users' : marker.users.first.displayName;
    final photoURL = isCluster ? '' : marker.users.first.photoURL;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isCluster ? AppColors.accentYellow : AppColors.accentRed,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            displayName.length > 10 ? '${displayName.substring(0, 10)}...' : displayName,
            style: const TextStyle(
              fontFamily: 'Poppins',
              color: AppColors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),
        Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.location_pin,
              size: 30,
              color: isCluster ? AppColors.accentYellow : AppColors.accentRed,
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 1.5),
              ),
              child: CircleAvatar(
                radius: 10,
                backgroundImage: photoURL.isNotEmpty ? CachedNetworkImageProvider(photoURL) : null,
                child: photoURL.isEmpty
                    ? const Icon(Icons.person, size: 10, color: AppColors.textSecondary)
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showClusterDialog(BuildContext context, List<UserModel> users) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Clustered Users',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundImage:
                            user.photoURL.isNotEmpty ? CachedNetworkImageProvider(user.photoURL) : null,
                        child: user.photoURL.isEmpty
                            ? const Icon(Icons.person, size: 20, color: AppColors.textSecondary)
                            : null,
                      ),
                      title: Text(
                        user.displayName,
                        style: const TextStyle(fontFamily: 'Poppins'),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _showUserDialog(context, user);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUserDialog(BuildContext context, UserModel user, {bool isCurrentUser = false}) {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);

    final distance = user.location != null && locationProvider.currentPosition != null
        ? latlong.Distance().as(
            latlong.LengthUnit.Kilometer,
            latlong.LatLng(
              locationProvider.currentPosition!.latitude,
              locationProvider.currentPosition!.longitude,
            ),
            latlong.LatLng(
              user.location!.latitude,
              user.location!.longitude,
            ),
          )
        : null;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: isCurrentUser
                            ? [AppColors.primaryTeal, AppColors.accentTeal]
                            : [AppColors.accentRed, AppColors.accentRed.withOpacity(0.8)],
                      ),
                    ),
                  ),
                  CircleAvatar(
                    radius: 36,
                    backgroundImage:
                        user.photoURL.isNotEmpty ? CachedNetworkImageProvider(user.photoURL) : null,
                    child: user.photoURL.isEmpty
                        ? const Icon(Icons.person, size: 36, color: AppColors.textSecondary)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                user.displayName,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                user.email?.isNotEmpty == true ? user.email! : 'No email provided',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              if (user.location != null)
                FutureBuilder<String?>(
                  future: _getPlaceName(user.location!.latitude, user.location!.longitude),
                  builder: (context, snapshot) {
                    final placeName = snapshot.data ?? 'Unknown';
                    final distanceText = distance != null
                        ? distance < 1
                            ? '${(distance * 1000).toStringAsFixed(0)}m'
                            : '${distance.toStringAsFixed(1)}km'
                        : 'Unknown';
                    return Text(
                      '$placeName (${distanceText})',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    );
                  },
                )
              else
                const Text(
                  'Location: Unknown',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'Joined: ${user.createdAt.toLocal().toString().split(' ')[0]}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              if (user.socialAccounts.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: user.socialAccounts.keys.map((platform) {
                    return Chip(
                      label: Text(
                        platform.capitalize(),
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 12),
                      ),
                      backgroundColor: _getPlatformColor(platform),
                      labelStyle: const TextStyle(color: AppColors.white),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (!isCurrentUser)
                    ElevatedButton(
                      onPressed: () {
                        print(
                            'Navigating to ViewUserProfileScreen for user: ${user.uid}, ${user.displayName}');
                        Navigator.pop(context);
                        Navigator.pushNamed(context, AppRoutes.userProfile, arguments: user);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryTeal,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text(
                        'View Profile',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: AppColors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPlatformColor(String platform) {
    switch (platform.toLowerCase()) {
      case 'facebook':
        return AppColors.facebookBlue;
      case 'twitter':
        return AppColors.twitterBlue;
      case 'tiktok':
        return AppColors.tiktokBlack;
      default:
        return AppColors.grey600;
    }
  }

  double _calculateDistance(UserModel user, LocationProvider locationProvider) {
    if (user.location == null || locationProvider.currentPosition == null) return double.infinity;
    return latlong.Distance().as(
          latlong.LengthUnit.Kilometer,
          latlong.LatLng(
            locationProvider.currentPosition!.latitude,
            locationProvider.currentPosition!.longitude,
          ),
          latlong.LatLng(user.location!.latitude, user.location!.longitude),
        );
  }

  List<_ClusterMarker> _clusterUsers(
    List<UserModel> users,
    LocationProvider locationProvider,
    String searchQuery,
    double zoom,
  ) {
    final maxMarkers = zoom > 18 ? 20 : 50;
    final clusterRadius = zoom > 18 ? 5.0 : 20.0;
    final distanceCalculator = const latlong.Distance();

    final filteredUsers = searchQuery.isEmpty
        ? users
        : users.where((user) =>
            user.displayName.toLowerCase().contains(searchQuery.toLowerCase()) ||
            (user.location != null &&
                user.shareLocation &&
                user.shareConnections &&
                _calculateDistance(user, locationProvider) < 10));

    final clusters = <_ClusterMarker>[];
    final processedUids = <String>{};

    for (final user in filteredUsers.take(maxMarkers)) {
      if (user.location == null ||
          !user.shareLocation ||
          !user.shareConnections ||
          processedUids.contains(user.uid)) {
        continue;
      }

      final userPoint = latlong.LatLng(user.location!.latitude, user.location!.longitude);
      final clusterUsers = [user];
      processedUids.add(user.uid);

      for (final otherUser in filteredUsers) {
        if (otherUser.uid == user.uid ||
            otherUser.location == null ||
            processedUids.contains(otherUser.uid)) {
          continue;
        }
        final otherPoint = latlong.LatLng(otherUser.location!.latitude, otherUser.location!.longitude);
        final distance = distanceCalculator(userPoint, otherPoint);
        if (distance <= clusterRadius) {
          clusterUsers.add(otherUser);
          processedUids.add(otherUser.uid);
        }
      }

      double latSum = 0;
      double lonSum = 0;
      for (final u in clusterUsers) {
        latSum += u.location!.latitude;
        lonSum += u.location!.longitude;
      }
      final clusterPoint = latlong.LatLng(latSum / clusterUsers.length, lonSum / clusterUsers.length);

      final jitter =
          clusterUsers.length == 1 ? 0.00001 * (math.Random().nextDouble() - 0.5) : 0.0;
      final jitteredPoint = latlong.LatLng(
        clusterPoint.latitude + jitter,
        clusterPoint.longitude + jitter,
      );

      clusters.add(_ClusterMarker(point: jitteredPoint, users: clusterUsers));
    }

    return clusters;
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}

class _ClusterMarker {
  final latlong.LatLng point;
  final List<UserModel> users;

  _ClusterMarker({required this.point, required this.users});
}

extension StringExtension on String {
  String capitalize() => "${this[0].toUpperCase()}${substring(1)}";
}