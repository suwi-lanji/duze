import 'package:duze/core/services/notification_service.dart';
import 'package:duze/features/notifications/providers/notification_provider.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'config/app_config.dart';
import 'config/routes.dart';
import 'config/theme.dart';
import 'core/services/auth_service.dart';
import 'core/services/location_service.dart';
import 'core/services/social_service.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/location/providers/location_provider.dart';
import 'features/discovery/providers/discovery_provider.dart';
import 'features/chat/providers/chat_provider.dart';
import 'features/post/providers/post_provider.dart';

// Global StreamController to broadcast oauth_verifier
final StreamController<String?> oauthVerifierController = StreamController<String?>.broadcast();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await dotenv.load(fileName: ".env"); // Load .env file

// Initialize AdMob
  await MobileAds.instance.initialize();
 await NotificationService().initialize();
  // Initialize deep linking
  _initDeepLinks();

  runApp(const DuzeApp());
}

void _initDeepLinks() async {
  final appLinks = AppLinks();

  // Handle streamed deep links
  StreamSubscription? sub;
  sub = appLinks.uriLinkStream.listen((Uri? uri) {
    print('Deep link stream received: $uri');
    if (uri != null && uri.scheme == 'duze' && uri.host == 'auth') {
      final verifier = uri.queryParameters['oauth_verifier'];
      final token = uri.queryParameters['oauth_token'];
      print('Deep link parsed: URI=$uri, Verifier=$verifier, Token=$token');
      oauthVerifierController.add(verifier);
    } else {
      print('Invalid deep link: $uri');
      oauthVerifierController.add(null); // Notify AuthProvider of failure
    }
  }, onError: (err) {
    print('Deep link stream error: $err');
    oauthVerifierController.addError(err);
  });

  // Handle initial URI
  try {
    final initialUri = await appLinks.getInitialLink();
    print('Initial deep link received: $initialUri');
    if (initialUri != null && initialUri.scheme == 'duze' && initialUri.host == 'auth') {
      final verifier = initialUri.queryParameters['oauth_verifier'];
      final token = initialUri.queryParameters['oauth_token'];
      print('Initial deep link parsed: URI=$initialUri, Verifier=$verifier, Token=$token');
      oauthVerifierController.add(verifier);
    } else {
      print('Invalid initial deep link: $initialUri');
    }
  } catch (e) {
    print('Initial deep link error: $e');
  }
}

class DuzeApp extends StatelessWidget {
  const DuzeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => DiscoveryProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => PostProvider()),
         ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: Builder(
        builder: (context) {
          final authProvider = Provider.of<AuthProvider>(context);
          return MaterialApp(
            title: 'Duze',
            theme: AppTheme.lightTheme,
          //  darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            onGenerateRoute: AppRoutes.generateRoute,
            initialRoute: authProvider.isAuthenticated ? AppRoutes.home : AppRoutes.splash,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}