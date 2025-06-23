import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:duze/config/routes.dart';
import 'package:duze/core/models/chat_model.dart';
import 'package:duze/core/models/message_request_model.dart';
import 'package:duze/features/auth/providers/auth_provider.dart';
import 'package:duze/features/chat/providers/chat_provider.dart';
import 'package:duze/features/chat/widgets/chat_card.dart';
import 'package:duze/shared/widgets/app_colors.dart';
import 'package:duze/shared/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  Future<String> _fetchSenderName(String senderId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(senderId).get();
      return doc.data()?['displayName'] ?? senderId;
    } catch (e) {
      print('Error fetching sender name: $e');
      return senderId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);

    if (authProvider.currentUser == null) {
      return const Scaffold(
        appBar: CustomAppBar(),
        body: Center(child: Text('Please log in to view chats')),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      chatProvider.initialize(authProvider.currentUser!.uid);
    });

    return Scaffold(
      appBar: const CustomAppBar(),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.profileGradient),
        child: chatProvider.isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryTeal))
            : chatProvider.chats.isEmpty
                ? const Center(
                    child: Text(
                      'No chats available',
                      style: TextStyle(color: AppColors.mainFontColor),
                    ),
                  )
                : ListView.builder(
                    itemCount: chatProvider.chats.length,
                    itemBuilder: (context, index) {
                      final chat = chatProvider.chats[index];
                      final recipientId = chat.participants.firstWhere(
                        (uid) => uid != authProvider.currentUser!.uid,
                      );

                      return FutureBuilder<String>(
                        future: _fetchSenderName(recipientId),
                        builder: (context, snapshot) {
                          final recipientName = snapshot.data ?? 'Loading...';
                          return ChatCard(
                            chat: chat,
                            recipientName: recipientName,
                            onTap: () {
                              if (chat.isPending && chat.senderId != authProvider.currentUser!.uid) {
                                final request = chatProvider.pendingRequests.firstWhere(
                                  (r) => r.requestId == chat.id,
                                  orElse: () => MessageRequest(
                                    requestId: chat.id,
                                    senderId: recipientId,
                                    recipientId: authProvider.currentUser!.uid,
                                    message: chat.lastMessage,
                                    timestamp: chat.lastMessageTimestamp,
                                    status: 'pending',
                                  ),
                                );
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.messageRequest,
                                  arguments: request,
                                );
                              } else {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.chatDetail,
                                  arguments: chat,
                                );
                              }
                            },
                            isPending: chat.isPending,
                            warningText: chat.isPending
                                ? chat.senderId == authProvider.currentUser!.uid
                                    ? 'Waiting for $recipientName to accept'
                                    : 'Pending request from $recipientName'
                                : null,
                          );
                        },
                      );
                    },
                  ),
      ),
    );
  }
}