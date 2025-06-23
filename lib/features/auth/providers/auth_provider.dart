// features/auth/providers/auth_provider.dart
import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:duze/core/models/user_model.dart';
import 'package:duze/main.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oauth1/oauth1.dart' as oauth1;
import 'package:url_launcher/url_launcher.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
   final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  UserModel? _currentUser;
  String? _errorMessage;
  bool _isLoading = false;

 static final CloudinaryPublic _cloudinary = CloudinaryPublic('dkltwubbb', 'ml_default');

  UserModel? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  User? _user;
  UserModel? _userModel;
 

  User? get user => _user;
  UserModel? get userModel => _userModel;
   bool _isAuthenticated = false; // Add this
  
   bool get isAuthenticated => _isAuthenticated; // Getter
  set isAuthenticated(bool value) {
    _isAuthenticated = value;
    _saveAuthState(value); // Persist state
    notifyListeners();
  }

  AuthProvider() {
    _initializeAuthState();
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        await _loadUserData(user.uid);
        isAuthenticated = true;
      } else {
        _currentUser = null;
        isAuthenticated = false;
      }
    });
  }

  Future<void> _initializeAuthState() async {
    // Check SharedPreferences for cached auth state
    final prefs = await SharedPreferences.getInstance();
    _isAuthenticated = prefs.getBool('isAuthenticated') ?? false;
    if (_auth.currentUser != null) {
      await _loadUserData(_auth.currentUser!.uid);
      isAuthenticated = true;
    }
    notifyListeners();
  }

  Future<void> _saveAuthState(bool isAuthenticated) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAuthenticated', isAuthenticated);
  }

 Future<void> _loadUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _currentUser = UserModel.fromMap(doc.data()!);
        print('Loaded user data: ${_currentUser!.displayName}');
        notifyListeners();
      } else {
        _errorMessage = 'User document not found';
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to load user data: $e';
      print('Error loading user data: $e');
      notifyListeners();
    }
  }

  Future<bool> registerWithEmail(String email, String password, String displayName) async {
    try {
      _setLoading(true);
      final userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final user = userCredential.user!;
      await user.updateDisplayName(displayName);

      final userModel = UserModel(
        uid: user.uid,
        email: email,
        displayName: displayName,
        createdAt: DateTime.now(),
      );
      await _firestore.collection('users').doc(user.uid).set(userModel.toMap());
      _currentUser = userModel;
      _clearError();
      notifyListeners();
       isAuthenticated = true;
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signInWithEmail(String email, String password) async {
    try {
      _setLoading(true);
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      if (userCredential.user == null) {
        _setError('Login failed: No user returned');
        return false;
      }
      await _loadUserData(userCredential.user!.uid);
      print('Email login successful: ${userCredential.user!.uid}');
      _clearError();
      notifyListeners();
       isAuthenticated = true;
      return true;
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'invalid-email':
          errorMessage = 'Invalid email address';
          break;
        case 'invalid-credential':
          errorMessage = 'Incorrect email or password';
          break;
        case 'user-disabled':
          errorMessage = 'User account is disabled';
          break;
        case 'user-not-found':
          errorMessage = 'No user found with this email';
          break;
        default:
          errorMessage = 'Login failed: ${e.message}';
      }
      _setError(errorMessage);
      print('FirebaseAuthException: $e');
      return false;
    } catch (e) {
      _setError('Unexpected error during login: $e');
      print('Unexpected error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

String _generateOAuth1Header(
    String consumerKey,
    String consumerSecret,
    String accessToken,
    String accessSecret,
    String method,
    String url,
  ) {
    // Simplified; use oauth1 package in production
    return 'OAuth oauth_consumer_key="$consumerKey", oauth_token="$accessToken", ...';
  }

 Future<void> _storeAccessToken(String uid, String platform, String token, {String? secret}) async {
    await _secureStorage.write(key: '${uid}_$platform', value: token);
    if (secret != null) {
      await _secureStorage.write(key: '${uid}_${platform}_secret', value: secret);
    }
  }

//   Twitter Authentication
  Future<bool> signInWithTwitter() async {
    try {
      _setLoading(true);
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        _setError('No user signed in.');
        return false;
      }

      await dotenv.load();
      final consumerKey = dotenv.env['TWITTER_API_KEY'];
      final consumerSecret = dotenv.env['TWITTER_API_SECRET'];
      final redirectUri = dotenv.env['TWITTER_REDIRECT_URI'] ?? 'duze://auth';

      final platform = oauth1.Platform(
        'https://api.twitter.com/oauth/request_token',
        'https://api.twitter.com/oauth/authorize',
        'https://api.twitter.com/oauth/access_token',
        oauth1.SignatureMethods.hmacSha1,
      );
      final clientCredentials = oauth1.ClientCredentials(consumerKey!, consumerSecret!);
      final auth = oauth1.Authorization(clientCredentials, platform);

      final requestTokenResponse = await auth.requestTemporaryCredentials(redirectUri);
      final requestToken = requestTokenResponse.credentials;

      final authUrl = auth.getResourceOwnerAuthorizationURI(requestToken.token);
      if (!await launchUrl(Uri.parse(authUrl), mode: LaunchMode.externalApplication)) {
        _setError('Failed to open Twitter authorization.');
        return false;
      }

      final verifier = await _getOAuthVerifier(); // Assume existing implementation
      if (verifier == null) {
        _setError('Invalid Twitter verifier.');
        return false;
      }

       final accessTokenResponse = await auth.requestTokenCredentials(
        requestToken,
        verifier,
      );
      final accessToken = accessTokenResponse.credentials;

      final client = oauth1.Client(platform.signatureMethod, clientCredentials, accessToken);
      final userResponse = await client.get(
        Uri.parse('https://api.twitter.com/2/users/me?user.fields=username'),
      );
      if (userResponse.statusCode != 200) {
        _setError('Failed to fetch Twitter profile: ${userResponse.body}');
        return false;
      }
      final userData = jsonDecode(userResponse.body)['data'];
      final twitterUsername = userData['username'];

      // Comment out followers/following due to free tier limitations
      /*
      final followersResponse = await client.get(
        Uri.parse('https://api.twitter.com/2/users/$userId/followers?max_results=100'),
      );
      final followers = jsonDecode(followersResponse.body)['data']?.map((f) => f['username']).toList() ?? [];
      final followingResponse = await client.get(
        Uri.parse('https://api.twitter.com/2/users/$userId/following?max_results=100'),
      );
      final following = jsonDecode(followingResponse.body)['data']?.map((f) => f['username']).toList() ?? [];
      */

      await _firestore.collection('users').doc(currentUser.uid).update({
        'twitterUsername': twitterUsername,
        // 'twitterFollowers': [], // Commented out
        // 'twitterFollowing': [], // Commented out
        'socialAccounts.twitter': {
          'platform': 'twitter',
          'id': currentUser.uid,
          'accessToken': accessToken.token,
        },
      });

      await _loadUserData(currentUser.uid);
      return true;
    } catch (e, stackTrace) {
      _setError('Twitter connection failed: $e');
      print('Error: $e\n$stackTrace');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Facebook Authentication
  Future<bool> signInWithFacebook() async {
    try {
      _setLoading(true);
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        _setError('No user signed in.');
        return false;
      }

      final result = await FacebookAuth.instance.login(permissions: ['public_profile', 'user_friends']);
      if (result.status != LoginStatus.success) {
        _setError('Facebook login failed: ${result.message}');
        return false;
      }

      final accessToken = result.accessToken!.token;
      final userResponse = await http.get(
        Uri.parse('https://graph.facebook.com/v22.0/me?fields=id,name,followers_count&access_token=$accessToken'),
      );
      if (userResponse.statusCode != 200) {
        _setError('Failed to fetch Facebook profile: ${userResponse.body}');
        return false;
      }
      final userData = jsonDecode(userResponse.body);
      final facebookUsername = userData['name'];
      final facebookFollowerCount = userData['followers_count'] ?? 0;

      final friendsResponse = await http.get(
        Uri.parse('https://graph.facebook.com/v22.0/me/friends?fields=id,name&access_token=$accessToken'),
      );
      List<String> facebookFriends = [];
      int facebookFriendCount = 0;
      if (friendsResponse.statusCode == 200) {
        final friendsData = jsonDecode(friendsResponse.body);
        final friendIds = (friendsData['data'] as List).map((f) => f['id'].toString()).toList();
        facebookFriendCount = friendsData['summary']?['total_count'] ?? friendIds.length;

        // Filter friends to only those registered in the app
        final usersSnapshot = await _firestore.collection('users').get();
        final appUserIds = usersSnapshot.docs
            .where((doc) => doc.data()['socialAccounts']?['facebook']?['id'] != null)
            .map((doc) => doc.data()['socialAccounts']['facebook']['id'].toString())
            .toList();
        facebookFriends = friendIds.where((id) => appUserIds.contains(id)).toList();
      }

      await _firestore.collection('users').doc(currentUser.uid).update({
        'facebookUsername': facebookUsername,
        'facebookFollowerCount': facebookFollowerCount,
        'facebookFriendCount': facebookFriendCount,
        'facebookFriends': facebookFriends,
        'socialAccounts.facebook': {
          'platform': 'facebook',
          'id': userData['id'],
          'accessToken': accessToken,
        },
      });

      await _loadUserData(currentUser.uid);
      return true;
    } catch (e, stackTrace) {
      _setError('Facebook connection failed: $e');
      print('Error: $e\n$stackTrace');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // TikTok Authentication
  Future<bool> signInWithTikTok() async {
    try {
      _setLoading(true);
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        _setError('No user signed in.');
        return false;
      }

      await dotenv.load();
      final clientKey = dotenv.env['TIKTOK_CLIENT_KEY'];
      final clientSecret = dotenv.env['TIKTOK_CLIENT_SECRET'];
      final redirectUri = dotenv.env['TIKTOK_REDIRECT_URI'] ?? 'duze://auth';

      final authUrl =
          'https://www.tiktok.com/v2/auth/authorize/?client_key=$clientKey&scope=user.info.basic&response_type=code&redirect_uri=$redirectUri&state=duze';
      if (!await launchUrl(Uri.parse(authUrl), mode: LaunchMode.externalApplication)) {
        _setError('Failed to open TikTok authorization.');
        return false;
      }

      final code = await _getOAuthVerifier(); // Reuse Twitter's verifier logic
      if (code == null) {
        _setError('Invalid TikTok authorization code.');
        return false;
      }

      final tokenResponse = await http.post(
        Uri.parse('https://open.tiktokapis.com/v2/oauth/token/'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_key': clientKey!,
          'client_secret': clientSecret!,
          'code': code,
          'grant_type': 'authorization_code',
          'redirect_uri': redirectUri,
        },
      );
      if (tokenResponse.statusCode != 200) {
        _setError('Failed to get TikTok token: ${tokenResponse.body}');
        return false;
      }
      final tokenData = jsonDecode(tokenResponse.body);
      final accessToken = tokenData['access_token'];

      final userResponse = await http.get(
        Uri.parse('https://open.tiktokapis.com/v2/user/info/?fields=open_id,username,follower_count,following_count'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (userResponse.statusCode != 200) {
        _setError('Failed to fetch TikTok profile: ${userResponse.body}');
        return false;
      }
      final userData = jsonDecode(userResponse.body)['data']['user'];
      final tiktokUsername = userData['username'];
      final tiktokFollowerCount = userData['follower_count'];
      final tiktokFollowingCount = userData['following_count'];

      await _firestore.collection('users').doc(currentUser.uid).update({
        'tiktokUsername': tiktokUsername,
        'tiktokFollowerCount': tiktokFollowerCount,
        'tiktokFollowingCount': tiktokFollowingCount,
        'socialAccounts.tiktok': {
          'platform': 'tiktok',
          'id': userData['open_id'],
          'accessToken': accessToken,
        },
      });

      await _loadUserData(currentUser.uid);
      return true;
    } catch (e, stackTrace) {
      _setError('TikTok connection failed: $e');
      print('Error: $e\n$stackTrace');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> disconnectSocialAccount(String platform) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      if (platform == 'facebook') {
        await FacebookAuth.instance.logOut();
      }

      await _firestore.collection('users').doc(currentUser.uid).update({
        'socialAccounts.$platform': FieldValue.delete(),
        '${platform}Username': null,
        if (platform == 'facebook') ...{
          'facebookFollowerCount': null,
          'facebookFriendCount': null,
          'facebookFriends': [],
        },
        if (platform == 'twitter') ...{
          'twitterFollowers': [],
          'twitterFollowing': [],
        },
        if (platform == 'tiktok') ...{
          'tiktokFollowerCount': null,
          'tiktokFollowingCount': null,
        },
      });

      await _loadUserData(currentUser.uid);
    } catch (e) {
      print('Error disconnecting $platform: $e');
    }
  }

  Future<Map<String, List<String>>> findMutualConnections(String otherUserId) async {
    try {
      final currentUser = _userModel;
      if (currentUser == null) return {};

      final otherUserDoc = await _firestore.collection('users').doc(otherUserId).get();
      if (!otherUserDoc.exists) return {};

      final otherUser = UserModel.fromMap(otherUserDoc.data()!);
      final mutualConnections = <String, List<String>>{};

      if (currentUser.facebookFriends.isNotEmpty && otherUser.facebookFriends.isNotEmpty) {
        final mutualFacebookFriends = currentUser.facebookFriends
            .toSet()
            .intersection(otherUser.facebookFriends.toSet())
            .toList();
        mutualConnections['facebookFriends'] = mutualFacebookFriends;
      }

      // Twitter connections commented out
      /*
      if (currentUser.twitterFollowers.isNotEmpty && otherUser.twitterFollowers.isNotEmpty) {
        mutualConnections['twitterFollowers'] = currentUser.twitterFollowers
            .toSet()
            .intersection(otherUser.twitterFollowers.toSet())
            .toList();
      }
      if (currentUser.twitterFollowing.isNotEmpty && otherUser.twitterFollowing.isNotEmpty) {
        mutualConnections['twitterFollowing'] = currentUser.twitterFollowing
            .toSet()
            .intersection(otherUser.twitterFollowing.toSet())
            .toList();
      }
      */

      return mutualConnections;
    } catch (e) {
      print('Error finding mutual connections: $e');
      return {};
    }
  }

 Future<String?> _getOAuthVerifier() async {
  final completer = Completer<String?>();

  // Listen to oauthVerifierController stream
  final subscription = oauthVerifierController.stream.listen((verifier) {
    print('Received verifier from stream: $verifier');
    if (verifier != null && verifier.isNotEmpty) {
      completer.complete(verifier);
    } else {
      completer.complete(null);
      print('Verifier is empty or null');
    }
  }, onError: (err) {
    print('Verifier stream error: $err');
    completer.completeError(err);
  });

  // Timeout after 2 minutes
  Future.delayed(Duration(minutes: 2), () {
    if (!completer.isCompleted) {
      completer.complete(null);
      subscription.cancel();
      print('OAuth verifier timeout');
    }
  });

  return await completer.future;
}

  Future<void> _fetchTwitterConnections(oauth1.Client client, String uid) async {
    try {
      // Fetch followers
      final followersResponse = await client.get(
        Uri.parse('https://api.twitter.com/2/users/me/followers?max_results=100'),
      );
      if (followersResponse.statusCode == 200) {
        final data = json.decode(followersResponse.body);
        final followers = (data['data'] as List?)?.map((user) => user['id'].toString()).toList() ?? [];
        await _updateSocialConnections('twitter', followers: followers);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('twitter_followers_$uid', followers);
        print('Fetched ${followers.length} Twitter followers');
      } else {
        print('Failed to fetch followers: ${followersResponse.statusCode}, body: ${followersResponse.body}');
      }

      // Fetch following
      final followingResponse = await client.get(
        Uri.parse('https://api.twitter.com/2/users/me/following?max_results=100'),
      );
      if (followingResponse.statusCode == 200) {
        final data = json.decode(followingResponse.body);
        final following = (data['data'] as List?)?.map((user) => user['id'].toString()).toList() ?? [];
        await _updateSocialConnections('twitter', following: following);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('twitter_following_$uid', following);
        print('Fetched ${following.length} Twitter following');
      } else {
        print('Failed to fetch following: ${followingResponse.statusCode}, body: ${followingResponse.body}');
      }
    } catch (e) {
      _setError('Failed to fetch Twitter connections: $e');
      print('Error: $e');
    }
  }


  Future<void> _updateSocialAccount(SocialAccount account) async {
    if (_currentUser == null) return;
    final updatedAccounts = Map<String, SocialAccount>.from(_currentUser!.socialAccounts)
      ..[account.platform] = account;
    await _firestore.collection('users').doc(_currentUser!.uid).update({
      'socialAccounts': updatedAccounts.map((key, value) => MapEntry(key, value.toMap())),
    });
    _currentUser = _currentUser!.copyWith(socialAccounts: updatedAccounts);
    notifyListeners();
  }

  Future<void> _updateSocialConnections(String platform, {List<String>? friends, List<String>? followers, List<String>? following}) async {
    if (_currentUser == null) return;
    final updates = <String, dynamic>{};
    if (friends != null) updates['${platform}Friends'] = friends;
    if (followers != null) updates['${platform}Followers'] = followers;
    if (following != null) updates['${platform}Following'] = following;
    await _firestore.collection('users').doc(_currentUser!.uid).update(updates);
    _currentUser = _currentUser!.copyWith(
      facebookFriends: platform == 'facebook' ? friends ?? [] : _currentUser!.facebookFriends,
      twitterFollowers: platform == 'twitter' ? followers ?? [] : _currentUser!.twitterFollowers,
      twitterFollowing: platform == 'twitter' ? following ?? [] : _currentUser!.twitterFollowing,
    );
    notifyListeners();
  }



 



  
Future<void> updateUserProfile(Map<String, dynamic> updates) async {
    if (_currentUser == null) {
      _setError('No user logged in');
      return;
    }
    try {
      _setLoading(true);
      await _firestore.collection('users').doc(_currentUser!.uid).update(updates);
      await _loadUserData(_currentUser!.uid);
      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Failed to update profile: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }


  Future<void> updateProfilePicture(String uid, XFile image) async {
    try {
    //  final cloudinary = CloudinaryPublic('duze', 'duze_preset', cache: true);
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(image.path, resourceType: CloudinaryResourceType.Image, folder: 'profiles'),
      );
      final photoURL = response.secureUrl;
      await updateUserProfile({'photoURL': photoURL});
    } catch (e) {
      _setError('Failed to update profile picture: $e');
    }
  }


 Future<String?> uploadProfileImage(File image) async {
    try {
     // final cloudinary = CloudinaryPublic('duze', 'duze_preset', cache: true);
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(image.path, resourceType: CloudinaryResourceType.Image, folder: 'profiles'),
      );
      final photoURL = response.secureUrl;
      return photoURL;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

 Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final user = _auth.currentUser;
      if (user != null && user.email != null) {
        // Re-authenticate
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        );
        await user.reauthenticateWithCredential(credential);
        // Update password
        await user.updatePassword(newPassword);
        _errorMessage = null;
      } else {
        throw Exception('No authenticated user found');
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }



  Future<void> updateUserLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied) {
          _setError('Location permission denied');
          return;
        }
      }
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final userLocation = UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        lastUpdated: DateTime.now(),
      );
      await updateUserProfile({'location': userLocation.toMap()});
    } catch (e) {
      _setError('Failed to update location: $e');
    }
  }




  Future<List<UserModel>> findNearbyUsers(double radiusInKm) async {
    if (_currentUser?.location == null) return [];
    final center = _currentUser!.location!;
    final radiusInMeters = radiusInKm * 1000;
    final usersSnapshot = await _firestore.collection('users').get();
    final nearbyUsers = <UserModel>[];

    for (var doc in usersSnapshot.docs) {
      final user = UserModel.fromMap(doc.data());
      if (user.uid == _currentUser!.uid || user.location == null || !user.shareLocation) continue;
      final distance = Geolocator.distanceBetween(
        center.latitude,
        center.longitude,
        user.location!.latitude,
        user.location!.longitude,
      );
      if (distance <= radiusInMeters && distance <= user.visibilityRadius * 1000) {
        nearbyUsers.add(user);
      }
    }
    return nearbyUsers;
  }

 

  Future<http.Response> _makeApiCallWithRetry(String url, {Map<String, String>? headers, int retries = 3}) async {
    for (int i = 0; i < retries; i++) {
      try {
        final response = await http.get(Uri.parse(url), headers: headers);
        if (response.statusCode == 429) {
          await Future.delayed(Duration(seconds: (1 << i)));
          continue;
        }
        return response;
      } catch (e) {
        if (i == retries - 1) rethrow;
      }
    }
    throw Exception('API rate limit exceeded');
  }


 Future<void> signOut() async {
    _setLoading(true);
    try {
      await _auth.signOut();
      _user = null;
      _userModel = null;
       isAuthenticated = false;

      _clearError();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }


  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _clearError();
  }


  Future<void> _fetchTwitterFollowers(String accessToken, String secret) async {
    try {
      await dotenv.load(fileName: ".env");
      final response = await _makeApiCallWithRetry(
        'https://api.twitter.com/2/users/me/followers?max_results=100',
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final friends = (data['data'] as List).map((user) => user['id'].toString()).toList();
        await _updateUserFriends(friends);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('twitter_friends_${_auth.currentUser!.uid}', friends);
      } else {
        _errorMessage = 'Failed to fetch Twitter followers: ${response.statusCode}';
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to fetch Twitter followers: ${_formatError(e)}';
      notifyListeners();
    }
  }

  // Update user location
  Future<void> _updateUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _errorMessage = 'Location services are disabled';
        notifyListeners();
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _errorMessage = 'Location permission denied';
          notifyListeners();
          return;
        }
      }
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final userLocation = UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        lastUpdated: DateTime.now(),
      );
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(location: userLocation);
        await _firestore.collection('users').doc(_currentUser!.uid).set(
              _currentUser!.toMap(),
              SetOptions(merge: true),
            );
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = _formatError(e);
      notifyListeners();
    }
  }



  // Update friends list
  Future<void> _updateUserFriends(List<String> friends) async {
    if (_currentUser != null) {
      final batch = _firestore.batch();
      final docRef = _firestore.collection('users').doc(_currentUser!.uid);
      batch.set(docRef, {'friends': friends}, SetOptions(merge: true));
      await batch.commit();
      _currentUser = _currentUser!.copyWith(friends: friends);
      notifyListeners();
    }
  }

 
  String _formatError(dynamic error) {
    return error.toString().replaceAll('Exception: ', '');
  }
 

 
}

