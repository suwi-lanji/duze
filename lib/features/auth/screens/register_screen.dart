// features/auth/screens/register_screen.dart
import 'package:duze/shared/widgets/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../../../config/routes.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
      ),
       body: Container(
    decoration: const BoxDecoration(gradient: AppColors.profileGradient),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomTextField(
                controller: _displayNameController,
                labelText: 'Display Name',
                 textColor: Colors.black, 
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your display name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _emailController,
                labelText: 'Email',
                 textColor: Colors.black, 
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _passwordController,
                labelText: 'Password',
                obscureText: true,
                 textColor: Colors.black, 
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Register',
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final success = await authProvider.registerWithEmail(
                      _emailController.text.trim(),
                      _passwordController.text,
                      _displayNameController.text.trim(),
                    );
                    if (success) {
                      Navigator.pushReplacementNamed(context, AppRoutes.home);
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