// lib/features/discovery/screens/create_event_screen.dart
import 'package:duze/features/auth/providers/auth_provider.dart';
import 'package:duze/features/discovery/providers/discovery_provider.dart';
import 'package:duze/features/discovery/screens/events_screen.dart';
import 'package:duze/features/location/providers/location_provider.dart';
import 'package:duze/shared/widgets/app_colors.dart';
import 'package:duze/shared/widgets/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  String _description = '';
  DateTime _startTime = DateTime.now().add(const Duration(hours: 1));
  DateTime? _endTime;
  String _address = '';
  String _visibility = 'public';
  String _category = 'Party';
  double? _latitude;
  double? _longitude;

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    final discoveryProvider = Provider.of<DiscoveryProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Event', style: TextStyle(color: AppColors.buttoncolor)),
        backgroundColor: AppColors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.profileGradient),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    labelStyle: TextStyle(color: AppColors.buttoncolor),
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(color: AppColors.black),
                  onChanged: (value) => _title = value,
                  validator: (value) => value!.isEmpty ? 'Title is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    labelStyle: TextStyle(color: AppColors.buttoncolor),
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(color: AppColors.black),
                  maxLines: 3,
                  onChanged: (value) => _description = value,
                  validator: (value) => value!.isEmpty ? 'Description is required' : null,
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Start Time', style: TextStyle(color: AppColors.buttoncolor)),
                  subtitle: Text(
                    _startTime.toLocal().toString().split('.')[0],
                    style: const TextStyle(color: AppColors.black),
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _startTime,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(_startTime),
                      );
                      if (time != null) {
                        setState(() {
                          _startTime = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    labelStyle: TextStyle(color: AppColors.buttoncolor),
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(color: AppColors.black),
                  onChanged: (value) => _address = value,
                  validator: (value) => value!.isEmpty ? 'Address is required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _visibility,
                  decoration: const InputDecoration(
                    labelText: 'Visibility',
                    labelStyle: TextStyle(color: AppColors.buttoncolor),
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(color: AppColors.black),
                  items: const [
                    DropdownMenuItem(value: 'public', child: Text('Public')),
                    DropdownMenuItem(value: 'friends', child: Text('Friends Only')),
                    DropdownMenuItem(value: 'private', child: Text('Private')),
                  ],
                  onChanged: (value) => setState(() => _visibility = value!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    labelStyle: TextStyle(color: AppColors.buttoncolor),
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(color: AppColors.black),
                  items: const [
                    DropdownMenuItem(value: 'Party', child: Text('Party')),
                    DropdownMenuItem(value: 'Sports', child: Text('Sports')),
                    DropdownMenuItem(value: 'Study', child: Text('Study')),
                    DropdownMenuItem(value: 'Music', child: Text('Music')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (value) => setState(() => _category = value!),
                ),
                const SizedBox(height: 24),
                CustomButton(
                  text: 'Create Event',
                  gradient: AppColors.buttonGradient,
                  isLoading: discoveryProvider.isLoading,
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      if (locationProvider.currentPosition == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Location not available')),
                        );
                        return;
                      }
                      try {
                        _latitude = locationProvider.currentPosition!.latitude;
                        _longitude = locationProvider.currentPosition!.longitude;
                        await discoveryProvider.createEvent(
                          title: _title,
                          description: _description,
                          startTime: _startTime,
                          endTime: _endTime,
                          latitude: _latitude!,
                          longitude: _longitude!,
                          address: _address,
                          userId: authProvider.currentUser!.uid,
                          visibility: _visibility,
                          category: _category,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Event created successfully')),
                        );
                        // Redirect to EventsScreen and refresh events
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const EventsScreen()),
                          (route) => route.isFirst, // Clear stack to root
                        );
                        // Trigger event refresh
                        await discoveryProvider.loadNearbyEvents(
                          locationProvider.currentPosition!.latitude,
                          locationProvider.currentPosition!.longitude,
                          5.0,
                          authProvider.currentUser!.uid,
                          authProvider.currentUser!.friends ?? [],
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to create event: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}