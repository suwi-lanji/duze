import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:duze/core/models/notification_model.dart';
import 'package:flutter/material.dart';

class NotificationProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  bool _isInitialized = false;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void initialize(String userId) {
    if (_isInitialized) {
      print('NotificationProvider already initialized for user: $userId');
      return;
    }
    _isInitialized = true;
    print('Initializing NotificationProvider for user: $userId');
    _loadNotifications(userId);
  }

  Future<void> _loadNotifications(String userId) async {
    _isLoading = true;
    notifyListeners();
    print('Loading notifications for user: $userId');

    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();
      _notifications = snapshot.docs.map((doc) => NotificationModel.fromMap(doc.data())).toList();
      // Sort by isRead (unseen first) and then by timestamp
      _notifications.sort((a, b) {
        if (a.isRead == b.isRead) {
          return b.timestamp.compareTo(a.timestamp); // Descending by timestamp
        }
        return a.isRead ? 1 : -1; // Unseen (isRead: false) first
      });
      print('Loaded ${_notifications.length} notifications');
    } catch (e) {
      print('Error loading notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
      print('Finished loading notifications, isLoading: $_isLoading');
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      print('Marking notification $notificationId as read');
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
      _notifications = _notifications.map((n) => n.id == notificationId
          ? NotificationModel(
              id: n.id,
              userId: n.userId,
              type: n.type,
              content: n.content,
              itemId: n.itemId,
              timestamp: n.timestamp,
              isRead: true,
            )
          : n).toList();
      // Re-sort after marking as read
      _notifications.sort((a, b) {
        if (a.isRead == b.isRead) {
          return b.timestamp.compareTo(a.timestamp);
        }
        return a.isRead ? 1 : -1;
      });
      notifyListeners();
      print('Notification $notificationId marked as read');
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> addNotification({
    required String userId,
    required String type,
    required String content,
    required String itemId,
  }) async {
    try {
      print('Adding notification for user: $userId, type: $type');
      final id = _firestore.collection('notifications').doc().id;
      final notification = NotificationModel(
        id: id,
        userId: userId,
        type: type,
        content: content,
        itemId: itemId,
        timestamp: DateTime.now(),
        isRead: false,
      );
      await _firestore.collection('notifications').doc(id).set(notification.toMap());
      _notifications.insert(0, notification);
      // Re-sort after adding new notification
      _notifications.sort((a, b) {
        if (a.isRead == b.isRead) {
          return b.timestamp.compareTo(a.timestamp);
        }
        return a.isRead ? 1 : -1;
      });
      notifyListeners();
      print('Notification $id added');
    } catch (e) {
      print('Error adding notification: $e');
    }
  }
}