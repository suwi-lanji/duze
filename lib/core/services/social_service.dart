
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/user_model.dart';

class SocialService {
  // Facebook Graph API integration
  Future<List<String>> getFacebookFriends(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('https://graph.facebook.com/me/friends?access_token=$accessToken'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final friends = data['data'] as List;
        return friends.map((friend) => friend['id'].toString()).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching Facebook friends: $e');
      return [];
    }
  }

  // Twitter API integration (simplified)
  Future<List<String>> getTwitterFollowing(String accessToken) async {
    try {
      // Note: Twitter API v2 requires more complex authentication
      // This is a simplified example
      final response = await http.get(
        Uri.parse('https://api.twitter.com/2/users/by/username/me/following'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final following = data['data'] as List;
        return following.map((user) => user['id'].toString()).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching Twitter following: $e');
      return [];
    }
  }

  // Find mutual connections between users
  Future<List<String>> findMutualConnections(
    String userId1,
    String userId2,
    String platform,
  ) async {
    try {
      // This would query your database to find mutual connections
      // between two users on a specific platform
      return [];
    } catch (e) {
      print('Error finding mutual connections: $e');
      return [];
    }
  }

  // Sync user's social connections to database
  Future<void> syncSocialConnections(
    String userId,
    String platform,
    List<String> connections,
  ) async {
    try {
      // Store connections in Firestore
      final batch = FirebaseFirestore.instance.batch();
      
      for (String connectionId in connections) {
        final docRef = FirebaseFirestore.instance
            .collection('connections')
            .doc();
        
        batch.set(docRef, {
          'userId': userId,
          'platform': platform,
          'connectionId': connectionId,
          'syncedAt': DateTime.now(),
        });
      }
      
      await batch.commit();
    } catch (e) {
      print('Error syncing social connections: $e');
    }
  }
}