import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../config/routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  void _checkAuthentication() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // Listen for authProvider changes to ensure user data is loaded
    authProvider.addListener(() {
      if (!mounted) return;
      if (authProvider.isLoading) return; // Wait until loading is complete
      Navigator.pushReplacementNamed(
        context,
        authProvider.isAuthenticated ? AppRoutes.home : AppRoutes.auth,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_on, size: 80, color: Colors.purple),
            const SizedBox(height: 16),
            const Text(
              'Welcome to Duze',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.purple),
            ),
            const SizedBox(height: 8),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.removeListener(() {}); // Clean up listener
    super.dispose();
  }
}