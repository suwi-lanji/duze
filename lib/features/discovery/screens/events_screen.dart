import 'package:duze/features/auth/providers/auth_provider.dart';
import 'package:duze/features/discovery/models/event_model.dart';
import 'package:duze/features/location/providers/location_provider.dart';
import 'package:duze/features/discovery/screens/create_event_screen.dart';
import 'package:duze/features/discovery/screens/event_details_screen.dart';
import 'package:duze/shared/widgets/app_colors.dart';
import 'package:duze/shared/widgets/custom_app_bar.dart';
import 'package:duze/shared/widgets/custom_button.dart';
import 'package:duze/shared/widgets/custom_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../providers/discovery_provider.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  double _searchRadius = 100.0; // Default radius in kilometers

  @override
  Widget build(BuildContext context) {
    final discoveryProvider = Provider.of<DiscoveryProvider>(context);
    final locationProvider = Provider.of<LocationProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final distanceCalculator = const latlong.Distance();

    return Scaffold(
      appBar: const CustomAppBar(),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.profileGradient),
        child: RefreshIndicator(
          onRefresh: () => _refreshEvents(context, discoveryProvider, locationProvider, authProvider),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Events Near You',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.buttoncolor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: 'Create New Event',
                        gradient: AppColors.buttonGradient,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CreateEventScreen()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<double>(
                      value: _searchRadius,
                      items: const [
                        DropdownMenuItem(value: 50.0, child: Text('50 km')),
                        DropdownMenuItem(value: 100.0, child: Text('100 km')),
                        DropdownMenuItem(value: 500.0, child: Text('500 km')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _searchRadius = value);
                          _refreshEvents(context, discoveryProvider, locationProvider, authProvider);
                        }
                      },
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.black),
                      dropdownColor: AppColors.white,
                      underline: const SizedBox(),
                    ),
                  ],
                ).animate().fadeIn(duration: 500.ms),
                const SizedBox(height: 16),
                if (discoveryProvider.isLoading || locationProvider.isLoading)
                  _buildEventLoadingCard()
                else if (!locationProvider.hasPermission)
                  CustomCard(
                    glassEffect: true,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(Icons.location_off, size: 48, color: AppColors.grey600),
                        const SizedBox(height: 8),
                        Text(
                          locationProvider.errorMessage ?? 'Location permission required',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.black),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () async {
                            await locationProvider.initializeLocation();
                            if (locationProvider.hasPermission && locationProvider.currentPosition != null) {
                              await _refreshEvents(context, discoveryProvider, locationProvider, authProvider);
                            } else {
                              final permission = await Geolocator.checkPermission();
                              if (permission == LocationPermission.deniedForever) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Location permission permanently denied. Please enable in settings.'),
                                    ),
                                  );
                                  await Geolocator.openAppSettings();
                                }
                              } else {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please grant location permissions')),
                                  );
                                }
                              }
                            }
                          },
                          child: const Text('Request Permission'),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 200.ms)
                else if (locationProvider.currentPosition == null)
                  CustomCard(
                    glassEffect: true,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(Icons.location_off, size: 48, color: AppColors.grey600),
                        const SizedBox(height: 8),
                        Text(
                          'Unable to get location',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.black),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () async {
                            await locationProvider.initializeLocation();
                            if (locationProvider.currentPosition != null) {
                              await _refreshEvents(context, discoveryProvider, locationProvider, authProvider);
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enable location services')),
                                );
                              }
                            }
                          },
                          child: const Text('Retry Location'),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 200.ms)
                else if (discoveryProvider.nearbyEvents.isEmpty)
                  CustomCard(
                    glassEffect: true,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(Icons.event_busy, size: 48, color: AppColors.grey600),
                        const SizedBox(height: 8),
                        Text(
                          'No events within $_searchRadius km',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.black),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => _refreshEvents(context, discoveryProvider, locationProvider, authProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 200.ms)
                else
                  Column(
                    children: discoveryProvider.nearbyEvents.map((event) {
                      final distance = locationProvider.currentPosition != null
                          ? distanceCalculator(
                              latlong.LatLng(
                                locationProvider.currentPosition!.latitude,
                                locationProvider.currentPosition!.longitude,
                              ),
                              latlong.LatLng(event.latitude, event.longitude),
                            ) /
                              1000
                          : null;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: CustomCard(
                          glassEffect: true,
                          padding: const EdgeInsets.all(16),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primaryTeal.withOpacity(0.1),
                              child: const Icon(Icons.event, color: AppColors.primaryTeal),
                            ),
                            title: Text(
                              event.title,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppColors.buttoncolor,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            subtitle: Text(
                              event.address,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.black),
                            ),
                            trailing: Text(
                              distance != null ? '${distance.toStringAsFixed(1)} km' : 'N/A',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.black,
                                    fontSize: 12,
                                  ),
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EventDetailsScreen(event: event),
                              ),
                            ),
                          ),
                        ),
                      ).animate().fadeIn(duration: 500.ms, delay: 200.ms);
                    }).toList(),
                  ),
                if (discoveryProvider.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      discoveryProvider.errorMessage!,
                      style: const TextStyle(color: AppColors.accentRed, fontSize: 14),
                    ),
                  ).animate().fadeIn(duration: 300.ms),
                if (locationProvider.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      locationProvider.errorMessage!,
                      style: const TextStyle(color: AppColors.accentRed, fontSize: 14),
                    ),
                  ).animate().fadeIn(duration: 300.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshEvents(
    BuildContext context,
    DiscoveryProvider discoveryProvider,
    LocationProvider locationProvider,
    AuthProvider authProvider,
  ) async {
    // Log initial state
    print('onRefresh triggered at ${DateTime.now()}');
    print('Current user: ${authProvider.currentUser?.uid ?? "null"}');
    print('Current position: ${locationProvider.currentPosition?.latitude ?? "null"}, ${locationProvider.currentPosition?.longitude ?? "null"}');
    print('Has permission: ${locationProvider.hasPermission}');
    print('Search radius: $_searchRadius km');

    if (!locationProvider.hasPermission) {
      print('No location permission, attempting to initialize');
      await locationProvider.initializeLocation();
      if (!locationProvider.hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission required to find events')),
          );
        }
        return;
      }
    }

    if (locationProvider.currentPosition == null) {
      print('Location not available, using fallback coordinates');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location unavailable, using default coordinates')),
        );
      }
    }

    if (authProvider.currentUser == null) {
      print('User not logged in, proceeding with empty user ID');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in for personalized events')),
        );
      }
    }

    try {
      // Use fallback coordinates if location is unavailable
      final latitude = locationProvider.currentPosition?.latitude ?? -15.3262018;
      final longitude = locationProvider.currentPosition?.longitude ?? 28.6722283;
      final userId = authProvider.currentUser?.uid ?? '';
      final friends = authProvider.currentUser?.friends ?? [];

      print('Calling loadNearbyEvents with ($latitude, $longitude), radius: $_searchRadius km, userId: $userId');
      await discoveryProvider.loadNearbyEvents(
        latitude,
        longitude,
        _searchRadius,
        userId,
        friends,
      );
      print('Loaded ${discoveryProvider.nearbyEvents.length} events');
    } catch (e, stackTrace) {
      print('Error in onRefresh: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to refresh events: $e')),
        );
      }
    }
  }

  Widget _buildEventLoadingCard() {
    return CustomCard(
      glassEffect: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: double.infinity, height: 20, color: AppColors.grey600.withOpacity(0.3)),
          const SizedBox(height: 8),
          Container(width: double.infinity, height: 16, color: AppColors.grey600.withOpacity(0.3)),
          const SizedBox(height: 8),
          Container(width: 100, height: 16, color: AppColors.grey600.withOpacity(0.3)),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }
}