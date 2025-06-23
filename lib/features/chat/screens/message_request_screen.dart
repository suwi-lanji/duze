import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:duze/core/models/connect_request_model.dart';
import 'package:duze/core/models/message_request_model.dart';
import 'package:duze/core/models/user_model.dart';
import 'package:duze/features/auth/providers/auth_provider.dart';
import 'package:duze/features/chat/providers/chat_provider.dart';
import 'package:duze/shared/widgets/app_colors.dart';
import 'package:duze/shared/widgets/custom_button.dart';
import 'package:duze/shared/widgets/custom_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

class MessageRequestScreen extends StatefulWidget {
  const MessageRequestScreen({super.key});

  @override
  State<MessageRequestScreen> createState() => _MessageRequestScreenState();
}

class _MessageRequestScreenState extends State<MessageRequestScreen> {
  final _messageController = TextEditingController();
  bool _isLoading = false;
  ScaffoldMessengerState? _scaffoldMessenger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<UserModel?> _fetchUser(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      return UserModel.fromMap({...doc.data()!, 'uid': doc.id});
    } catch (e) {
      print('Error fetching user: $e');
      return null;
    }
  }

  Future<ConnectRequest?> _fetchConnectRequest(String senderId, String recipientId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('friendRequests')
          .where('senderId', isEqualTo: senderId)
          .where('recipientId', isEqualTo: recipientId)
          .where('status', isEqualTo: 'pending')
          .get();
      if (snapshot.docs.isNotEmpty) {
        return ConnectRequest.fromMap(snapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      print('Error fetching connect request: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    final authProvider = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);

    if (arguments is! MessageRequest && arguments is! UserModel) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error', style: TextStyle(color: AppColors.mainFontColor))),
        body: const Center(child: Text('Invalid data provided')),
      );
    }

    final isRequest = arguments is MessageRequest;
    final request = isRequest ? arguments as MessageRequest : null;
    final recipient = isRequest ? null : arguments as UserModel;

    if (authProvider.currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Message Request', style: TextStyle(color: AppColors.mainFontColor))),
        body: const Center(child: Text('Please log in to send messages')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isRequest ? 'Message Request' : 'Send Message Request',
          style: const TextStyle(color: AppColors.mainFontColor, fontFamily: 'Poppins'),
        ),
        backgroundColor: AppColors.white.withOpacity(0.95),
        foregroundColor: AppColors.mainFontColor,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.profileGradient),
        padding: const EdgeInsets.all(16),
        child: CustomCard(
          glassEffect: true,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isRequest) ...[
                FutureBuilder<UserModel?>(
                  future: _fetchUser(request!.senderId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.primaryTeal));
                    }
                    if (!snapshot.hasData || snapshot.hasError) {
                      return const Text('Error loading sender details', style: TextStyle(color: AppColors.accentRed));
                    }
                    final sender = snapshot.data!;
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.grey600.withOpacity(0.2),
                        backgroundImage: sender.photoURL.isNotEmpty
                            ? CachedNetworkImageProvider(sender.photoURL)
                            : null,
                        child: sender.photoURL.isEmpty
                            ? const Icon(Icons.person, color: AppColors.grey600)
                            : null,
                      ),
                      title: Text(
                        sender.displayName!,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.mainFontColor,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      subtitle: Text(
                        request.message,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.grey600,
                            ),
                      ),
                    ).animate().fadeIn(duration: 700.ms);
                  },
                ),
                const SizedBox(height: 16),
                FutureBuilder<ConnectRequest?>(
                  future: _fetchConnectRequest(request!.senderId, authProvider.currentUser!.uid),
                  builder: (context, snapshot) {
                    final connectRequest = snapshot.data;
                    return Column(
                      children: [
                        if (connectRequest != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'This message is part of a pending connect request.',
                              style: TextStyle(
                                color: AppColors.primaryTeal,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CustomButton(
                              text: 'Accept',
                              gradient: AppColors.buttonGradient,
                              isLoading: _isLoading,
                              onPressed: _isLoading
                                  ? null
                                  : () async {
                                      setState(() => _isLoading = true);
                                      final sender = await _fetchUser(request.senderId);
                                      if (sender != null) {
                                        try {
                                          await chatProvider.acceptConnectRequest(
                                            connectRequestId: connectRequest?.id,
                                            messageRequest: request,
                                            sender: sender,
                                            context: context,
                                            recipient: authProvider.currentUser!,
                                          );
                                          if (mounted) {
                                            _scaffoldMessenger?.showSnackBar(
                                              const SnackBar(content: Text('Request accepted')),
                                            );
                                            Navigator.pop(context);
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            _scaffoldMessenger?.showSnackBar(
                                              SnackBar(content: Text('Error: $e')),
                                            );
                                          }
                                        }
                                      }
                                      setState(() => _isLoading = false);
                                    },
                            ).animate().slideX(begin: -0.1, end: 0, duration: 500.ms),
                            const SizedBox(width: 16),
                            CustomButton(
                              text: 'Deny',
                              color: AppColors.accentRed,
                             // textColor: AppColors.white,
                              isLoading: _isLoading,
                              onPressed: _isLoading
                                  ? null
                                  : () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Deny Request'),
                                          content: const Text('Are you sure you want to deny this request?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              child: const Text('Deny', style: TextStyle(color: AppColors.accentRed)),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        setState(() => _isLoading = true);
                                        try {
                                          await chatProvider.denyConnectRequest(
                                            connectRequestId: connectRequest!.id,
                                            messageRequestId: request.requestId,
                                          );
                                          if (mounted) {
                                            _scaffoldMessenger?.showSnackBar(
                                              const SnackBar(content: Text('Request denied')),
                                            );
                                            Navigator.pop(context);
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            _scaffoldMessenger?.showSnackBar(
                                              SnackBar(content: Text('Error: $e')),
                                            );
                                          }
                                        }
                                        setState(() => _isLoading = false);
                                      }
                                    },
                            ).animate().slideX(begin: 0.1, end: 0, duration: 500.ms),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ] else ...[
                ListTile(
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.textLight.withOpacity(0.2),
                    backgroundImage: recipient!.photoURL.isNotEmpty
                        ? CachedNetworkImageProvider(recipient.photoURL)
                        : null,
                    child: recipient.photoURL.isEmpty
                        ? const Icon(Icons.person, color: AppColors.grey600)
                        : null,
                  ),
                  title: Text(
                    recipient!.displayName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.mainFontColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  subtitle: Text(
                    'Mood: ${recipient.mood ?? 'Not set'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.grey600,
                        ),
                  ),
                ).animate().fadeIn(duration: 700.ms),
                const SizedBox(height: 24),
                TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    labelText: 'Your Message',
                    labelStyle: const TextStyle(color: AppColors.mainFontColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryTeal),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryTeal, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.8),
                    contentPadding: const EdgeInsets.all(16),
                    hintText: 'Type your message here...',
                    hintStyle: const TextStyle(color: AppColors.grey600),
                  ),
                  maxLines: 5,
                  style: const TextStyle(fontFamily: 'Poppins', color: AppColors.textDark),
                ).animate().slideY(begin: 0.2, end: 0, duration: 500.ms),
                const SizedBox(height: 24),
                FutureBuilder<ConnectRequest?>(
                  future: _fetchConnectRequest(authProvider.currentUser!.uid, recipient!.uid),
                  builder: (context, snapshot) {
                    final existingRequest = snapshot.data;
                    if (existingRequest != null) {
                      return Text(
                        'A connect request has already been sent.',
                        style: TextStyle(
                          color: AppColors.accentRed,
                          fontStyle: FontStyle.italic,
                        ),
                      );
                    }
                    return CustomButton(
                      text: 'Send Connect Request with Message',
                      gradient: AppColors.buttonGradient,
                      isLoading: _isLoading,
                      onPressed: _isLoading || existingRequest != null
                          ? null
                          : () async {
                              if (_messageController.text.trim().isEmpty) {
                                _scaffoldMessenger?.showSnackBar(
                                  const SnackBar(content: Text('Please enter a message')),
                                );
                                return;
                              }
                              setState(() => _isLoading = true);
                              try {
                                await chatProvider.sendMessageRequest(
                                  context: context,
                                  senderId: authProvider.currentUser!.uid,
                                  recipientId: recipient!.uid,
                                  message: _messageController.text.trim(),
                                );
                                if (mounted) {
                                  _scaffoldMessenger?.showSnackBar(
                                    const SnackBar(content: Text('Connect and message request sent')),
                                  );
                                  Navigator.pop(context);
                                }
                              } catch (e) {
                                if (mounted) {
                                  _scaffoldMessenger?.showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              }
                              setState(() => _isLoading = false);
                            },
                    ).animate().fadeIn(duration: 500.ms, delay: 200.ms);
                  },
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}