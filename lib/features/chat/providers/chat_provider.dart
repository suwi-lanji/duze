import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:duze/config/routes.dart';
import 'package:duze/core/models/chat_model.dart';
import 'package:duze/core/models/connect_request_model.dart';
import 'package:duze/core/models/message_model.dart';
import 'package:duze/core/models/message_request_model.dart';
import 'package:duze/core/models/user_model.dart';
import 'package:duze/core/services/notification_service.dart';

import 'package:duze/features/notifications/providers/notification_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';

class ChatProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Chat> _chats = [];
  List<MessageRequest> _pendingRequests = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  final Map<String, Map<String, bool>> _typingStatus = {};

  List<Chat> get chats => _chats;
  List<MessageRequest> get pendingRequests => _pendingRequests;
  bool get isLoading => _isLoading;
  final Map<String, UserModel> _userCache = {}; // Cache for user data

  final String _cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? 'your_cloud_name';
  final String _apiKey = dotenv.env['CLOUDINARY_API_KEY'] ?? 'your_api_key';
  final String _apiSecret = dotenv.env['CLOUDINARY_API_SECRET'] ?? 'your_api_secret';

  ChatProvider();

  void initialize(String userId) {
    if (_isInitialized) {
      print('ChatProvider initialized for user: $userId');
      return;
    }
    _isInitialized = true;
    _isLoading = true;
    notifyListeners();
    print('Initializing ChatProvider for user: $userId');
    _loadChats(userId);
    _loadPendingRequests(userId);
    _loadPendingSentRequests(userId);
  }

  Future<void> fetchChats(String userId) async {
    _isLoading = true;
    notifyListeners();
    print('Fetching chats for user: $userId');
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: userId)
          .orderBy('lastMessageTimestamp', descending: true)
          .get();
      _chats = querySnapshot.docs.map((doc) => Chat.fromMap(doc.data())).toList();
      print('Loaded ${_chats.length} chats');
    } catch (e) {
      print('Error fetching chats: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadChats(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: userId)
          .orderBy('lastMessageTimestamp', descending: true)
          .get();
      _chats = snapshot.docs.map((doc) => Chat.fromMap(doc.data())).toList();
      print('Loaded ${_chats.length} chats');
    } catch (e) {
      print('Error loading chats: $e');
    } finally {
      _updateLoadingState();
    }
  }

  Future<void> _loadPendingRequests(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('pendingMessages')
          .where('recipientId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .orderBy('timestamp', descending: true)
          .get();
      _pendingRequests = snapshot.docs.map((doc) => MessageRequest.fromMap(doc.data())).toList();
      print('Loaded ${_pendingRequests.length} pending requests received');
    } catch (e) {
      print('Error loading pending requests: $e');
    } finally {
      _updateLoadingState();
    }
  }

  Future<void> _loadPendingSentRequests(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('friendRequests')
          .where('senderId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();
      for (var doc in snapshot.docs) {
        final connectRequest = ConnectRequest.fromMap(doc.data());
        if (connectRequest.messageRequestId != null) {
          final messageDoc = await _firestore
              .collection('pendingMessages')
              .doc(connectRequest.messageRequestId)
              .get();
          if (messageDoc.exists) {
            final messageRequest = MessageRequest.fromMap(messageDoc.data()!);
            final chat = Chat(
              id: connectRequest.id,
              participants: [connectRequest.senderId, connectRequest.recipientId],
              lastMessage: messageRequest.message!,
              lastMessageTimestamp: messageRequest.timestamp,
              unreadCount: {connectRequest.senderId: 0, connectRequest.recipientId: 1},
              isPending: true,
              senderId: connectRequest.senderId,
            );
            if (!_chats.any((c) => c.id == chat.id)) {
              _chats.add(chat);
            }
          }
        }
      }
      _chats.sort((a, b) => b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp));
      notifyListeners();
      print('Loaded pending sent message requests as chats');
    } catch (e) {
      print('Error loading pending sent requests: $e');
    }
  }

  void _updateLoadingState() {
    _isLoading = false;
    notifyListeners();
    print('Updated loading state: isLoading = $_isLoading');
  }

  Future<bool> isFriend(String userId1, String userId2) async {
    try {
      final doc = await _firestore.collection('relationships').doc(userId1).get();
      if (!doc.exists) return false;
      final friends = (doc.data()?['friends'] as List<dynamic>?)?.cast<String>() ?? [];
      return friends.contains(userId2);
    } catch (e) {
      print('Error checking friendship: $e');
      return false;
    }
  }

  Future<bool> _hasExistingChat(String userId1, String userId2) async {
    try {
      final snapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: userId1)
          .get();
      return snapshot.docs.any((doc) {
        final participants = List<String>.from(doc['participants']);
        return participants.contains(userId2);
      });
    } catch (e) {
      print('Error checking existing chat: $e');
      return false;
    }
  }

  Future<Chat?> getExistingChat(String userId1, String userId2) async {
    try {
      final snapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: userId1)
          .get();
      final chatDoc = snapshot.docs.firstWhere(
        (doc) {
          final participants = List<String>.from(doc['participants']);
          return participants.contains(userId2);
        },
        orElse: () => throw Exception('No chat found'),
      );
      return Chat.fromMap(chatDoc.data());
    } catch (e) {
      print('Error getting existing chat: $e');
      return null;
    }
  }

  Future<String?> _uploadToCloudinary(File file, String type) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/$type/upload');
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final publicId = 'chat_media_${DateTime.now().millisecondsSinceEpoch}';
      final signatureString = 'public_id=$publicId&timestamp=$timestamp$_apiSecret';
      final signature = sha1.convert(utf8.encode(signatureString)).toString();

      final request = http.MultipartRequest('POST', url)
        ..fields['api_key'] = _apiKey
        ..fields['timestamp'] = timestamp
        ..fields['signature'] = signature
        ..fields['public_id'] = publicId
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonData = json.decode(responseData);
        print('Cloudinary upload successful: ${jsonData['secure_url']}');
        return jsonData['secure_url'];
      } else {
        print('Cloudinary upload failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error uploading to Cloudinary: $e');
      return null;
    }
  }

  Future<void> sendConnectRequest({
    required BuildContext context,
    required String senderId,
    required String recipientId,
    String? message,
  }) async {
    try {
      print('Sending connect request from $senderId to $recipientId');

      final snapshot = await _firestore
          .collection('friendRequests')
          .where('senderId', isEqualTo: senderId)
          .where('recipientId', isEqualTo: recipientId)
          .where('status', isEqualTo: 'pending')
          .get();
      if (snapshot.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A connect request already exists')),
        );
        return;
      }

      final connectRequestId = _firestore.collection('friendRequests').doc().id;
      String? messageRequestId;

      if (message != null) {
        final requestId = _firestore.collection('pendingMessages').doc().id;
        final messageRequest = MessageRequest(
          requestId: requestId,
          senderId: senderId,
          recipientId: recipientId,
          message: message,
          timestamp: DateTime.now(),
          status: 'pending',
        );
        await _firestore.collection('pendingMessages').doc(requestId).set(messageRequest.toMap());
        messageRequestId = requestId;

        final chat = Chat(
          id: requestId,
          participants: [senderId, recipientId],
          lastMessage: message,
          lastMessageTimestamp: DateTime.now(),
          unreadCount: {senderId: 0, recipientId: 1},
          isPending: true,
          senderId: senderId,
        );
        await _firestore.collection('chats').doc(requestId).set(chat.toMap());
        _chats.add(chat);
        _chats.sort((a, b) => b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp));
      }

      final connectRequest = ConnectRequest(
        id: connectRequestId,
        senderId: senderId,
        recipientId: recipientId,
        messageRequestId: messageRequestId,
        status: 'pending',
        timestamp: DateTime.now(),
      );
      await _firestore.collection('friendRequests').doc(connectRequestId).set(connectRequest.toMap());

      final senderDoc = await _firestore.collection('users').doc(senderId).get();
      final senderName = senderDoc.data()?['displayName'] ?? 'Unknown User';

      if (message != null) {
        await NotificationService().showMessageRequestNotification(
          requestId: messageRequestId!,
          senderName: senderName,
          message: message, recipientId:recipientId, context: context,
        );
      }

      final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
      await notificationProvider.addNotification(
        userId: recipientId,
        type: message != null ? 'message_request' : 'friend_request',
        content: message != null
            ? 'Message request from $senderName: $message'
            : 'Connect request from $senderName',
        itemId: messageRequestId ?? connectRequestId,
      );

      notifyListeners();
      print('Connect request sent successfully');
    } catch (e) {
      print('Error sending connect request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send connect request: $e')),
      );
    }
  }

  Future<void> sendMessageRequest({
    required BuildContext context,
    required String senderId,
    required String recipientId,
    required String message,
  }) async {
    try {
      print('Sending message request from $senderId to $recipientId: $message');

      if (await isFriend(senderId, recipientId)) {
        final chat = await getExistingChat(senderId, recipientId);
        if (chat != null) {
          print('Found existing chat: ${chat.id}');
          Navigator.pushNamed(context, AppRoutes.chatDetail, arguments: chat);
          return;
        }
      }

      final snapshot = await _firestore
          .collection('friendRequests')
          .where('senderId', isEqualTo: senderId)
          .where('recipientId', isEqualTo: recipientId)
          .where('status', isEqualTo: 'pending')
          .get();
      if (snapshot.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A connect request already exists')),
        );
        return;
      }

      await sendConnectRequest(
        context: context,
        senderId: senderId,
        recipientId: recipientId,
        message: message,
      );
    } catch (e) {
      print('Error sending message request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message request: $e')),
      );
    }
  }

  Future<void> acceptConnectRequest({
    required BuildContext context,
    required String? connectRequestId,
    required MessageRequest? messageRequest,
    required UserModel sender,
    required UserModel recipient,
  }) async {
    try {
      print('Accepting connect request: $connectRequestId');

      if (connectRequestId != null) {
        await _firestore.collection('friendRequests').doc(connectRequestId).update({
          'status': 'accepted',
        });
      }

      if (messageRequest != null) {
        await _firestore.collection('pendingMessages').doc(messageRequest.requestId).update({
          'status': 'accepted',
        });
      }

      await _firestore.collection('relationships').doc(sender.uid).set({
        'friends': FieldValue.arrayUnion([recipient.uid]),
      }, SetOptions(merge: true));
      await _firestore.collection('relationships').doc(recipient.uid).set({
        'friends': FieldValue.arrayUnion([sender.uid]),
      }, SetOptions(merge: true));

      String chatId = messageRequest?.requestId ?? connectRequestId ?? _firestore.collection('chats').doc().id;
      if (messageRequest != null) {
        final chat = Chat(
          id: messageRequest.requestId,
          participants: [sender.uid, recipient.uid],
          lastMessage: messageRequest.message,
          lastMessageTimestamp: DateTime.now(),
          unreadCount: {sender.uid: 0, recipient.uid: 1},
          isPending: false,
          senderId: messageRequest.senderId,
        );
        await _firestore.collection('chats').doc(messageRequest.requestId).set(chat.toMap());

        final messageId = _firestore.collection('chats').doc(messageRequest.requestId).collection('messages').doc().id;
        await _firestore.collection('chats').doc(messageRequest.requestId).collection('messages').doc(messageId).set({
          'messageId': messageId,
          'senderId': messageRequest.senderId,
          'content': messageRequest.message,
          'timestamp': Timestamp.now(),
          'type': 'text',
        });

        _chats = _chats.map((c) => c.id == messageRequest.requestId ? chat : c).toList();
        _pendingRequests.removeWhere((r) => r.requestId == messageRequest.requestId);
      } else {
        final chat = Chat(
          id: chatId,
          participants: [sender.uid, recipient.uid],
          lastMessage: 'Connected!',
          lastMessageTimestamp: DateTime.now(),
          unreadCount: {sender.uid: 0, recipient.uid: 0},
          isPending: false,
          senderId: sender.uid,
        );
        await _firestore.collection('chats').doc(chatId).set(chat.toMap());
        _chats.add(chat);
      }

      _chats.sort((a, b) => b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp));

      final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
      await notificationProvider.addNotification(
        userId: sender.uid,
        type: 'request_accept',
        content: '${recipient.displayName} accepted your request',
        itemId: chatId,
      );

      await NotificationService().showAcceptNotification(
        requestId: chatId,
        recipientName: recipient.displayName,recipientId:recipient.uid, context: context,
      );

      notifyListeners();
      print('Connect request accepted');
    } catch (e) {
      print('Error accepting connect request: $e');
      rethrow;
    }
  }

Future<void> acceptConnectRequestNew({
    required BuildContext context,
    required String requestId,
    required String senderId,
    required String recipientId,
  }) async {
    try {
      print('Accepting connect request: $requestId');

      final requestDoc = await _firestore.collection('friendRequests').doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Connect request not found');
      }
      final connectRequest = ConnectRequest.fromMap(requestDoc.data()!);

      await _firestore.collection('friendRequests').doc(requestId).update({
        'status': 'accepted',
      });

      if (connectRequest.messageRequestId != null) {
        await _firestore.collection('pendingMessages').doc(connectRequest.messageRequestId).update({
          'status': 'accepted',
        });
      }

      await _firestore.collection('relationships').doc(senderId).set({
        'friends': FieldValue.arrayUnion([recipientId]),
      }, SetOptions(merge: true));
      await _firestore.collection('relationships').doc(recipientId).set({
        'friends': FieldValue.arrayUnion([senderId]),
      }, SetOptions(merge: true));

      String chatId = connectRequest.messageRequestId ?? requestId;
      Chat chat;
      if (connectRequest.messageRequestId != null) {
        final messageDoc = await _firestore.collection('pendingMessages').doc(connectRequest.messageRequestId).get();
        final messageRequest = MessageRequest.fromMap(messageDoc.data()!);
        chat = Chat(
          id: chatId,
          participants: [senderId, recipientId],
          lastMessage: messageRequest.message!,
          lastMessageTimestamp: DateTime.now(),
          unreadCount: {senderId: 0, recipientId: 0},
          isPending: false,
          senderId: senderId,
        );
        await _firestore.collection('chats').doc(chatId).update(chat.toMap());

        final messageId = _firestore.collection('chats').doc(chatId).collection('messages').doc().id;
        await _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId).set({
          'messageId': messageId,
          'senderId': senderId,
          'content': messageRequest.message,
          'timestamp': Timestamp.now(),
          'type': 'text',
        });

        _chats = _chats.map((c) => c.id == chatId ? chat : c).toList();
        _pendingRequests.removeWhere((r) => r.requestId == connectRequest.messageRequestId);
      } else {
        chat = Chat(
          id: chatId,
          participants: [senderId, recipientId],
          lastMessage: 'Connected!',
          lastMessageTimestamp: DateTime.now(),
          unreadCount: {senderId: 0, recipientId: 0},
          isPending: false,
          senderId: senderId,
        );
        await _firestore.collection('chats').doc(chatId).set(chat.toMap());
        if (!_chats.any((c) => c.id == chatId)) {
          _chats.add(chat);
        }
      }

      _chats.sort((a, b) => b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp));

      final sender = await _fetchUser(senderId);
      final recipient = await _fetchUser(recipientId);
      final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
      await notificationProvider.addNotification(
        userId: senderId,
        type: 'request_accept',
        content: '${recipient?.displayName ?? 'Someone'} accepted your request',
        itemId: chatId,
      );

      await NotificationService().showAcceptNotification(
        requestId: chatId,
        recipientName: recipient?.displayName ?? 'Someone',recipientId:recipientId, context: context,
      );

      notifyListeners();
      print('Connect request accepted: $requestId');
    } catch (e) {
      print('Error accepting connect request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to accept connect request')),
      );
      rethrow;
    }
  }


 Future<UserModel?> _fetchUser(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      final user = UserModel.fromMap({...doc.data()!, 'uid': doc.id});
      _userCache[userId] = user;
      return user;
    } catch (e) {
      print('Error fetching user: $e');
      return null;
    }
  }

  Future<void> denyConnectRequest({
    required String? connectRequestId,
    required String? messageRequestId,
  }) async {
    try {
      print('Denying connect request: $connectRequestId');
      if (connectRequestId != null) {
        await _firestore.collection('friendRequests').doc(connectRequestId).update({
          'status': 'denied',
        });
      }
      if (messageRequestId != null) {
        await _firestore.collection('pendingMessages').doc(messageRequestId).update({
          'status': 'denied',
        });
        await _firestore.collection('chats').doc(messageRequestId).delete();
        _chats.removeWhere((c) => c.id == messageRequestId);
        _pendingRequests.removeWhere((r) => r.requestId == messageRequestId);
      }
      notifyListeners();
      print('Connect request denied');
    } catch (e) {
      print('Error denying connect request: $e');
      rethrow;
    }
  }

  Future<void> sendMessage({
    required BuildContext context,
    required String chatId,
    required String senderId,
    required String content,
    required String type,
    File? mediaFile,
  }) async {
    try {
      print('Sending message to chat: $chatId, type: $type');

      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (chatDoc.exists && chatDoc.data()!['isPending'] == true) {
        throw Exception('Cannot send messages until connection is accepted');
      }

      String? mediaUrl;
      if (mediaFile != null) {
        mediaUrl = await _uploadToCloudinary(
          mediaFile,
          type == 'image' ? 'image' : type == 'video' ? 'video' : 'raw',
        );
        if (mediaUrl == null) {
          throw Exception('Media upload failed');
        }
      }

      final messageId = _firestore.collection('chats').doc(chatId).collection('messages').doc().id;
      final message = Message(
        messageId: messageId,
        senderId: senderId,
        content: content,
        timestamp: DateTime.now(),
        type: type,
        mediaUrl: mediaUrl,
      );
      await _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId).set(message.toMap());

      final chat = _chats.firstWhere((c) => c.id == chatId);
      final updatedUnread = Map<String, int>.from(chat.unreadCount);
      chat.participants.forEach((uid) {
        if (uid != senderId) {
          updatedUnread[uid] = (updatedUnread[uid] ?? 0) + 1;
        } else {
          updatedUnread[uid] = 0; // Reset unread count for sender
        }
      });
      final updatedChat = Chat(
        id: chat.id,
        participants: chat.participants,
        lastMessage: content,
        lastMessageTimestamp: DateTime.now(),
        unreadCount: updatedUnread,
        isPending: chat.isPending,
        senderId: senderId,
      );
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': content,
        'lastMessageTimestamp': Timestamp.now(),
        'unreadCount': updatedUnread,
      });

      _chats = _chats.map((c) => c.id == chatId ? updatedChat : c).toList();
      _chats.sort((a, b) => b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp));

      final senderDoc = await _firestore.collection('users').doc(senderId).get();
      final senderName = senderDoc.data()?['userName'] ?? 'Unknown User';
      final recipientId = chat.participants.firstWhere((uid) => uid != senderId);
      final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
      await notificationProvider.addNotification(
        userId: recipientId,
        type: 'message',
        content: 'New message from $senderName: $content',
        itemId: chatId,
      );

      notifyListeners();
      print('Message sent successfully');
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  Future<void> acceptMessageRequest({
    required BuildContext context,
    required MessageRequest request,
    required UserModel sender,
    required UserModel recipient,
  }) async {
    final snapshot = await _firestore
        .collection('friendRequests')
        .where('messageRequestId', isEqualTo: request.requestId)
        .get();
    if (snapshot.docs.isNotEmpty) {
      await acceptConnectRequest(
        context: context,
        connectRequestId: snapshot.docs.first.id,
        messageRequest: request,
        sender: sender,
        recipient: recipient,
      );
    }
  }

  Future<void> denyMessageRequest(String requestId) async {
    final snapshot = await _firestore
        .collection('friendRequests')
        .where('messageRequestId', isEqualTo: requestId)
        .get();
    if (snapshot.docs.isNotEmpty) {
      await denyConnectRequest(
        connectRequestId: snapshot.docs.first.id,
        messageRequestId: requestId,
      );
    }
  }

  Future<void> sendPostNotification({
    required BuildContext context,
    required String senderId,
    required String postOwnerId,
    required String postId,
    required String type,
    required String content,
  }) async {
    try {
      final senderDoc = await _firestore.collection('users').doc(senderId).get();
      final senderName = senderDoc.data()?['userName'] ?? 'Unknown User';

      final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
      await notificationProvider.addNotification(
        userId: postOwnerId,
        type: type == 'like' ? 'post_like' : 'post_comment',
        content: type == 'like' ? '$senderName liked your post' : '$senderName commented on your post: $content',
        itemId: postId,
      );

      await NotificationService().showPostNotification(
        postId: postId,
        senderName: senderName,
        type: type,
        content: content,
        recipientId:postOwnerId, context: context,
      );
    } catch (e) {
      print('Error sending post notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send post notification: $e')),
      );
    }
  }

  void updateTypingStatus({
    required String chatId,
    required String userId,
    required bool isTyping,
  }) {
    if (!_typingStatus.containsKey(chatId)) {
      _typingStatus[chatId] = {};
    }
    _typingStatus[chatId]![userId] = isTyping;
    _firestore.collection('chats').doc(chatId).update({
      'typing': {userId: isTyping},
    });
    notifyListeners();
  }

  bool isTyping(String userId, String chatId) {
    return _typingStatus[chatId]?[userId] ?? false;
  }

  Stream<Map<String, bool>> getTypingStatusStream(String chatId) {
    return _firestore.collection('chats').doc(chatId).snapshots().map((snapshot) {
      final data = snapshot.data();
      return (data?['typing'] as Map<String, dynamic>?)?.cast<String, bool>() ?? {};
    });
  }
}