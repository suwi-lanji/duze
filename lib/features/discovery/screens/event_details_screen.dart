// lib/features/discovery/screens/event_details_screen.dart
import 'package:duze/features/auth/providers/auth_provider.dart';
import 'package:duze/features/discovery/models/event_model.dart';
import 'package:duze/features/discovery/providers/discovery_provider.dart';
import 'package:duze/features/location/providers/location_provider.dart';
import 'package:duze/shared/widgets/app_colors.dart';
import 'package:duze/shared/widgets/custom_button.dart';
import 'package:duze/shared/widgets/custom_card.dart';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as latlong;

import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';


class EventDetailsScreen extends StatelessWidget {
  final EventModel event;

  const EventDetailsScreen({super.key, required this.event});

  Future<void> _launchGoogleMaps(double lat, double lng) async {
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch Google Maps';
    }
  }

  @override
  Widget build(BuildContext context) {
    final discoveryProvider = Provider.of<DiscoveryProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final locationProvider = Provider.of<LocationProvider>(context);
    final distanceCalculator = const latlong.Distance();
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

    return Scaffold(
      appBar: AppBar(
        title: Text(event.title, style: const TextStyle(color: AppColors.buttoncolor)),
        backgroundColor: AppColors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.profileGradient),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomCard(
                glassEffect: true,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.buttoncolor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      event.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.black),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Category: ${event.category}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.black),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'When: ${event.startTime.toLocal().toString().split('.')[0]}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.black),
                    ),
                    if (event.endTime != null)
                      Text(
                        'Until: ${event.endTime!.toLocal().toString().split('.')[0]}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.black),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Where: ${event.address}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.black),
                    ),
                    if (distance != null)
                      Text(
                        'Distance: ${distance.toStringAsFixed(1)} km',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.black),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Attendees: ${event.attendees.length}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.black),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Visibility: ${event.visibility.capitalize()}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.black),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: event.attendees.contains(authProvider.currentUser?.uid) ? 'Leave' : 'Join',
                            color: event.attendees.contains(authProvider.currentUser?.uid)
                                ? AppColors.accentRed
                                : AppColors.primaryTeal,
                            onPressed: () async {
                              try {
                                await discoveryProvider.rsvpToEvent(
                                  event.id,
                                  authProvider.currentUser!.uid,
                                  !event.attendees.contains(authProvider.currentUser?.uid),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      event.attendees.contains(authProvider.currentUser?.uid)
                                          ? 'Left event'
                                          : 'Joined event',
                                    ),
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to RSVP: $e')),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CustomButton(
                            text: 'Navigate',
                            color: AppColors.primaryTeal,
                            icon: const Icon(Icons.directions, color: AppColors.white),
                            onPressed: () async {
                              try {
                                await _launchGoogleMaps(event.latitude, event.longitude);
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to open Google Maps: $e')),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() => "${this[0].toUpperCase()}${substring(1)}";
}