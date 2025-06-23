import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:duze/core/models/checkin_model.dart';
import 'package:duze/core/models/post_model.dart';
import 'package:duze/features/chat/providers/chat_provider.dart';
import 'package:duze/features/post/providers/post_provider.dart';
import 'package:duze/shared/widgets/app_colors.dart';
import 'package:duze/shared/widgets/custom_app_bar.dart';
import 'package:duze/shared/widgets/custom_button.dart';
import 'package:duze/shared/widgets/custom_card.dart';
import 'package:duze/shared/widgets/user_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../config/routes.dart';
import '../../../core/models/user_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLocationSharingEnabled = true;
  bool _isConnectionsSharingEnabled = true;
  String _mood = 'open';
  bool _isGhostMode = false;
  bool _notificationsEnabled = true;
  String _profileScope = 'everyone';
  bool _activitySharingEnabled = true;
  InterstitialAd? _interstitialAd;
  int _buttonPressCount = 0;
  NativeAd? _nativeAd;
  bool _isNativeAdLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      setState(() {
        _isLocationSharingEnabled = authProvider.currentUser?.shareLocation ?? true;
        _isConnectionsSharingEnabled = authProvider.currentUser?.shareConnections ?? true;
        _mood = authProvider.currentUser?.mood ?? 'open';
        _isGhostMode = authProvider.currentUser?.visibility == 'ghost';
        _notificationsEnabled = authProvider.currentUser?.notificationsEnabled ?? true;
        _profileScope = authProvider.currentUser?.profileScope ?? 'everyone';
        _activitySharingEnabled = authProvider.currentUser?.activitySharingEnabled ?? true;
      });
      _loadInterstitialAd();
      _loadNativeAd();
    });
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => setState(() => _interstitialAd = ad),
        onAdFailedToLoad: (error) {
          print('Interstitial ad failed to load: $error');
          _interstitialAd = null;
        },
      ),
    );
  }

  void _loadNativeAd() {
    _nativeAd = NativeAd(
      adUnitId: 'ca-app-pub-3940256099942544/2247696110',
      factoryId: 'adFactoryExample',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) => setState(() => _isNativeAdLoaded = true),
        onAdFailedToLoad: (ad, error) {
          print('Native ad failed to load: $error');
          ad.dispose();
          setState(() => _isNativeAdLoaded = false);
        },
      ),
    )..load();
  }

  Future<void> _updateProfileWithAd(Map<String, dynamic> updates, AuthProvider authProvider) async {
    setState(() => _buttonPressCount++);
    if (_buttonPressCount % 3 == 0 && _interstitialAd != null) {
      await _interstitialAd!.show();
      _interstitialAd = null;
      _loadInterstitialAd();
    }
    try {
      await authProvider.updateUserProfile(updates);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    }
  }

  void _toggleLocationSharing(AuthProvider authProvider) async {
    setState(() => _isLocationSharingEnabled = !_isLocationSharingEnabled);
    await _updateProfileWithAd({'shareLocation': _isLocationSharingEnabled}, authProvider);
  }

  void _toggleConnectionsSharing(AuthProvider authProvider) async {
    setState(() => _isConnectionsSharingEnabled = !_isConnectionsSharingEnabled);
    await _updateProfileWithAd({'shareConnections': _isConnectionsSharingEnabled}, authProvider);
  }

  void _setMood(String mood, AuthProvider authProvider) async {
    setState(() => _mood = mood);
    await _updateProfileWithAd({
      'mood': mood,
      'moodExpires': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
    }, authProvider);
  }

  void _toggleGhostMode(AuthProvider authProvider) async {
    setState(() => _isGhostMode = !_isGhostMode);
    await _updateProfileWithAd({
      'visibility': _isGhostMode ? 'ghost' : 'visible',
      'visibilityExpires': _isGhostMode ? Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))) : null,
    }, authProvider);
  }

  void _toggleNotifications(AuthProvider authProvider) async {
    setState(() => _notificationsEnabled = !_notificationsEnabled);
    await _updateProfileWithAd({'notificationsEnabled': _notificationsEnabled}, authProvider);
  }

  void _setProfileScope(String scope, AuthProvider authProvider) async {
    setState(() => _profileScope = scope);
    await _updateProfileWithAd({'profileScope': scope}, authProvider);
  }

  void _toggleActivitySharing(AuthProvider authProvider) async {
    setState(() => _activitySharingEnabled = !_activitySharingEnabled);
    await _updateProfileWithAd({'activitySharingEnabled': _activitySharingEnabled}, authProvider);
  }

  Future<void> _signOut(AuthProvider authProvider) async {
    setState(() => _buttonPressCount++);
    if (_buttonPressCount % 3 == 0 && _interstitialAd != null) {
      await _interstitialAd!.show();
      _interstitialAd = null;
      _loadInterstitialAd();
    }
    try {
      await authProvider.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to sign out: $e')));
      }
    }
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: const CustomAppBar(),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.profileGradient),
        child: SafeArea(
          child: user == null
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryTeal))
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileHeader(user).animate().fadeIn(duration: 500.ms),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Account Details'),
                        const SizedBox(height: 8),
                        _buildAccountDetails(user).animate().slideY(begin: 0.2, end: 0, duration: 500.ms),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Controls'),
                        const SizedBox(height: 8),
                        _buildControlsSection(authProvider).animate().fadeIn(duration: 500.ms, delay: 200.ms),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Activity Timeline'),
                        const SizedBox(height: 8),
                        _buildTimelineSection(user).animate().fadeIn(duration: 500.ms, delay: 300.ms),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Social Connections'),
                        const SizedBox(height: 8),
                        _buildSocialConnectionsSection(context, authProvider)
                            .animate()
                            .fadeIn(duration: 500.ms, delay: 400.ms),
                        const SizedBox(height: 24),
                        _buildConnectionRequestsSectionTitle(context, authProvider),
                        const SizedBox(height: 8),
                        _buildConnectionRequestsSection(context, authProvider)
                            .animate()
                            .fadeIn(duration: 500.ms, delay: 500.ms),
                        if (authProvider.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              authProvider.errorMessage!,
                              style: const TextStyle(
                                color: AppColors.accentRed,
                                fontFamily: 'Poppins',
                                fontSize: 14,
                              ),
                            ),
                          ).animate().fadeIn(duration: 300.ms),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(UserModel user) {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 64,
            backgroundColor: AppColors.grey600.withOpacity(0.2),
            backgroundImage: user.photoURL.isNotEmpty ? CachedNetworkImageProvider(user.photoURL) : null,
            child: user.photoURL.isEmpty
                ? const Icon(Icons.person, size: 64, color: AppColors.grey600)
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            user.displayName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.buttoncolor,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            user.email.isNotEmpty ? user.email : 'No email provided',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.black,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.buttoncolor,
            fontWeight: FontWeight.w600,
          ),
    );
  }

  Widget _buildConnectionRequestsSectionTitle(BuildContext context, AuthProvider authProvider) {
    final currentUserId = authProvider.currentUser?.uid;
    if (currentUserId == null) {
      return _buildSectionTitle('Connection Requests');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('friendRequests')
          .where('recipientId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return Row(
          children: [
            _buildSectionTitle('Connection Requests'),
            if (count > 0)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Badge(
                  backgroundColor: AppColors.accentRed,
                  textColor: AppColors.textPrimary,
                  label: Text(
                    count.toString(),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAccountDetails(UserModel user) {
    return CustomCard(
      glassEffect: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Joined', user.createdAt.toLocal().toString().split(' ')[0]),
          _buildDetailRow('Friends', user.friends.length.toString()),
          _buildDetailRow('Visibility Radius', '${user.visibilityRadius.toStringAsFixed(1)} km'),
          const SizedBox(height: 16),
          CustomButton(
            text: 'Edit Profile',
            gradient: AppColors.buttonGradient,
            onPressed: () => Navigator.pushNamed(context, AppRoutes.editProfile),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsSection(AuthProvider authProvider) {
    return CustomCard(
      glassEffect: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Mood',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.buttoncolor,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            trailing: DropdownButton<String>(
              value: _mood,
              dropdownColor: AppColors.white,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'open', child: Text('Open to Connect')),
                DropdownMenuItem(value: 'chilled', child: Text('Chilled')),
                DropdownMenuItem(value: 'dnd', child: Text('Do Not Disturb')),
              ],
              onChanged: (value) {
                if (value != null) _setMood(value, authProvider);
              },
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.black),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Go Ghost (24h)',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.buttoncolor,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            subtitle: Text(
              'Hide your profile temporarily',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.black),
            ),
            value: _isGhostMode,
            onChanged: (value) => _toggleGhostMode(authProvider),
            activeColor: AppColors.primaryTeal,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Share Location',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.buttoncolor,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            subtitle: Text(
              'Allow others to see your location',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.black),
            ),
            value: _isLocationSharingEnabled,
            onChanged: (value) => _toggleLocationSharing(authProvider),
            activeColor: AppColors.primaryTeal,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Share Social Connections',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.buttoncolor,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            subtitle: Text(
              'Show your social media connections',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.black),
            ),
            value: _isConnectionsSharingEnabled,
            onChanged: (value) => _toggleConnectionsSharing(authProvider),
            activeColor: AppColors.primaryTeal,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Push Notifications',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.buttoncolor,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            subtitle: Text(
              'Receive app notifications',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.black),
            ),
            value: _notificationsEnabled,
            onChanged: (value) => _toggleNotifications(authProvider),
            activeColor: AppColors.primaryTeal,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Profile Visibility',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.buttoncolor,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            trailing: DropdownButton<String>(
              value: _profileScope,
              dropdownColor: AppColors.white,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'everyone', child: Text('Everyone')),
                DropdownMenuItem(value: 'friends', child: Text('Friends Only')),
              ],
              onChanged: (value) {
                if (value != null) _setProfileScope(value, authProvider);
              },
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.black),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Share Activity',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.buttoncolor,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            subtitle: Text(
              'Share your recent activity',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.black),
            ),
            value: _activitySharingEnabled,
            onChanged: (value) => _toggleActivitySharing(authProvider),
            activeColor: AppColors.primaryTeal,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Change Password',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.buttoncolor,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.grey600),
            onTap: () => Navigator.pushNamed(context, AppRoutes.changePassword),
          ),
          const SizedBox(height: 16),
          CustomButton(
            text: 'Log Out',
            color: AppColors.accentRed,
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirm Logout'),
                  content: const Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Log Out', style: TextStyle(color: AppColors.accentRed)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await _signOut(authProvider);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection(UserModel user) {
    return CustomCard(
      glassEffect: true,
      padding: const EdgeInsets.all(16),
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _fetchTimelineStream(user.uid),
        builder: (context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryTeal));
          }
          if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.accentRed));
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Text('No activity yet', style: TextStyle(color: AppColors.grey600));
          }
          final widgets = <Widget>[];
          for (var i = 0; i < items.length; i++) {
            final item = items[i];
            widgets.add(
              item['type'] == 'checkin'
                  ? _buildCheckinItem(CheckinModel.fromMap(item['data']))
                  : _buildPostItem(PostModel.fromMap(item['data'])),
            );
            if ((i + 1) % 5 == 0 && _isNativeAdLoaded && _nativeAd != null) {
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
    );
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
      items.sort((a, b) => (b['data']['timestamp'] as Timestamp).compareTo(a['data']['timestamp'] as Timestamp));
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
                errorWidget: (context, url, error) => const Icon(Icons.error, color: AppColors.accentRed),
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
                  errorWidget: (context, url, error) => const Icon(Icons.error, color: AppColors.accentRed),
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

  Widget _buildSocialConnectionsSection(BuildContext context, AuthProvider authProvider) {
    final user = authProvider.currentUser!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connect your social media accounts to find friends nearby.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.black,
                fontWeight: FontWeight.w400,
              ),
        ),
        const SizedBox(height: 16),
        _buildSocialConnectionCard(
          context,
          authProvider,
          platform: 'facebook',
          name: user.facebookUsername ?? 'Not connected',
          friendCount: user.facebookFriendCount ?? 0,
          followerCount: user.facebookFollowerCount,
          icon: Icons.facebook,
          color: AppColors.facebookBlue,
          isConnected: user.socialAccounts.containsKey('facebook'),
        ),
        const SizedBox(height: 12),
        _buildSocialConnectionCard(
          context,
          authProvider,
          platform: 'twitter',
          name: user.twitterUsername != null ? '@${user.twitterUsername}' : 'Not connected',
          friendCount: 0,
          followerCount: null,
          icon: Icons.alternate_email,
          color: AppColors.twitterBlue,
          isConnected: user.socialAccounts.containsKey('twitter'),
        ),
        const SizedBox(height: 12),
        _buildSocialConnectionCard(
          context,
          authProvider,
          platform: 'tiktok',
          name: user.tiktokUsername != null ? '@${user.tiktokUsername}' : 'Not connected',
          friendCount: user.tiktokFollowingCount ?? 0,
          followerCount: user.tiktokFollowerCount,
          icon: Icons.music_note,
          color: AppColors.tiktokBlack,
          isConnected: user.socialAccounts.containsKey('tiktok'),
        ),
      ],
    );
  }

  Widget _buildConnectionRequestsSection(BuildContext context, AuthProvider authProvider) {
    final currentUserId = authProvider.currentUser?.uid;
    if (currentUserId == null) {
      return const Text(
        'Please log in to view connection requests',
        style: TextStyle(color: AppColors.grey600),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('friendRequests')
          .where('recipientId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryTeal));
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.accentRed));
        }
        final requests = snapshot.data?.docs ?? [];
        if (requests.isEmpty) {
          return const Text(
            'No pending connection requests',
            style: TextStyle(color: AppColors.grey600, fontFamily: 'Poppins'),
          );
        }

        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.5 + 16,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final senderId = request['senderId'] as String;
              final requestId = request.id;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(senderId).get(),
                builder: (context, AsyncSnapshot<DocumentSnapshot> userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      width: 200,
                      child: Center(child: CircularProgressIndicator(color: AppColors.primaryTeal)),
                    );
                  }
                  if (userSnapshot.hasError || !userSnapshot.hasData || !userSnapshot.data!.exists) {
                    return const SizedBox.shrink();
                  }

                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  final user = UserModel.fromMap({...userData, 'uid': senderId});
                  final chatProvider = Provider.of<ChatProvider>(context, listen: false);

                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: UserCard(
                      user: user,
                      showDistance: false,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.userProfile, arguments: user),
                      onAccept: () async {
                        await chatProvider.acceptConnectRequestNew(
                          context: context,
                          requestId: requestId,
                          senderId: senderId,
                          recipientId: currentUserId,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Connection request accepted')),
                        );
                      },
                      onDeny: () async {
                        await chatProvider.denyConnectRequest(
                          connectRequestId: requestId,
                          messageRequestId: request['messageRequestId'] as String?,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Connection request denied')),
                        );
                      },
                      isPendingReceived: true,
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSocialConnectionCard(
    BuildContext context,
    AuthProvider authProvider, {
    required String platform,
    required String name,
    required int friendCount,
    int? followerCount,
    required IconData icon,
    required Color color,
    required bool isConnected,
  }) {
    return CustomCard(
      glassEffect: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Text(
                platform.capitalize(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.buttoncolor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Name: $name',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.black,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            platform == 'tiktok' ? 'Following: $friendCount' : 'Friends: $friendCount',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.black,
                ),
          ),
          if (followerCount != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Followers: $followerCount',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.black,
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: isConnected ? 'Connected' : 'Connect with ${platform.capitalize()}',
                  isLoading: authProvider.isLoading && !isConnected,
                  icon: Icon(icon, color: AppColors.white, size: 20),
                  color: color,
                  onPressed: isConnected
                      ? null
                      : () async {
                          bool success;
                          switch (platform) {
                            case 'facebook':
                              success = await authProvider.signInWithFacebook();
                              break;
                            case 'twitter':
                              success = await authProvider.signInWithTwitter();
                              break;
                            case 'tiktok':
                              success = await authProvider.signInWithTikTok();
                              break;
                            default:
                              success = false;
                          }
                          if (success && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${platform.capitalize()} connected')),
                            );
                            await _updateProfileWithAd({}, authProvider);
                          } else if (authProvider.errorMessage != null && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(authProvider.errorMessage!)),
                            );
                          }
                        },
                ),
              ),
              if (isConnected)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: IconButton(
                    icon: const Icon(Icons.cancel, color: AppColors.accentRed, size: 24),
                    onPressed: () async {
                      await authProvider.disconnectSocialAccount(platform);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${platform.capitalize()} disconnected')),
                        );
                      }
                      await _updateProfileWithAd({}, authProvider);
                    },
                    tooltip: 'Disconnect ${platform.capitalize()}',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.buttoncolor,
                  fontWeight: FontWeight.w500,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.black,
                ),
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() => "${this[0].toUpperCase()}${substring(1)}";
}