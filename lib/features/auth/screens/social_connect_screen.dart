// features/auth/screens/social_connect_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_provider.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/app_colors.dart';

class SocialConnectScreen extends StatelessWidget {
  const SocialConnectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Connect Social Media',
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Connect your social media accounts to find friends nearby.',
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'Poppins',
                    color: AppColors.textSecondary,
                  ),
                ).animate().fadeIn(duration: 500.ms),
                const SizedBox(height: 24),
                _buildSocialButton(
                  context,
                  authProvider,
                  platform: 'facebook',
                  text: user?.socialAccounts.containsKey('facebook') ?? false
                      ? 'Connected to Facebook'
                      : 'Connect with Facebook',
                  icon: Icons.facebook,
                  color: AppColors.facebookBlue,
                ),
                const SizedBox(height: 16),
                _buildSocialButton(
                  context,
                  authProvider,
                  platform: 'twitter',
                  text: user?.socialAccounts.containsKey('twitter') ?? false
                      ? 'Connected to Twitter'
                      : 'Connect with Twitter',
                  icon: Icons.alternate_email,
                  color: AppColors.twitterBlue,
                ),
                const SizedBox(height: 16),
                _buildSocialButton(
                  context,
                  authProvider,
                  platform: 'tiktok',
                  text: user?.socialAccounts.containsKey('tiktok') ?? false
                      ? 'Connected to TikTok'
                      : 'Connect with TikTok',
                  icon: Icons.music_note,
                  color: AppColors.tiktokBlack,
                ),
                const SizedBox(height: 24),
                CustomButton(
                  text: 'Find Nearby Friends',
                  gradient: AppColors.buttonGradient, // Use gradient here
                  onPressed: () {
                    Navigator.pushNamed(context, '/nearby_users');
                  },
                ).animate().slideY(begin: 0.2, end: 0, duration: 500.ms),
                if (authProvider.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      authProvider.errorMessage!,
                      style: const TextStyle(
                        color: AppColors.accentRed,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ).animate().fadeIn(duration: 300.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton(
    BuildContext context,
    AuthProvider authProvider, {
    required String platform,
    required String text,
    required IconData icon,
    required Color color,
  }) {
    return CustomButton(
      text: text,
      isLoading: authProvider.isLoading && authProvider.currentUser?.socialAccounts.containsKey(platform) != true,
      icon: Icon(icon, color: AppColors.textPrimary),
      color: color, // Use solid color for social buttons
      onPressed: authProvider.currentUser?.socialAccounts.containsKey(platform) ?? false
          ? null
          : () {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Future.microtask(() async {
                bool success;
                switch (platform) {
                  case 'facebook':
                    success = await authProvider.signInWithFacebook();
                    break;
                  case 'twitter':
                    success = await authProvider.signInWithTwitter();
                    break;
                  case 'tiktok':
                    success = await authProvider.signInWithTikTok();
                    break;
                  default:
                    success = false;
                }
                if (success) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('$platform connected'.replaceFirst('tiktok', 'TikTok'))),
                  );
                }
              });
            },
    ).animate().fadeIn(duration: 500.ms, delay: (platform.hashCode % 3 * 100).ms);
  }
}