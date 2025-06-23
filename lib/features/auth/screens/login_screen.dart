// features/auth/screens/login_screen.dart
import 'package:duze/shared/widgets/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../../../config/routes.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/social_login_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
       body: Container(
    decoration: const BoxDecoration(gradient: AppColors.profileGradient),
      child: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 60),
                    Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Welcome to Duze',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Connect with friends nearby',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    CustomTextField(
                      controller: _emailController,
                      labelText: 'Email',
                      textColor: Colors.black, 
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _passwordController,
                      labelText: 'Password',
                      obscureText: _obscurePassword,
                       textColor: Colors.black, 
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    if (authProvider.errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[300]!),
                        ),
                        child: Text(
                          authProvider.errorMessage!,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                    CustomButton(
                    text: authProvider.isLoading ? 'Logging in...' : 'Login',
                    onPressed: authProvider.isLoading
                        ? null
                        : () async {
                            final success = await authProvider.signInWithEmail(
                              _emailController.text,
                              _passwordController.text,
                            );
                            if (success && context.mounted) {
                              Navigator.pushReplacementNamed(context, AppRoutes.home);
                            }
                          },
                    color: Colors.teal,
                  ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        // TODO: Implement forgot password
                      },
                      child: const Text('Forgot Password?'),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey[300])),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Or continue with',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey[300])),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SocialLoginButton(
                      text: 'Continue with Facebook',
                      icon: Icons.facebook,
                      color: const Color(0xFF1877F2),
                      onPressed: () async {
                        final success = await authProvider.signInWithFacebook();
                        if (success && mounted) {
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
                        if (success && mounted) {
                          Navigator.pushReplacementNamed(context, AppRoutes.home);
                        }
                      },
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, AppRoutes.register);
                          },
                          child: const Text('Sign Up'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
       ),
    );
  }
}