import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:duze/config/routes.dart';
import 'package:duze/core/models/chat_model.dart';
import 'package:duze/core/models/message_model.dart';
import 'package:duze/core/models/user_model.dart';
import 'package:duze/features/auth/providers/auth_provider.dart';
import 'package:duze/features/chat/providers/chat_provider.dart';
import 'package:duze/shared/widgets/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({super.key});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();
  File? _selectedMedia;
  String? _mediaType;
  bool _isUploading = false;
  AudioPlayer? _audioPlayer;
  VideoPlayerController? _videoController;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _messageController.addListener(_updateTypingStatus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _messageController.removeListener(_updateTypingStatus);
    _messageController.dispose();
    _scrollController.dispose();
    _audioPlayer?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<UserModel?> _fetchUser(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      return UserModel.fromMap({...doc.data()!, 'uid': doc.id});
    } catch (e) {
      print('Error fetching user: $e');
      return null;
    }
  }

  void _updateTypingStatus() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chat = ModalRoute.of(context)!.settings.arguments! as Chat;
    final isTyping = _messageController.text.isNotEmpty;

    if (_isTyping != isTyping && authProvider.currentUser != null) {
      chatProvider.updateTypingStatus(
        chatId: chat.id,
        userId: authProvider.currentUser!.uid,
        isTyping: isTyping,
      );
      setState(() => _isTyping = isTyping);
    }
  }

  void _pickMedia(String type) async {
    try {
      XFile? pickedFile;
      if (type == 'image') {
        pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      } else if (type == 'video') {
        pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
      } else if (type == 'voice') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice notes not implemented yet')),
        );
        return;
      }
      if (pickedFile != null) {
        setState(() {
          _selectedMedia = File(pickedFile!.path);
          _mediaType = type;
        });
      }
    } catch (e) {
      print('Error picking media: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to pick media')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = ModalRoute.of(context)!.settings.arguments! as Chat;
    final authProvider = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);

    if (authProvider.currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: const Center(child: Text('Please log in to view chat')),
      );
    }

    final recipientId = chat.participants.firstWhere((uid) => uid != authProvider.currentUser!.uid);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.white.withOpacity(0.95),
        leading: FutureBuilder<UserModel?>(
          future: _fetchUser(recipientId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const CircleAvatar(child: CircularProgressIndicator());
            }
            final user = snapshot.data!;
            return GestureDetector(
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.userProfile,
                arguments: user,
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundImage: user.photoURL.isNotEmpty ? NetworkImage(user.photoURL) : null,
                      child: user.photoURL.isEmpty ? const Icon(Icons.person, color: AppColors.grey600) : null,
                    ),
                  ),
                  if (user.status == 'online')
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(BorderSide(color: AppColors.white, width: 2)),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        title: FutureBuilder<UserModel?>(
          future: _fetchUser(recipientId),
          builder: (context, snapshot) {
            final user = snapshot.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? 'Loading...',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (user?.status == 'online')
                  const Text(
                    'Online',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.green,
                      fontSize: 12,
                    ),
                  )
                else if (user?.lastActive != null)
                  Text(
                    'Last seen ${DateFormat('MMM d, HH:mm').format(user!.lastActive!)}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: AppColors.grey600,
                      fontSize: 12,
                    ),
                  ),
              ],
            );
          },
        ),
        centerTitle: false,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.profileGradient),
        child: Column(
          children: [
            if (chat.isPending)
              Container(
                padding: const EdgeInsets.all(8),
                color: AppColors.accentRed.withOpacity(0.2),
                child: Text(
                  'Waiting for connection to be accepted. Messaging is disabled.',
                  style: TextStyle(
                    color: AppColors.accentRed,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .doc(chat.id)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .limit(50)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primaryTeal));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final messages = snapshot.data!.docs
                      .map((doc) => Message.fromMap(doc.data() as Map<String, dynamic>))
                      .toList();

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    itemCount: messages.length + (chatProvider.isTyping(recipientId, chat.id) ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == 0 && chatProvider.isTyping(recipientId, chat.id)) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              Text(
                                'Typing...',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.grey600,
                                ),
                              ),
                              SizedBox(width: 8),
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryTeal),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(duration: 300.ms);
                      }
                      final message = messages[chatProvider.isTyping(recipientId, chat.id) ? index - 1 : index];
                      final isMe = message.senderId == authProvider.currentUser!.uid;
                      return _buildMessage(message, isMe).animate()
                          .slideX(
                            begin: isMe ? 0.2 : -0.2,
                            end: 0,
                            duration: 300.ms,
                            curve: Curves.easeOut,
                          )
                          .fadeIn(duration: 300.ms);
                    },
                  );
                },
              ),
            ),
            if (_selectedMedia != null && !chat.isPending)
              Container(
                padding: const EdgeInsets.all(8),
                color: AppColors.white.withOpacity(0.8),
                child: Row(
                  children: [
                    _mediaType == 'image'
                        ? Image.file(_selectedMedia!, height: 50, width: 50, fit: BoxFit.cover)
                        : _mediaType == 'video'
                            ? const Icon(Icons.videocam, size: 50, color: AppColors.primaryTeal)
                            : const Icon(Icons.mic, size: 50, color: AppColors.primaryTeal),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Selected $_mediaType')),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.accentRed),
                      onPressed: () => setState(() {
                        _selectedMedia = null;
                        _mediaType = null;
                      }),
                    ),
                  ],
                ),
              ),
            if (!chat.isPending)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.image, color: AppColors.primaryTeal),
                      onPressed: () => _pickMedia('image'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.videocam, color: AppColors.primaryTeal),
                      onPressed: () => _pickMedia('video'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.mic, color: AppColors.primaryTeal),
                      onPressed: () => _pickMedia('voice'),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppColors.white.withOpacity(0.8),
                        ),
                      ).animate(onPlay: (controller) {
                        if (_messageController.text.isNotEmpty) {
                          controller.forward();
                        }
                      }).scaleXY(begin: 0.98, end: 1, duration: 200.ms),
                    ),
                    IconButton(
                      icon: _isUploading
                          ? const CircularProgressIndicator(color: AppColors.primaryTeal)
                          : const Icon(Icons.send, color: AppColors.primaryTeal),
                      onPressed: _isUploading
                          ? null
                          : () async {
                              final content = _messageController.text.trim();
                              String type = 'text';
                              final mediaFile = _selectedMedia;

                              if (mediaFile != null && _mediaType != null) {
                                type = _mediaType!;
                              } else if (content.isEmpty && mediaFile == null) {
                                return;
                              }

                              setState(() => _isUploading = true);
                              try {
                                await chatProvider.sendMessage(
                                  context: context,
                                  chatId: chat.id,
                                  senderId: authProvider.currentUser!.uid,
                                  content: content.isEmpty && mediaFile != null ? type : content,
                                  type: type,
                                  mediaFile: mediaFile,
                                );
                                _messageController.clear();
                                setState(() {
                                  _selectedMedia = null;
                                  _mediaType = null;
                                });
                                _scrollToBottom();
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              } finally {
                                setState(() => _isUploading = false);
                              }
                            },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(Message message, bool isMe) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMe ? AppColors.primaryTeal.withOpacity(0.8) : AppColors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _buildMessageContent(message, isMe),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('HH:mm').format(message.timestamp),
            style: const TextStyle(color: AppColors.grey600, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(Message message, bool isMe) {
    switch (message.type) {
      case 'image':
        return CachedNetworkImage(
          imageUrl: message.mediaUrl ?? '',
          width: 200,
          height: 200,
          fit: BoxFit.cover,
          placeholder: (context, url) => const CircularProgressIndicator(),
          errorWidget: (context, url, error) => const Icon(Icons.error),
        );
      case 'video':
        return GestureDetector(
          onTap: () {
            setState(() {
              _videoController = VideoPlayerController.networkUrl(Uri.parse(message.mediaUrl!))
                ..initialize().then((_) => setState(() {}));
              _videoController!.play();
            });
            showDialog(
              context: context,
              builder: (context) => Dialog(
                child: _videoController != null && _videoController!.value.isInitialized
                    ? AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      )
                    : const CircularProgressIndicator(),
              ),
            );
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 200,
                height: 200,
                color: AppColors.grey600,
              ),
              const Icon(Icons.play_arrow, color: AppColors.white, size: 50),
            ],
          ),
        );
      case 'voice':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow, color: AppColors.primaryTeal),
              onPressed: () async {
                if (message.mediaUrl != null) {
                  await _audioPlayer!.play(UrlSource(message.mediaUrl!));
                }
              },
            ),
            const Text('Voice Note'),
          ],
        );
      default:
        return Text(
          message.content,
          style: TextStyle(
            color: isMe ? AppColors.white : AppColors.textDark,
            fontFamily: 'Poppins',
          ),
        );
    }
  }
}