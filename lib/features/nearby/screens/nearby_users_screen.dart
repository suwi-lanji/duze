// features/nearby/screens/nearby_users_screen.dart
import 'package:duze/core/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/app_colors.dart';
import '../../../shared/widgets/custom_button.dart';

class NearbyUsersScreen extends StatelessWidget {
  const NearbyUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Nearby Friends',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: SafeArea(
          child: FutureBuilder<List<UserModel>>(
            future: authProvider.findNearbyUsers(5.0),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text(
                    'No nearby users found',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: AppColors.textPrimary,
                    ),
                  ),
                );
              }

              final users = snapshot.data!;
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return FutureBuilder<Map<String, List<String>>>(
                    future: authProvider.findMutualConnections(user.uid),
                    builder: (context, connectionSnapshot) {
                      if (connectionSnapshot.connectionState == ConnectionState.waiting) {
                        return const ListTile(
                          title: Text('Loading...'),
                          leading: CircularProgressIndicator(),
                        );
                      }
                      final mutualConnections = connectionSnapshot.data ?? {};
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.glassBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: ListTile(
                          title: Text(
                            user.displayName,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            _formatMutualConnections(mutualConnections),
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: AppColors.textSecondary,
                            ),
                          ),
                          leading: user.photoURL.isNotEmpty
                              ? CircleAvatar(backgroundImage: NetworkImage(user.photoURL))
                              : const Icon(Icons.person, color: AppColors.textPrimary),
                        ),
                      ).animate().fadeIn(duration: 500.ms, delay: (index * 100).ms);
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.teal,
        onPressed: () async {
          await authProvider.updateUserLocation();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location updated')),
          );
        },
        child: const Icon(Icons.location_on, color: AppColors.textPrimary),
      ),
    );
  }

  String _formatMutualConnections(Map<String, List<String>> connections) {
    if (connections['friends']?.isNotEmpty ?? false) {
      return '${connections['friends']!.length} mutual friends';
    }
    return 'No mutual connections';
  }
}