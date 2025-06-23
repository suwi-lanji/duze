import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:duze/core/models/checkin_model.dart';
import 'package:duze/core/models/post_model.dart';
import 'package:duze/features/chat/providers/chat_provider.dart';
import 'package:duze/features/location/providers/location_provider.dart';
import 'package:duze/shared/widgets/custom_button.dart';
import 'package:duze/shared/widgets/custom_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:provider/provider.dart';
import '../../../core/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/app_colors.dart';
import '../../../config/routes.dart';

class ViewUserProfileScreen extends StatefulWidget {
  const ViewUserProfileScreen({super.key});

  @override
  State<ViewUserProfileScreen> createState() => _ViewUserProfileScreenState();
}

class _ViewUserProfileScreenState extends State<ViewUserProfileScreen> {
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  NativeAd? _nativeAd;
  bool _isNativeAdLoaded = false;
  bool _isPremiumUser = false; // TODO: Implement actual premium check
  bool _isFriend = false;
  bool _isPendingSent = false; // Current user sent a pending request
  bool _isPendingReceived = false; // Current user received a pending request
  String? _pendingRequestId; // ID of the pending request (sent or received)
  bool _isAdLoaded = false;
  UserModel? _user;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    _loadInterstitialAd();
    _loadNativeAd();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arguments = ModalRoute.of(context)?.settings.arguments;
    print('ViewUserProfileScreen received arguments: $arguments, Type: ${arguments.runtimeType}');

    if (arguments is UserModel && arguments.uid.isNotEmpty) {
      _user = arguments;
      print('UserModel received: UID=${_user!.uid}, Name=${_user!.displayName}');
      if (_isLoading) {
        _checkFriendAndRequestStatus();
      }
    } else {
      setState(() {
        _errorMessage = 'No valid user data provided';
        _isLoading = false;
      });
    }
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // Test ID
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          print('Banner ad loaded');
          setState(() => _isAdLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          print('Banner ad failed to load: $error');
          ad.dispose();
        },
      ),
    )..load();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712', // Test ID
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          print('Interstitial ad loaded');
          setState(() => _interstitialAd = ad);
        },
        onAdFailedToLoad: (error) {
          print('Interstitial ad failed to load: $error');
          setState(() => _interstitialAd = null);
        },
      ),
    );
  }

  void _loadNativeAd() {
    _nativeAd = NativeAd(
      adUnitId: 'ca-app-pub-3940256099942544/2247696110', // Test ID
      factoryId: 'example',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          print('Native ad loaded');
          setState(() {
            _isNativeAdLoaded = true;
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          print('Native ad failed to load: $error');
          ad.dispose();
          setState(() {
            _isNativeAdLoaded = false;
            _isAdLoaded = false;
            _nativeAd = null;
          });
        },
      ),
    )..load();
  }

  Future<void> _checkFriendAndRequestStatus() async {
    if (_user == null) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.currentUser == null) {
        setState(() {
          _errorMessage = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      final currentUserId = authProvider.currentUser!.uid;
      final userId = _user!.uid;

      // Check friend status
      final relationshipsDoc = await FirebaseFirestore.instance
          .collection('relationships')
          .doc(currentUserId)
          .get();
      final friends = (relationshipsDoc.data()?['friends'] as List<dynamic>?)?.cast<String>() ?? [];
      final isFriend = friends.contains(userId);

      // Check pending requests (sent by current user)
      final sentRequestQuery = await FirebaseFirestore.instance
          .collection('friendRequests')
          .where('senderId', isEqualTo: currentUserId)
          .where('recipientId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();
      final isPendingSent = sentRequestQuery.docs.isNotEmpty;
      final pendingSentRequestId = sentRequestQuery.docs.isNotEmpty ? sentRequestQuery.docs.first.id : null;

      // Check pending requests (received from viewed user)
      final receivedRequestQuery = await FirebaseFirestore.instance
          .collection('friendRequests')
          .where('senderId', isEqualTo: userId)
          .where('recipientId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'pending')
          .get();
      final isPendingReceived = receivedRequestQuery.docs.isNotEmpty;
      final pendingReceivedRequestId = receivedRequestQuery.docs.isNotEmpty ? receivedRequestQuery.docs.first.id : null;

      setState(() {
        _isFriend = isFriend;
        _isPendingSent = isPendingSent;
        _isPendingReceived = isPendingReceived;
        _pendingRequestId = pendingSentRequestId ?? pendingReceivedRequestId;
        _isLoading = false;
      });
      print('Friend status for $userId: $_isFriend');
      print('Pending sent: $_isPendingSent, Pending received: $_isPendingReceived, Request ID: $_pendingRequestId');
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to check status: $e';
        _isLoading = false;
      });
      print('Error checking status: $e');
    }
  }

  Future<void> _handleConnectRequest(String userId, AuthProvider authProvider, ChatProvider chatProvider) async {
    if (_interstitialAd != null && !_isPremiumUser) {
      await _interstitialAd!.show();
      _interstitialAd = null;
      _loadInterstitialAd();
    }
    if (authProvider.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to perform this action')),
      );
      return;
    }
    try {
      await chatProvider.sendConnectRequest(
        context: context,
        senderId: authProvider.currentUser!.uid,
        recipientId: userId,
      );
      setState(() {
        _isPendingSent = true;
        _pendingRequestId = 'new_request'; // Placeholder; actual ID set in ChatProvider
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect request sent')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send connect request: $e')),
      );
    }
  }

  Future<void> _handleAcceptRequest(String requestId, String userId, AuthProvider authProvider, ChatProvider chatProvider) async {
    try {
      await chatProvider.acceptConnectRequestNew(
        context: context,
        requestId: requestId,
        senderId: userId,
        recipientId: authProvider.currentUser!.uid,
      );
      setState(() {
        _isFriend = true;
        _isPendingReceived = false;
        _pendingRequestId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect request accepted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept request: $e')),
      );
    }
  }

  Future<void> _handleDenyRequest(String requestId, AuthProvider authProvider) async {
    try {
      await FirebaseFirestore.instance.collection('friendRequests').doc(requestId).delete();
      setState(() {
        _isPendingReceived = false;
        _pendingRequestId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect request denied')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to deny request: $e')),
      );
    }
  }

  Future<void> _handleTextButton(BuildContext context, UserModel user, AuthProvider authProvider, ChatProvider chatProvider) async {
    if (authProvider.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to send messages')),
      );
      return;
    }

    if (_isFriend) {
      final chat = await chatProvider.getExistingChat(
        authProvider.currentUser!.uid,
        user.uid,
      );
      if (chat != null) {
        Navigator.pushNamed(context, AppRoutes.chatDetail, arguments: chat);
      } else {
        // Create a new chat
        await chatProvider.sendConnectRequest(
          context: context,
          senderId: authProvider.currentUser!.uid,
          recipientId: user.uid,
          message: 'Hello! Let’s chat.', // Default message for friends
        );
        final newChat = await chatProvider.getExistingChat(
          authProvider.currentUser!.uid,
          user.uid,
        );
        if (newChat != null) {
          Navigator.pushNamed(context, AppRoutes.chatDetail, arguments: newChat);
        }
      }
    } else {
      final sendMessage = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Send Connect Request'),
          content: const Text('You are not friends with this user. Would you like to send a connect request with a message?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No, just connect'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes, include message'),
            ),
          ],
        ),
      );

      if (sendMessage == true) {
        Navigator.pushNamed(context, AppRoutes.messageRequest, arguments: user);
      } else if (sendMessage == false) {
        await chatProvider.sendConnectRequest(
          context: context,
          senderId: authProvider.currentUser!.uid,
          recipientId: user.uid,
        );
        setState(() {
          _isPendingSent = true;
          _pendingRequestId = 'new_request'; // Placeholder
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connect request sent')),
        );
      }
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryTeal)),
      );
    }
    if (_errorMessage != null || _user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage ?? 'No user data provided'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final locationProvider = Provider.of<LocationProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);

    final distance = _user!.location != null && locationProvider.currentPosition != null
        ? latlong.Distance().as(
            latlong.LengthUnit.Kilometer,
            latlong.LatLng(
                locationProvider.currentPosition!.latitude,
                locationProvider.currentPosition!.longitude),
            latlong.LatLng(_user!.location!.latitude, _user!.location!.longitude),
          )
        : null;

    final isOwnProfile = authProvider.currentUser?.uid == _user!.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(_user!.displayName, style: const TextStyle(fontFamily: 'Poppins')),
        backgroundColor: AppColors.white.withOpacity(0.95),
        actions: [
          if (!isOwnProfile)
            IconButton(
              icon: const Icon(Icons.chat, color: AppColors.primaryTeal),
              onPressed: () => _handleTextButton(context, _user!, authProvider, chatProvider),
            ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(gradient: AppColors.profileGradient),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileHeader(_user!, distance),
                  const SizedBox(height: 24),
                  _buildDetailsSection(_user!),
                  const SizedBox(height: 24),
                  _buildTimelineSection(_user!, isOwnProfile),
                  if (!isOwnProfile) ...[
                    const SizedBox(height: 16),
                    _buildConnectFollowButtons(_user!, authProvider, chatProvider),
                  ],
                  if (_bannerAd != null) const SizedBox(height: 60),
                ],
              ),
            ),
          ),
          if (_bannerAd != null && !_isPremiumUser)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.glassBackground.withOpacity(0.5),
                  border: Border.all(color: AppColors.glassBorder),
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(8),
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(UserModel user, double? distance) {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundImage:
                user.photoURL.isNotEmpty ? CachedNetworkImageProvider(user.photoURL) : null,
            child: user.photoURL.isEmpty
                ? const Icon(Icons.person, size: 60, color: AppColors.grey600)
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            user.displayName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.textDark),
          ),
          if (distance != null)
            Text(
              distance < 1
                  ? '~${(distance * 1000).toStringAsFixed(0)}m away'
                  : '~${distance.toStringAsFixed(1)}km away',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: AppColors.textDark),
            ),
          if (user.mood != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Chip(
                label: Text(
                  user.mood == 'open'
                      ? 'Open to Connect'
                      : user.mood == 'chilled'
                          ? 'Chilled'
                          : 'Do Not Disturb',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12),
                ),
                backgroundColor: user.mood == 'open'
                    ? AppColors.primaryTeal.withOpacity(0.2)
                    : user.mood == 'chilled'
                        ? AppColors.accentYellow.withOpacity(0.2)
                        : AppColors.accentRed.withOpacity(0.2),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              if (user.facebookUsername != null)
                Chip(
                  label: Text('@${user.facebookUsername}',
                      style: const TextStyle(color: AppColors.facebookBlue)),
                  avatar: const Icon(Icons.facebook, size: 16, color: AppColors.facebookBlue),
                ),
              if (user.twitterUsername != null)
                Chip(
                  label: Text('@${user.twitterUsername}',
                      style: const TextStyle(color: AppColors.twitterBlue)),
                  avatar: const Icon(Icons.alternate_email, size: 16, color: AppColors.twitterBlue),
                ),
              if (user.tiktokUsername != null)
                Chip(
                  label: Text('@${user.tiktokUsername}',
                      style: const TextStyle(color: AppColors.tiktokBlack)),
                  avatar: const Icon(Icons.music_note, size: 16, color: AppColors.tiktokBlack),
                ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _buildDetailsSection(UserModel user) {
    return CustomCard(
      glassEffect: true,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Details',
              style:
                  Theme.of(context).textTheme.titleMedium!.copyWith(color: AppColors.mainFontColor)),
          const SizedBox(height: 8),
          _buildDetailRow('Joined', user.createdAt.toLocal().toString().split(' ')[0]),
          _buildDetailRow(
              'Social Accounts',
              user.socialAccounts.isNotEmpty
                  ? user.socialAccounts.keys.map((k) => k.capitalize()).join(', ')
                  : 'None'),
          _buildDetailRow('Location Sharing', user.shareLocation ? 'Enabled' : 'Disabled'),
          _buildDetailRow('Visibility Radius', '${user.visibilityRadius.toStringAsFixed(1)} km'),
          if (user.facebookFriends.isNotEmpty)
            _buildDetailRow('Mutual FB Friends', user.facebookFriends.length.toString()),
        ],
      ),
    ).animate().slideY(begin: 0.2, end: 0, duration: 500.ms);
  }

  Widget _buildTimelineSection(UserModel user, bool isOwnProfile) {
    return CustomCard(
      glassEffect: true,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Activity Timeline',
              style:
                  Theme.of(context).textTheme.titleMedium!.copyWith(color: AppColors.mainFontColor)),
          const SizedBox(height: 8),
          if (!isOwnProfile &&
              (user.activitySharingEnabled != true ||
                  (user.profileScope == 'friends' && !_isFriend)))
            const Text(
              'Activity is private',
              style: TextStyle(color: AppColors.grey600),
            )
          else
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _fetchTimelineStream(user.uid),
              builder: (context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: AppColors.primaryTeal));
                }
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}',
                      style: const TextStyle(color: AppColors.accentRed));
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const Text('No activity yet',
                      style: TextStyle(color: AppColors.grey600));
                }
                final widgets = <Widget>[];
                for (var i = 0; i < items.length; i++) {
                  final item = items[i];
                  widgets.add(
                    item['type'] == 'checkin'
                        ? _buildCheckinItem(CheckinModel.fromMap(item['data']))
                        : _buildPostItem(PostModel.fromMap(item['data'])),
                  );
                  if ((i + 1) % 5 == 0 &&
                      _isNativeAdLoaded &&
                      _nativeAd != null &&
                      !_isPremiumUser) {
                    widgets.add(
                      Container(
                        height: 200,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: AdWidget(ad: _nativeAd!),
                      ),
                    );
                  }
                }
                return Column(children: widgets);
              },
            ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 200.ms);
  }

  Stream<List<Map<String, dynamic>>> _fetchTimelineStream(String userId) {
    return FirebaseFirestore.instance
        .collection('checkins')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots()
        .asyncMap((checkins) async {
      final posts = await FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();
      final List<Map<String, dynamic>> items = [];
      for (var doc in checkins.docs) {
        items.add({'type': 'checkin', 'data': doc.data(), 'id': doc.id});
      }
      for (var doc in posts.docs) {
        items.add({'type': 'post', 'data': doc.data(), 'id': doc.id});
      }
      items.sort((a, b) =>
          (b['data']['timestamp'] as Timestamp).compareTo(a['data']['timestamp'] as Timestamp));
      return items.take(10).toList();
    });
  }

  Widget _buildCheckinItem(CheckinModel checkin) {
    return ListTile(
      leading: const Icon(Icons.location_on, color: AppColors.primaryTeal),
      title: Text(
        checkin.venueName ?? 'Check-in',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      subtitle: Text(
        '${checkin.timestamp.toDate().toLocal().toString().split('.')[0]} • ${checkin.location.latitude.toStringAsFixed(2)}, ${checkin.location.longitude.toStringAsFixed(2)}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.grey600),
      ),
      trailing: checkin.photoURL != null && checkin.photoURL!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: checkin.photoURL!,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) =>
                    const Icon(Icons.error, color: AppColors.accentRed),
              ),
            )
          : null,
    );
  }

  Widget _buildPostItem(PostModel post) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post.postType == 'arTag' ? 'AR Tag: ${post.content}' : post.content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textDark),
          ),
          if (post.mediaUrl != null && post.mediaUrl!.isNotEmpty && post.postType != 'arTag')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: post.mediaUrl!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.error, color: AppColors.accentRed),
                ),
              ),
            ),
          if (post.arModelUrl != null && post.postType == 'arTag')
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Icon(Icons.camera_alt, color: AppColors.primaryTeal, size: 24),
            ),
          Text(
            post.timestamp.toLocal().toString().split('.')[0],
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.grey600),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectFollowButtons(
      UserModel user, AuthProvider authProvider, ChatProvider chatProvider) {
    if (_isFriend) {
      return Center(
        child: CustomButton(
          text: 'Message',
          gradient: AppColors.buttonGradient,
          onPressed: () => _handleTextButton(context, user, authProvider, chatProvider),
        ),
      );
    } else if (_isPendingSent) {
      return const Center(
        child: Text(
          'Connect request pending approval',
          style: TextStyle(
            color: AppColors.grey600,
            fontStyle: FontStyle.italic,
            fontFamily: 'Poppins',
          ),
        ),
      );
    } else if (_isPendingReceived && _pendingRequestId != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomButton(
            text: 'Accept',
            gradient: AppColors.buttonGradient,
            onPressed: () =>
                _handleAcceptRequest(_pendingRequestId!, user.uid, authProvider, chatProvider),
          ),
          const SizedBox(width: 16),
          CustomButton(
            text: 'Deny',
            gradient: AppColors.buttonGradient,
            onPressed: () => _handleDenyRequest(_pendingRequestId!, authProvider),
          ),
        ],
      );
    } else {
      return Center(
        child: CustomButton(
          text: 'Connect',
          gradient: AppColors.buttonGradient,
          onPressed: () => _handleConnectRequest(user.uid, authProvider, chatProvider),
        ),
      );
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.grey600),
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() => "${this[0].toUpperCase()}${substring(1)}";
}