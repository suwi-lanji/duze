import 'package:cached_network_image/cached_network_image.dart';
import 'package:duze/features/auth/providers/auth_provider.dart';
import 'package:duze/features/chat/providers/chat_provider.dart';
import 'package:duze/shared/widgets/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/models/user_model.dart';

class UserCard extends StatelessWidget {
  final UserModel user;
  final bool showDistance;
  final VoidCallback? onTap;
  final VoidCallback? onConnect;
  final VoidCallback? onMessage;
  final VoidCallback? onAccept;
  final VoidCallback? onDeny;
  final VoidCallback? onCancel;
  final String? distance;
  final List<String> mutualConnections;
  final bool isPendingSent;
  final bool isPendingReceived;
  final bool isFriend;

  const UserCard({
    super.key,
    required this.user,
    this.showDistance = false,
    this.onTap,
    this.onConnect,
    this.onMessage,
    this.onAccept,
    this.onDeny,
    this.onCancel,
    this.distance,
    this.mutualConnections = const [],
    this.isPendingSent = false,
    this.isPendingReceived = false,
    this.isFriend = false,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final cardHeight = mediaQuery.size.height * 0.5;
    final cardWidth = mediaQuery.size.width * 0.8;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              user.photoURL.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: user.photoURL,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        decoration: const BoxDecoration(
                          gradient: AppColors.profileGradient,
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(color: AppColors.primaryTeal),
                        ),
                      ),
                      errorWidget: (_, __, ___) => _defaultProfileFallback(),
                    )
                  : _defaultProfileFallback(),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.white.withOpacity(0.1),
                      AppColors.white.withOpacity(0.1),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 24,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.displayName,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                  shadows: [
                                    Shadow(
                                      color: AppColors.black.withOpacity(0.6),
                                      offset: const Offset(0, 1),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                          ),
                        ),
                        if (isFriend)
                          Chip(
                            label: const Text('Friends'),
                            backgroundColor: AppColors.primaryTeal.withOpacity(0.2),
                            labelStyle: const TextStyle(
                              color: AppColors.primaryTeal,
                              fontFamily: 'Poppins',
                            ),
                          ),
                      ],
                    ),
                    if (showDistance && distance != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        distance!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 16,
                              color: AppColors.textPrimary,
                              shadows: [
                                Shadow(
                                  color: AppColors.black.withOpacity(0.4),
                                  offset: const Offset(0, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (user.facebookUsername != null)
                      _socialRow(Icons.facebook, AppColors.facebookBlue, user.facebookUsername!),
                    if (user.twitterUsername != null)
                      _socialRow(Icons.alternate_email, AppColors.twitterBlue, '@${user.twitterUsername}'),
                    if (user.tiktokUsername != null)
                      _socialRow(Icons.music_note, AppColors.tiktokBlack, '@${user.tiktokUsername}'),
                  ],
                ),
              ),
              Positioned(
                bottom: 24,
                right: 16,
                child: Row(
                  children: [
                    if (isPendingSent && onCancel != null)
                      _buildActionButton(
                        text: 'Cancel',
                        gradient: LinearGradient(
                          colors: [AppColors.accentRed, AppColors.accentRed.withOpacity(0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        onPressed: onCancel,
                      ),
                    if (isPendingReceived && onAccept != null && onDeny != null) ...[
                      _buildActionButton(
                        icon: Icons.check,
                        gradient: AppColors.buttonGradient,
                        onPressed: onAccept,
                      ),
                      const SizedBox(width: 8),
                      _buildActionButton(
                        icon: Icons.close,
                        gradient: AppColors.buttonGradient,
                        onPressed: onDeny,
                      ),
                    ] else if (!isPendingSent && !isPendingReceived && !isFriend && onConnect != null)
                      _buildActionButton(
                        text: 'Connect',
                        gradient: AppColors.buttonGradient,
                        onPressed: onConnect,
                      ),
                    if ((isFriend || isPendingSent || isPendingReceived) && onMessage != null) ...[
                      if (!isPendingReceived && !isPendingSent) const SizedBox(width: 8),
                      _buildActionButton(
                        icon: Icons.chat,
                        gradient: AppColors.buttonGradient,
                        onPressed: onMessage,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0, duration: 600.ms);
  }

  Widget _buildActionButton({
    String? text,
    IconData? icon,
    required Gradient gradient,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.transparent),
        ),
      ),
      child: Ink(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          padding: text != null
              ? const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
              : const EdgeInsets.all(12),
          child: text != null
              ? Text(
                  text,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                )
              : Icon(icon, color: AppColors.textPrimary, size: 20),
        ),
      ),
    );
  }

  Widget _defaultProfileFallback() => Container(
        decoration: const BoxDecoration(
          gradient: AppColors.profileGradient,
        ),
        child: const Icon(
          Icons.person,
          size: 100,
          color: AppColors.textSecondary,
        ),
      );

  Widget _socialRow(IconData icon, Color color, String username) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              username,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      );
}