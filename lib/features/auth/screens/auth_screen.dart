// features/auth/screens/auth_screen.dart
import 'package:duze/shared/widgets/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../../../config/routes.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/social_login_button.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
     
       body: Container(
    decoration: const BoxDecoration(gradient: AppColors.profileGradient),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome to Duze',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Login',
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.login);
              },
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: 'Register',
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.register);
              },
            ),
            const SizedBox(height: 24),
            const Text('Or continue with'),
            const SizedBox(height: 16),
            SocialLoginButton(
              text: 'Continue with Facebook',
              icon: Icons.facebook,
              color: const Color(0xFF1877F2),
              onPressed: () async {
                  final success = await authProvider.signInWithFacebook();
                    if (success) {
                          Navigator.pushReplacementNamed(context, AppRoutes.home);
                        }
              },
            ),
            const SizedBox(height: 12),
            SocialLoginButton(
              text: 'Continue with Twitter',
              icon: Icons.alternate_email,
              color: const Color(0xFF1DA1F2),
             onPressed: () async {
                         final success = await authProvider.signInWithTwitter();
                        if (success) {
                          Navigator.pushReplacementNamed(context, AppRoutes.home);
                        }
                      },
            ),
          ],
        ),
      ),
       ),
    );
  }
}