import 'package:duze/core/models/user_model.dart';
import 'package:duze/features/auth/providers/auth_provider.dart';
import 'package:duze/features/notifications/providers/notification_provider.dart';
import 'package:duze/features/profile/screens/profile_screen.dart';
import 'package:duze/shared/widgets/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  Future<String?> _getTownName(UserLocation? location) async {
    if (location == null) return null;
    try {
      final placemarks = await placemarkFromCoordinates(location.latitude, location.longitude);
      return placemarks.first.locality ?? 'Unknown';
    } catch (_) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.primaryDark,
      elevation: 0,
      centerTitle: true,
      leading: Consumer<AuthProvider>(
        builder: (_, authProvider, __) {
          final user = authProvider.currentUser;
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundImage:
                    user?.photoURL.isNotEmpty == true ? NetworkImage(user!.photoURL) : null,
                child: user?.photoURL.isEmpty == true || user == null
                    ? const Icon(Icons.person, color: AppColors.textSecondary)
                    : null,
              ),
            ),
          );
        },
      ),
      title: Consumer<AuthProvider>(
        builder: (_, authProvider, __) {
          return FutureBuilder<String?>(
            future: _getTownName(authProvider.currentUser?.location),
            builder: (context, snapshot) {
              return Text(
                snapshot.data ?? 'Loading...',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
              );
            },
          );
        },
      ),
      actions: [
        Consumer<NotificationProvider>(
          builder: (_, notificationProvider, __) {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            if (authProvider.currentUser != null) {
              notificationProvider.initialize(authProvider.currentUser!.uid);
            }
            return Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications, color: AppColors.primaryTeal),
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.notifications),
                ),
                if (notificationProvider.unreadCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.accentRed,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${notificationProvider.unreadCount}',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}