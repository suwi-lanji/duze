
// config/routes.dart
import 'package:duze/features/auth/screens/auth_screen.dart';
import 'package:duze/features/auth/screens/login_screen.dart';
import 'package:duze/features/auth/screens/register_screen.dart';
import 'package:duze/features/auth/screens/social_connect_screen.dart';
import 'package:duze/features/chat/screens/chat_detail_screen.dart';
import 'package:duze/features/chat/screens/chat_list_screen.dart';
import 'package:duze/features/chat/screens/message_request_screen.dart';
import 'package:duze/features/discovery/screens/create_event_screen.dart';
import 'package:duze/features/discovery/screens/discovery_screen.dart';
import 'package:duze/features/discovery/screens/event_details_screen.dart';
import 'package:duze/features/discovery/screens/events_screen.dart';
import 'package:duze/features/home/screens/home_screen.dart';
import 'package:duze/features/nearby/screens/nearby_users_screen.dart';
import 'package:duze/features/notifications/screens/notification_list_screen.dart';
import 'package:duze/features/profile/screens/change_password_screen.dart';
import 'package:duze/features/profile/screens/edit_profile_screen.dart';
import 'package:duze/features/profile/screens/profile_screen.dart';
import 'package:duze/features/profile/screens/view_user_profile_screen.dart';
import 'package:duze/features/settings/screens/settings_screen.dart';
import 'package:duze/features/splash/screens/splash_screen.dart';
import 'package:flutter/material.dart';
// config/routes.dart
// config/routes.dart
class AppRoutes {
  static const String splash = '/';
  static const String auth = '/auth';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String discovery = '/discovery';
  static const String chat = '/chat';
  static const String settingsRoute = '/settings';
  static const String socialConnect = '/social-connect';
  static const String nearbyUsers = '/nearby_users';
  static const String userProfile = '/user_profile';
  static const String editProfile = '/edit_user_profile';
  static const String changePassword = '/change_password';
  static const String events = '/events';
  static const String createEvent = '/create-event';
  static const String eventDetails = '/event-details';
   static const String chatDetail = '/chat_detail';
  static const String messageRequest = '/message_request';
  static const String notifications = '/notifications';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    print('Generating route: ${settings.name}, Arguments: ${settings.arguments}');
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen(), settings: settings);
      case auth:
        return MaterialPageRoute(builder: (_) => const AuthScreen(), settings: settings);
           case chatDetail:
        return MaterialPageRoute(builder: (_) => const ChatDetailScreen(), settings: settings);
      case messageRequest:
        return MaterialPageRoute(builder: (_) => const MessageRequestScreen(), settings: settings);
      case notifications:
        return MaterialPageRoute(builder: (_) => const NotificationListScreen(), settings: settings);
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen(), settings: settings);
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen(), settings: settings);
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen(), settings: settings);
      case events:
        return MaterialPageRoute(builder: (_) => const EventsScreen(), settings: settings);
      case createEvent:
        return MaterialPageRoute(builder: (_) => const CreateEventScreen(), settings: settings);
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen(), settings: settings);
      case discovery:
        return MaterialPageRoute(builder: (_) => const DiscoveryScreen(), settings: settings);
      case userProfile:
        return MaterialPageRoute(builder: (_) => const ViewUserProfileScreen(), settings: settings);
      case editProfile:
        return MaterialPageRoute(builder: (_) => const EditProfileScreen(), settings: settings);
      case changePassword:
        return MaterialPageRoute(builder: (_) => const ChangePasswordScreen(), settings: settings);
      case chat:
        return MaterialPageRoute(builder: (_) => const ChatListScreen(), settings: settings);
      case settingsRoute:
        return MaterialPageRoute(builder: (_) => const SettingsScreen(), settings: settings);
      case nearbyUsers:
        return MaterialPageRoute(builder: (_) => const NearbyUsersScreen(), settings: settings);
      case socialConnect:
        return MaterialPageRoute(builder: (_) => const SocialConnectScreen(), settings: settings);
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Page not found')),
          ),
          settings: settings,
        );
    }
  }
}