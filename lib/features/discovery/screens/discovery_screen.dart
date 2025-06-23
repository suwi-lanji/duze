import 'package:duze/shared/widgets/app_colors.dart';
import 'package:duze/shared/widgets/custom_app_bar.dart';
import 'package:duze/shared/widgets/custom_card.dart';
import 'package:duze/shared/widgets/user_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/discovery_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../location/providers/location_provider.dart';
import '../../map/screens/map_screen.dart';
import '../../../config/routes.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  DiscoveryScreenState createState() => DiscoveryScreenState();
}

class DiscoveryScreenState extends State<DiscoveryScreen> {
  double _radiusFilter = 5.0;
  static const double _maxRadius = 100.0;
  static const double _allRadius = 101.0;
  bool _isInitializing = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateLocationAndLoadData();
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !Provider.of<DiscoveryProvider>(context, listen: false).isLoading &&
        Provider.of<DiscoveryProvider>(context, listen: false).hasMoreUsers) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      final discoveryProvider = Provider.of<DiscoveryProvider>(context, listen: false);
      if (authProvider.currentUser != null && locationProvider.currentPosition != null) {
        discoveryProvider.discoverNearbyUsers(
          authProvider.currentUser!.uid,
          locationProvider.currentPosition!.latitude,
          locationProvider.currentPosition!.longitude,
          _radiusFilter == _allRadius ? double.infinity : _radiusFilter,
        );
      }
    }
  }

  Future<void> _updateLocationAndLoadData({bool reset = true}) async {
    if (!mounted) return;
    setState(() => _isInitializing = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final discoveryProvider = Provider.of<DiscoveryProvider>(context, listen: false);

    try {
      print('Initializing location for DiscoveryScreen');
      await locationProvider.initializeLocation();

      if (authProvider.currentUser == null) {
        print('User not authenticated, redirecting to login');
        Navigator.pushReplacementNamed(context, AppRoutes.login);
        return;
      }

      if (locationProvider.currentPosition == null) {
        print('No location available');
        // discoveryProvider.setError('Location unavailable. Please enable location services.');
        return;
      }

      print('Updating user location for UID: ${authProvider.currentUser!.uid}');
      await locationProvider.updateUserLocation(authProvider.currentUser!.uid);
      print(
          'Loading discovery data at ${locationProvider.currentPosition!.latitude}, ${locationProvider.currentPosition!.longitude}');

      if (reset) {
        discoveryProvider.resetUsers();
      }

      await discoveryProvider.discoverNearbyUsers(
        authProvider.currentUser!.uid,
        locationProvider.currentPosition!.latitude,
        locationProvider.currentPosition!.longitude,
        _radiusFilter == _allRadius ? double.infinity : _radiusFilter,
      );
    } catch (e, stackTrace) {
      print('Error loading discovery data: $e\n$stackTrace');
      // discoveryProvider._setError('Failed to load data: $e');
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final discoveryProvider = Provider.of<DiscoveryProvider>(context);
    final mediaQuery = MediaQuery.of(context);

    return Scaffold(
      appBar: const CustomAppBar(),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.profileGradient),
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () => _updateLocationAndLoadData(reset: true),
              color: AppColors.primaryTeal,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(mediaQuery.size.width * 0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRadiusFilter(mediaQuery),
                    SizedBox(height: mediaQuery.size.height * 0.03),
                    Text(
                      'People Nearby',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                    ).animate().fadeIn(
                        duration: const Duration(milliseconds: 600), delay: 100.ms),
                    SizedBox(height: mediaQuery.size.height * 0.02),
                    _buildUserList(discoveryProvider),
                    if (discoveryProvider.isLoading && !_isInitializing)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child:
                            Center(child: CircularProgressIndicator(color: AppColors.primaryTeal)),
                      ),
                    if (!discoveryProvider.hasMoreUsers &&
                        discoveryProvider.discoveredUsers.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: Text('No more users to load')),
                      ),
                  ],
                ),
              ),
            ),
            if (_isInitializing)
              Container(
                color: AppColors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.white),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MapScreen()),
          );
        },
        backgroundColor: AppColors.primaryTeal,
        elevation: 6,
        tooltip: 'View Map',
        child: const Icon(Icons.map, color: AppColors.white, size: 28),
      ).animate().scale(
          duration: const Duration(milliseconds: 600),
          delay: 700.ms,
          curve: Curves.easeOutBack),
    );
  }

  Widget _buildRadiusFilter(MediaQueryData mediaQuery) {
    return CustomCard(
      glassEffect: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Discovery Radius',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
              ),
              Text(
                _radiusFilter == _allRadius
                    ? 'All'
                    : _radiusFilter <= 5
                        ? '${_radiusFilter.toStringAsFixed(1)} km'
                        : '${_radiusFilter.toStringAsFixed(0)} km',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.primaryTeal,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
              activeTrackColor: AppColors.primaryTeal,
              inactiveTrackColor: AppColors.grey600.withOpacity(0.3),
              thumbColor: AppColors.white,
              overlayColor: AppColors.primaryTeal.withOpacity(0.2),
            ),
            child: Slider(
              value: _radiusFilter,
              min: 2.0,
              max: _allRadius,
              divisions: 99,
              label: _radiusFilter == _allRadius
                  ? 'All'
                  : _radiusFilter <= 5
                      ? '${_radiusFilter.toStringAsFixed(1)} km'
                      : '${_radiusFilter.toStringAsFixed(0)} km',
              onChanged: (value) {
                setState(() {
                  _radiusFilter = value;
                  _updateLocationAndLoadData();
                });
              },
            ),
          ).animate()
              .slideY(begin: 0.2, end: 0, duration: const Duration(milliseconds: 600)),
        ],
      ),
    ).animate().fadeIn(duration: const Duration(milliseconds: 600));
  }

  Widget _buildUserList(DiscoveryProvider discoveryProvider) {
    if (_isInitializing) {
      return const SizedBox.shrink();
    } else if (discoveryProvider.errorMessage != null) {
      return CustomCard(
        glassEffect: true,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.accentRed),
              const SizedBox(height: 12),
              Text(
                discoveryProvider.errorMessage!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.accentRed,
                      fontSize: 16,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _updateLocationAndLoadData(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(duration: const Duration(milliseconds: 400));
    } else if (discoveryProvider.discoveredUsers.isEmpty) {
      return CustomCard(
        glassEffect: true,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.people_outline, size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              Text(
                'No one found nearby',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Try increasing the radius or check back later.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.grey600,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ).animate().fadeIn(duration: const Duration(milliseconds: 400));
    } else {
      return Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final locationProvider = Provider.of<LocationProvider>(context, listen: false);
          final currentPosition = locationProvider.currentPosition;
          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: discoveryProvider.discoveredUsers.length,
            itemBuilder: (context, index) {
              final user = discoveryProvider.discoveredUsers[index];

              String distance = 'Unknown';
              if (user.location != null && currentPosition != null) {
                final distMeters = latlong.Distance().as(
                  latlong.LengthUnit.Meter,
                  latlong.LatLng(currentPosition.latitude, currentPosition.longitude),
                  latlong.LatLng(user.location!.latitude, user.location!.longitude),
                );
                if (distMeters < 1000) {
                  distance = '${distMeters.toStringAsFixed(0)}m';
                } else {
                  distance = '${(distMeters / 1000).toStringAsFixed(1)}km';
                }
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: UserCard(
                  user: user,
                  showDistance: true,
                  distance: distance,
                  mutualConnections: [],
                  onTap: () {
  if (user == null || user.uid.isEmpty) {
    print('Error: Invalid UserModel - UID: ${user?.uid}, DisplayName: ${user?.displayName}');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Error: Invalid user data')),
    );
    return;
  }
  print('Navigating to ViewUserProfileScreen for user: ${user.uid}, ${user.displayName}');
  Navigator.pushNamed(
    context,
    AppRoutes.userProfile,
    arguments: user,
  );
},
                  onConnect: () async {
                    try {
                      await FirebaseFirestore.instance
                          .collection('relationships')
                          .doc(user.uid)
                          .update({
                        'pendingConnections':
                            FieldValue.arrayUnion([authProvider.currentUser!.uid]),
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Connect request sent')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to send request: $e')),
                      );
                    }
                  },
                ),
              ).animate().slideY(
                    begin: 0.3,
                    end: 0,
                    duration: const Duration(milliseconds: 600),
                    delay: (index * 150).ms,
                    curve: Curves.easeOutQuad,
                  );
            },
          );
        },
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}