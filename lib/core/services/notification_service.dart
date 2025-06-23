import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:duze/features/auth/providers/auth_provider.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        print('Notification tapped: ${response.payload}');
      },
    );
    print('NotificationService initialized');
  }

  Future<void> showMessageRequestNotification({
    required BuildContext context, // Added for AuthProvider access
    required String requestId,
    required String senderName,
    required String message,
    required String recipientId,
  }) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser?.uid != recipientId) {
      print('NotificationService: Skipping message request notification for requestId: $requestId. '
            'Current user (${authProvider.currentUser?.uid}) is not recipient ($recipientId).');
      return;
    }

    print('NotificationService: Showing message request notification for recipient: $recipientId, '
          'from sender: $senderName, requestId: $requestId');

    const androidDetails = AndroidNotificationDetails(
      'message_requests',
      'Message Requests',
      channelDescription: 'Notifications for new message requests',
      importance: Importance.high,
      priority: Priority.high,
      actions: [
        AndroidNotificationAction('accept', 'Accept'),
        AndroidNotificationAction('deny', 'Deny'),
      ],
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(
      requestId.hashCode,
      'Message request from $senderName',
      message,
      details,
      payload: 'message_request|$requestId',
    );
  }

  Future<void> showAcceptNotification({
    required BuildContext context,
    required String requestId,
    required String recipientName,
    required String recipientId, // Recipient of the accept notification (original sender)
  }) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser?.uid != recipientId) {
      print('NotificationService: Skipping accept notification for requestId: $requestId. '
            'Current user (${authProvider.currentUser?.uid}) is not recipient ($recipientId).');
      return;
    }

    print('NotificationService: Showing accept notification for recipient: $recipientId, '
          'from recipientName: $recipientName, requestId: $requestId');

    const androidDetails = AndroidNotificationDetails(
      'request_accepts',
      'Request Accepts',
      channelDescription: 'Notifications for accepted requests',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(
      requestId.hashCode,
      '$recipientName accepted your request',
      'You can now chat with $recipientName',
      details,
      payload: 'accept_request|$requestId',
    );
  }

  Future<void> showPostNotification({
    required BuildContext context,
    required String postId,
    required String senderName,
    required String type, // 'like' or 'comment'
    required String content,
    required String recipientId,
  }) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser?.uid != recipientId) {
      print('NotificationService: Skipping post notification for postId: $postId, type: $type. '
            'Current user (${authProvider.currentUser?.uid}) is not recipient ($recipientId).');
      return;
    }

    print('NotificationService: Showing post notification for recipient: $recipientId, '
          'from sender: $senderName, postId: $postId, type: $type');

    const androidDetails = AndroidNotificationDetails(
      'post_notifications',
      'Post Notifications',
      channelDescription: 'Notifications for post likes and comments',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(
      postId.hashCode,
      type == 'like' ? '$senderName liked your post' : '$senderName commented on your post',
      content,
      details,
      payload: 'post|$postId|$type',
    );
  }
}