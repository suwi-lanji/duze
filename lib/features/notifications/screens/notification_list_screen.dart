import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:duze/core/models/message_request_model.dart';
import 'package:duze/core/models/notification_model.dart';
import 'package:duze/features/auth/providers/auth_provider.dart';
import 'package:duze/features/chat/providers/chat_provider.dart';
import 'package:duze/features/notifications/providers/notification_provider.dart';
import 'package:duze/shared/widgets/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../config/routes.dart';

class NotificationListScreen extends StatelessWidget {
  const NotificationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final notificationProvider = Provider.of<NotificationProvider>(context);

    if (authProvider.currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Please log in to view notifications')),
      );
    }

    // Initialize only once per build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notificationProvider.initialize(authProvider.currentUser!.uid);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.white.withOpacity(0.95),
        foregroundColor: AppColors.mainFontColor,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.profileGradient),
        child: notificationProvider.isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryTeal))
            : notificationProvider.notifications.isEmpty
                ? const Center(
                    child: Text(
                      'No notifications available',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        color: AppColors.mainFontColor,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: notificationProvider.notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notificationProvider.notifications[index];
                      return ListTile(
                        leading: Icon(
                          notification.type == 'message_request'
                              ? Icons.chat
                              : notification.type == 'friend_request'
                                  ? Icons.person_add
                                  : notification.type == 'request_accept'
                                      ? Icons.check_circle
                                      : notification.type == 'post_like'
                                          ? Icons.favorite
                                          : Icons.comment,
                          color: notification.isRead ? AppColors.grey600 : AppColors.primaryTeal,
                        ),
                        title: Text(
                          notification.content,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: notification.isRead ? AppColors.grey600 : AppColors.textDark,
                          ),
                        ),
                        subtitle: Text(
                          DateFormat('MMM d, yyyy').format(notification.timestamp),
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            color: AppColors.grey600,
                            fontSize: 12,
                          ),
                        ),
                        onTap: () async {
                          await notificationProvider.markAsRead(notification.id);
                          if (notification.type == 'message_request') {
                            try {
                              final request = await FirebaseFirestore.instance
                                  .collection('pendingMessages')
                                  .doc(notification.itemId)
                                  .get()
                                  .then((doc) {
                                if (!doc.exists) {
                                  throw Exception('Message request not found');
                                }
                                return MessageRequest.fromMap(doc.data()!);
                              });
                              Navigator.pushNamed(
                                context,
                                AppRoutes.messageRequest,
                                arguments: request,
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          } else if (notification.type == 'friend_request' || notification.type == 'request_accept') {
                            try {
                              final chat = await Provider.of<ChatProvider>(context, listen: false)
                                  .getExistingChat(authProvider.currentUser!.uid, notification.itemId);
                              if (chat != null) {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.chatDetail,
                                  arguments: chat,
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Chat not found')),
                                );
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          } else if (notification.type == 'post_like' || notification.type == 'post_comment') {
                            // TODO: Navigate to PostDetailScreen
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Post navigation not implemented')),
                            );
                          }
                        },
                      );
                    },
                  ),
      ),
    );
  }
}