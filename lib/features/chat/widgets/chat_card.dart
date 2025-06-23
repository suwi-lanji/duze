import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:duze/core/models/chat_model.dart';
import 'package:duze/core/models/user_model.dart';
import 'package:duze/features/auth/providers/auth_provider.dart';
import 'package:duze/shared/widgets/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ChatCard extends StatelessWidget {
  final Chat chat;
  final String? recipientName;
  final VoidCallback onTap;
  final bool isPending;
  final String? warningText;

  const ChatCard({
    super.key,
    required this.chat,
    this.recipientName,
    required this.onTap,
    this.isPending = false,
    this.warningText,
  });

  Future<UserModel?> _fetchRecipient(String recipientId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(recipientId).get();
      if (!doc.exists) return null;
      return UserModel.fromMap({...doc.data()!, 'uid': doc.id});
    } catch (e) {
      print('Error fetching recipient: $e');
      return null;
    }
  }

  Widget _defaultProfileFallback() => Container(
        decoration: const BoxDecoration(
          gradient: AppColors.profileGradient,
        ),
        child: const Icon(
          Icons.person,
          size: 24, // Adjusted for CircleAvatar size
          color: AppColors.textSecondary,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthProvider>(context).currentUser;
    final unreadCount = currentUser != null ? chat.unreadCount[currentUser.uid] ?? 0 : 0;
    final recipientId = chat.participants.firstWhere(
      (uid) => uid != currentUser?.uid,
      orElse: () => '',
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: AppColors.white.withOpacity(0.9),
      child: ListTile(
        onTap: onTap,
        leading: FutureBuilder<UserModel?>(
          future: _fetchRecipient(recipientId),
          builder: (context, snapshot) {
            final user = snapshot.data;
            return CircleAvatar(
              backgroundColor: AppColors.primaryTeal.withOpacity(0.2),
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const CircularProgressIndicator(color: AppColors.primaryTeal)
                  : user?.photoURL.isNotEmpty ?? false
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: user!.photoURL,
                            fit: BoxFit.cover,
                            width: 40,
                            height: 40,
                            placeholder: (context, url) => const CircularProgressIndicator(color: AppColors.primaryTeal),
                            errorWidget: (context, url, error) => _defaultProfileFallback(),
                          ),
                        )
                      : _defaultProfileFallback(),
            );
          },
        ),
        title: Text(
          recipientName ?? 'Chat',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.mainFontColor,
                fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
              ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              chat.lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.grey600),
            ),
            if (isPending && warningText != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  warningText!,
                  style: const TextStyle(
                    color: AppColors.accentRed,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('HH:mm').format(chat.lastMessageTimestamp),
              style: const TextStyle(color: AppColors.grey600, fontSize: 12),
            ),
            if (unreadCount > 0)
              CircleAvatar(
                radius: 10,
                backgroundColor: AppColors.primaryTeal,
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(color: AppColors.white, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}