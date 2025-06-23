import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';

import '../../../core/models/post_model.dart';
import '../../../core/models/user_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/chat/providers/chat_provider.dart';
import '../../../features/chat/screens/chat_list_screen.dart';
import '../../../features/discovery/screens/discovery_screen.dart';
import '../../../features/discovery/screens/events_screen.dart';
import '../../../features/location/providers/location_provider.dart';
import '../../../features/post/providers/post_provider.dart';
import '../../../features/profile/screens/profile_screen.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/app_colors.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../config/routes.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeTab(),
    const DiscoveryScreen(),
    const ChatListScreen(),
    const EventsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final postProvider = Provider.of<PostProvider>(context, listen: false);

    try {
      if (!authProvider.isAuthenticated || authProvider.currentUser == null) {
        print('User not authenticated, redirecting to login');
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.login);
        }
        return;
      }

      print('Initializing location');
      await locationProvider.initializeLocation();

      if (locationProvider.currentPosition == null) {
        print('No location available');
        postProvider.setError('Location unavailable. Please enable location services.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable location services')),
        );
        return;
      }

      print('Current location: (${locationProvider.currentPosition!.latitude}, ${locationProvider.currentPosition!.longitude})');
      print('Updating user location for UID: ${authProvider.currentUser!.uid}');
      await locationProvider.updateUserLocation(authProvider.currentUser!.uid);

      print('Fetching nearby posts');
      await Future.wait([
        postProvider.fetchNearbyPosts(
          locationProvider.currentPosition!.latitude,
          locationProvider.currentPosition!.longitude,
          currentUserId: authProvider.currentUser!.uid,
          limit: 10,
        ),
        chatProvider.fetchChats(authProvider.currentUser!.uid),
      ]);
    } catch (e, stackTrace) {
      print('Initialization error: $e\n$stackTrace');
      postProvider.setError('Failed to initialize: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Initialization failed: $e')),
      );
    }
  }

  @override
  void dispose() {
    print('Disposing HomeScreen');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: AppColors.primaryTeal,
        unselectedItemColor: AppColors.grey600,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Discover'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chats'),
          BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Events'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  bool _isTimeMachineMode = false;
  DateTime? _selectedDate;
  final ScrollController _scrollController = ScrollController();
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  final Map<String, VideoPlayerController> _videoControllers = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadNativeAd();
  }

  void _loadNativeAd() {
    _nativeAd = NativeAd(
      adUnitId: 'ca-app-pub-3940256099942544/2247696110', // Test ID
      factoryId: 'example',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) => setState(() => _isAdLoaded = true),
        onAdFailedToLoad: (ad, error) {
          print('Native ad failed: $error');
          ad.dispose();
          setState(() {
            _isAdLoaded = false;
            _nativeAd = null;
          });
        },
      ),
    );
    _nativeAd!.load();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !Provider.of<PostProvider>(context, listen: false).isLoading &&
        Provider.of<PostProvider>(context, listen: false).hasMorePosts) {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      final postProvider = Provider.of<PostProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (locationProvider.currentPosition != null && authProvider.currentUser != null) {
        postProvider.fetchNearbyPosts(
          locationProvider.currentPosition!.latitude,
          locationProvider.currentPosition!.longitude,
          currentUserId: authProvider.currentUser!.uid,
          limit: 10,
        );
      }
    }
  }

  Future<Map<String, String?>> _getLocationDetails(dynamic location) async {
    if (location == null) return {};
    double latitude = location is GeoPoint ? location.latitude : location.latitude;
    double longitude = location is GeoPoint ? location.longitude : location.longitude;
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final placeName = placemark.name?.isNotEmpty == true
            ? placemark.name
            : placemark.subLocality?.isNotEmpty == true
                ? placemark.subLocality
                : placemark.locality;
        print('Location details for ($latitude, $longitude): placeName=$placeName');
        return {
          'placeName': placeName,
          'street': placemark.street,
          'city': placemark.locality,
          'country': placemark.country,
          'postalCode': placemark.postalCode,
        };
      }
      return {};
    } catch (e) {
      print('Error getting location details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch location details')),
      );
      return {};
    }
  }

  void _showDatePicker() {
    showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    ).then((date) {
      if (date != null && mounted) {
        setState(() {
          _isTimeMachineMode = true;
          _selectedDate = date;
        });
        final locationProvider = Provider.of<LocationProvider>(context, listen: false);
        final postProvider = Provider.of<PostProvider>(context, listen: false);
        if (locationProvider.currentPosition != null) {
          postProvider.resetPosts();
          postProvider.fetchLocationHistory(
            locationProvider.currentPosition!.latitude,
            locationProvider.currentPosition!.longitude,
            startDate: date,
            endDate: date.add(const Duration(days: 1)),
          );
        }
      }
    });
  }

  void _showFullscreenMedia(String mediaUrl, String mediaType) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: mediaType == 'video'
                  ? AspectRatio(
                      aspectRatio: 16 / 9,
                      child: VideoPlayer(VideoPlayerController.network(mediaUrl)
                        ..initialize().then((_) => setState(() {}))),
                    )
                  : InteractiveViewer(
                      maxScale: 4.0,
                      child: Image.network(mediaUrl, fit: BoxFit.contain),
                    ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPostBottomSheet(BuildContext context, String postType) {
    final TextEditingController contentController = TextEditingController();
    XFile? _selectedMedia;
    String? _mediaType;
    double _visibilityRadius = 2.0;
    String _visibility = 'public';
    String _geotagPrecision = 'precise';
    String? _placeName;
    bool _isPosting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      postType == 'geotagged'
                          ? 'Create Geotagged Post'
                          : postType == 'checkIn'
                              ? 'Check-In'
                              : 'Create Invitation',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextField(
                              controller: contentController,
                              decoration: InputDecoration(
                                hintText: postType == 'invitation'
                                    ? 'Invite others (e.g., Having lunch at...)'
                                    : postType == 'checkIn'
                                        ? 'What’s happening at this place?'
                                        : 'What’s happening nearby?',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: AppColors.grey600.withOpacity(0.1),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.primaryTeal, width: 2),
                                ),
                              ),
                              maxLines: 3,
                            ),
                            if (postType == 'checkIn') ...[
                              const SizedBox(height: 16),
                              TextField(
                                decoration: InputDecoration(
                                  hintText: 'Enter place name (e.g., Granddaddies)',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.grey600.withOpacity(0.1),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: AppColors.primaryTeal, width: 2),
                                  ),
                                ),
                                onChanged: (value) {
                                  setModalState(() {
                                    _placeName = value;
                                  });
                                },
                              ),
                            ],
                            if (postType == 'invitation') ...[
                              const SizedBox(height: 16),
                              TextField(
                                decoration: InputDecoration(
                                  hintText: 'Duration (minutes, e.g., 60)',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.grey600.withOpacity(0.1),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: AppColors.primaryTeal, width: 2),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  setModalState(() {
                                    int? duration = int.tryParse(value);
                                    if (duration != null) {
                                      _placeName = 'Invitation Event';
                                    }
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.image, color: AppColors.primaryTeal),
                              onPressed: () async {
                                final picker = ImagePicker();
                                final file = await picker.pickImage(source: ImageSource.gallery);
                                if (file != null) {
                                  setModalState(() {
                                    _selectedMedia = file;
                                    _mediaType = 'image';
                                  });
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.gif, color: AppColors.primaryTeal),
                              onPressed: () async {
                                final picker = ImagePicker();
                                final file = await picker.pickImage(source: ImageSource.gallery);
                                if (file != null) {
                                  setModalState(() {
                                    _selectedMedia = file;
                                    _mediaType = 'gif';
                                  });
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.videocam, color: AppColors.primaryTeal),
                              onPressed: () async {
                                final picker = ImagePicker();
                                final file = await picker.pickVideo(source: ImageSource.gallery);
                                if (file != null) {
                                  setModalState(() {
                                    _selectedMedia = file;
                                    _mediaType = 'video';
                                  });
                                }
                              },
                            ),
                            if (postType != 'checkIn')
                              IconButton(
                                icon: const Icon(Icons.live_tv, color: AppColors.primaryTeal),
                                onPressed: () {
                                  setModalState(() {
                                    _mediaType = 'livestream';
                                    _selectedMedia = null;
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (_selectedMedia != null && _mediaType != 'livestream')
                      Container(
                        height: 200,
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.grey600.withOpacity(0.3)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _mediaType == 'video'
                              ? VideoPlayer(VideoPlayerController.file(File(_selectedMedia!.path)))
                              : Image.file(File(_selectedMedia!.path), fit: BoxFit.cover),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            DropdownButtonFormField<String>(
                              value: _visibility,
                              decoration: InputDecoration(
                                labelText: 'Visibility',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: AppColors.grey600.withOpacity(0.1),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'public', child: Text('Public')),
                                DropdownMenuItem(value: 'friends', child: Text('Friends')),
                                DropdownMenuItem(value: 'private', child: Text('Private')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setModalState(() {
                                    _visibility = value;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _geotagPrecision,
                              decoration: InputDecoration(
                                labelText: 'Geotag Precision',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: AppColors.grey600.withOpacity(0.1),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'precise', child: Text('Precise Location')),
                                DropdownMenuItem(value: 'general', child: Text('General Area')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setModalState(() {
                                    _geotagPrecision = value;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Visibility Radius: ${_visibilityRadius.toStringAsFixed(1)} km',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: AppColors.textDark,
                                      ),
                                ),
                                Text(
                                  '${_visibilityRadius.toStringAsFixed(1)} km',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppColors.grey600,
                                      ),
                                ),
                              ],
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
                                activeTrackColor: AppColors.primaryTeal,
                                inactiveTrackColor: AppColors.grey600.withOpacity(0.3),
                                thumbColor: AppColors.primaryTeal,
                                overlayColor: AppColors.primaryTeal.withOpacity(0.2),
                                valueIndicatorColor: AppColors.primaryTeal,
                                valueIndicatorTextStyle: const TextStyle(color: AppColors.white),
                              ),
                              child: Slider(
                                value: _visibilityRadius,
                                min: 1.0,
                                max: 5.0,
                                divisions: 4,
                                label: '${_visibilityRadius.toStringAsFixed(1)} km',
                                onChanged: (value) {
                                  setModalState(() {
                                    _visibilityRadius = value;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isPosting
                            ? null
                            : () async {
                                if (contentController.text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter some content')),
                                  );
                                  return;
                                }
                                setModalState(() => _isPosting = true);
                                try {
                                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                  if (authProvider.currentUser != null) {
                                    await Provider.of<PostProvider>(context, listen: false).createPost(
                                      authProvider.currentUser!.uid,
                                      contentController.text,
                                      media: _selectedMedia,
                                      mediaType: _mediaType,
                                      visibilityRadiusKm: _visibilityRadius,
                                      isLive: _mediaType == 'livestream',
                                      visibility: _visibility,
                                      geotagPrecision: _geotagPrecision,
                                      postType: postType,
                                      placeName: _placeName,
                                      invitationDuration: postType == 'invitation' ? int.tryParse(_placeName ?? '') : null,
                                    );
                                    if (mounted) {
                                      Navigator.pop(context);
                                    }
                                  }
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to create post: $e')),
                                  );
                                } finally {
                                  setModalState(() => _isPosting = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryTeal,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isPosting
                            ? const CircularProgressIndicator(color: AppColors.white, strokeWidth: 2)
                            : const Text('Post', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCommentsBottomSheet(BuildContext context, PostModel post) {
    final TextEditingController commentController = TextEditingController();
    final postProvider = Provider.of<PostProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    postProvider.fetchComments(post.postId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Comments (${post.commentsCount})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Consumer<PostProvider>(
                    builder: (context, postProvider, child) {
                      final comments = postProvider.commentsForPost(post.postId);
                      if (comments.isEmpty) {
                        return const Center(child: Text('No comments yet'));
                      }
                      return ListView.builder(
                        controller: scrollController,
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance.collection('users').doc(comment.userId).get(),
                            builder: (context, snapshot) {
                              String displayName = 'Unknown';
                              String? photoURL;
                              if (snapshot.hasData && snapshot.data!.exists) {
                                final userData = snapshot.data!.data() as Map<String, dynamic>;
                                final user = UserModel.fromMap(userData);
                                displayName = user.displayName;
                                photoURL = user.photoURL;
                              }
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 20,
                                  backgroundImage: photoURL != null && photoURL.isNotEmpty
                                      ? NetworkImage(photoURL)
                                      : null,
                                  child: photoURL == null || photoURL.isEmpty
                                      ? const Icon(Icons.person, color: AppColors.textSecondary)
                                      : null,
                                ),
                                title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(comment.content),
                                trailing: Text(
                                  '${comment.timestamp.hour}:${comment.timestamp.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(color: AppColors.grey600),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                if (authProvider.currentUser != null &&
                    (post.visibility == 'public' ||
                        post.userId == authProvider.currentUser!.uid ||
                        (post.visibility == 'friends' &&
                            authProvider.currentUser!.friends.contains(post.userId))))
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                      left: 16,
                      right: 16,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentController,
                            decoration: const InputDecoration(
                              hintText: 'Add a comment...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send, color: AppColors.primaryTeal),
                          onPressed: () async {
                            if (commentController.text.isNotEmpty && authProvider.currentUser != null) {
                              await HapticFeedback.lightImpact();
                              await postProvider.addComment(
                                post.postId,
                                authProvider.currentUser!.uid,
                                commentController.text,
                              );
                              commentController.clear();
                            }
                          },
                        ),
                      ],
                    ),
                  ) 
                ],
              );
          
            
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Scaffold(
      appBar: const CustomAppBar(),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.profileGradient),
        child: RefreshIndicator(
          onRefresh: () async {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            final locationProvider = Provider.of<LocationProvider>(context, listen: false);
            final postProvider = Provider.of<PostProvider>(context, listen: false);
            if (authProvider.currentUser != null && locationProvider.currentPosition != null) {
              postProvider.resetPosts();
              await Future.wait([
                locationProvider.updateUserLocation(authProvider.currentUser!.uid),
                postProvider.fetchNearbyPosts(
                  locationProvider.currentPosition!.latitude,
                  locationProvider.currentPosition!.longitude,
                  currentUserId: authProvider.currentUser!.uid,
                  limit: 10,
                ),
              ]);
            }
          },
          color: AppColors.primaryTeal,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(mediaQuery.size.width * 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    if (authProvider.currentUser == null) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.primaryTeal));
                    }
                    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
                    final isLocationStale = locationProvider.lastUpdated != null &&
                        DateTime.now().difference(locationProvider.lastUpdated!).inHours > 1;
                    return CustomCard(
                      glassEffect: true,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.symmetric(horizontal: 0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.profile,
                                    arguments: authProvider.currentUser!.uid,
                                  );
                                },
                                child: CircleAvatar(
                                  radius: 30,
                                  backgroundImage: authProvider.currentUser!.photoURL.isNotEmpty
                                      ? NetworkImage(authProvider.currentUser!.photoURL)
                                      : null,
                                  child: authProvider.currentUser!.photoURL.isEmpty
                                      ? const Icon(Icons.person, color: AppColors.textSecondary, size: 50)
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome back,',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: AppColors.grey600,
                                          ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.pushNamed(
                                          context,
                                          AppRoutes.profile,
                                          arguments: authProvider.currentUser!.uid,
                                        );
                                      },
                                      child: Text(
                                        authProvider.currentUser?.displayName ?? 'Guest',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                      ),
                                    ),
                                    FutureBuilder<Map<String, String?>>(
                                      future: _getLocationDetails(authProvider.currentUser?.location),
                                      builder: (context, snapshot) {
                                        final locationDetails = snapshot.data ?? {};
                                        final displayLocation = locationDetails['placeName'] ??
                                            [
                                              locationDetails['city'],
                                              locationDetails['country'],
                                            ].where((e) => e != null && e.isNotEmpty).join(', ');
                                        return Text(
                                          displayLocation.isNotEmpty ? displayLocation : 'Unknown location',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: AppColors.grey600,
                                              ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              Consumer<LocationProvider>(
                                builder: (context, locationProvider, child) {
                                  return Column(
                                    children: [
                                      Icon(
                                        locationProvider.currentPosition != null
                                            ? Icons.location_on
                                            : Icons.location_off,
                                        color: locationProvider.currentPosition != null
                                            ? Colors.green
                                            : Colors.redAccent,
                                      ),
                                      Text(
                                        locationProvider.currentPosition != null ? 'Online' : 'Offline',
                                        style: TextStyle(
                                          color: locationProvider.currentPosition != null
                                              ? Colors.green
                                              : Colors.redAccent,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                          if (isLocationStale)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: GestureDetector(
                                onTap: () {
                                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                  if (authProvider.currentUser != null) {
                                    locationProvider.updateUserLocation(authProvider.currentUser!.uid);
                                  }
                                },
                                child: Text(
                                  'Location may be outdated. Tap to refresh.',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppColors.accentRed,
                                        fontStyle: FontStyle.italic,
                                      ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                SizedBox(height: mediaQuery.size.height * 0.03),
                Consumer<PostProvider>(
                  builder: (context, postProvider, child) {
                    if (postProvider.isLoading && postProvider.posts.isEmpty) {
                      return _buildSkeletonLoader();
                    } else if (postProvider.errorMessage != null) {
                      return CustomCard(
                        glassEffect: true,
                        padding: const EdgeInsets.all(24),
                        margin: const EdgeInsets.symmetric(horizontal: 0),
                        child: Column(
                          children: [
                            const Icon(Icons.error_outline, size: 50, color: AppColors.accentRed),
                            const SizedBox(height: 10),
                            Text(
                              postProvider.errorMessage!,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.accentRed,
                                    fontSize: 16,
                                    
                                  ),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: () {
                                final locationProvider = Provider.of<LocationProvider>(context, listen: false);
                                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                if (locationProvider.currentPosition != null && authProvider.currentUser != null) {
                                  postProvider.resetPosts();
                                  postProvider.fetchNearbyPosts(
                                    locationProvider.currentPosition!.latitude,
                                    locationProvider.currentPosition!.longitude,
                                    currentUserId: authProvider.currentUser!.uid,
                                    limit: 10,
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryTeal,
                                foregroundColor: AppColors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    } else if (postProvider.posts.isEmpty) {
                      return CustomCard(
                        glassEffect: true,
                        padding: const EdgeInsets.all(24),
                        margin: const EdgeInsets.symmetric(horizontal: 0),
                        child: Column(
                          children: [
                            const Icon(Icons.add, size: 50, color: AppColors.textSecondary),
                            const SizedBox(height: 10),
                            const Text(
                              'No posts available nearby',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Try creating a post or moving to a new location.',
                              style: TextStyle(color: AppColors.grey600),
                            ),
                          ],
                        ),
                      );
                    }
                    final postsWithAds = <Widget>[];
                    for (var i = 0; i < postProvider.posts.length; i++) {
                      final post = postProvider.posts[i];
                      if (post.postType == 'arTag') continue;
                      postsWithAds.add(
                        CustomCard(
                          glassEffect: true,
                          margin: const EdgeInsets.only(bottom: 16, left: 0, right: 0),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance.collection('users').doc(post.userId).get(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData && snapshot.data!.exists) {
                                    final userData = snapshot.data!.data();
                                    if (userData != null) {
                                      final user = UserModel.fromMap(userData as Map<String, dynamic>);
                                      final distance = post.geotagPrecision == 'precise' &&
                                              Provider.of<LocationProvider>(context, listen: false)
                                                      .currentPosition !=
                                                  null
                                          ? latlong.Distance().as(
                                              latlong.LengthUnit.Meter,
                                              latlong.LatLng(
                                                Provider.of<LocationProvider>(context, listen: false)
                                                    .currentPosition!.latitude,
                                                Provider.of<LocationProvider>(context, listen: false)
                                                    .currentPosition!.longitude,
                                              ),
                                              latlong.LatLng(
                                                post.location.latitude,
                                                post.location.longitude,
                                              ),
                                            )
                                          : null;
                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.pushNamed(
                                            context,
                                            AppRoutes.profile,
                                            arguments: post.userId,
                                          );
                                        },
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 20,
                                              backgroundImage: user.photoURL.isNotEmpty
                                                  ? NetworkImage(user.photoURL)
                                                  : null,
                                              child: user.photoURL.isEmpty
                                                  ? const Icon(Icons.person, color: AppColors.textSecondary)
                                                  : null,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    user.displayName,
                                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                          fontWeight: FontWeight.bold,
                                                          color: AppColors.textPrimary,
                                                        ),
                                                  ),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        'at ${post.placeName ?? 'Unknown place'}',
                                                        style:
                                                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                                  color: AppColors.primaryTeal,
                                                                  fontWeight: FontWeight.w600,
                                                                ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        timeago.format(post.timestamp),
                                                        style:
                                                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                                                  color: AppColors.grey600,
                                                                ),
                                                      ),
                                                      if (post.geotagPrecision == 'precise' && distance != null)
                                                        Padding(
                                                          padding: const EdgeInsets.only(left: 8),
                                                          child: Text(
                                                            '${distance.toStringAsFixed(0)}m away',
                                                            style:
                                                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                                                      color: AppColors.grey600,
                                                                    ),
                                                          ),
                                                        )
                                                      else if (post.geotagPrecision == 'general')
                                                        Padding(
                                                          padding: const EdgeInsets.only(left: 8),
                                                          child: Text(
                                                            'Approximate location',
                                                            style:
                                                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                                                      color: AppColors.grey600,
                                                                      fontStyle: FontStyle.italic,
                                                                    ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (post.postType != 'geotagged')
                                              Chip(
                                                label: Text(
                                                  post.postType == 'checkIn' ? 'Check-In' : 'Invitation',
                                                  style: const TextStyle(color: AppColors.white),
                                                ),
                                                backgroundColor: post.postType == 'checkIn'
                                                    ? Colors.green
                                                    : AppColors.primaryTeal,
                                              ),
                                          ],
                                        ),
                                      );
                                    }
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                              const SizedBox(height: 8),
                              Text(
                                post.content,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                              ),
                              if (post.mediaUrl != null && post.mediaType != null) ...[
                                const SizedBox(height: 8),
                                if (post.mediaType == 'image' || post.mediaType == 'gif')
                                  GestureDetector(
                                    onTap: () => _showFullscreenMedia(post.mediaUrl!, post.mediaType!),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        post.mediaUrl!,
                                        height: 300,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          height: 300,
                                          color: AppColors.grey600.withOpacity(0.3),
                                          child: const Center(child: Text('Failed to load image')),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (post.mediaType == 'video') ...[
                                  StatefulBuilder(
                                    builder: (context, setVideoState) {
                                      final controller = _videoControllers.putIfAbsent(
                                        post.mediaUrl!,
                                        () => VideoPlayerController.network(post.mediaUrl!)
                                          ..initialize().then((_) => setVideoState(() {})),
                                      );
                                      return Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          AspectRatio(
                                            aspectRatio: controller.value.isInitialized
                                                ? controller.value.aspectRatio
                                                : 16 / 9,
                                            child: VideoPlayer(controller),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                                              color: Colors.white,
                                              size: 48,
                                            ),
                                            onPressed: () {
                                              setVideoState(() {
                                                controller.value.isPlaying
                                                    ? controller.pause()
                                                    : controller.play();
                                              });
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                                if (post.mediaType == 'livestream' && post.isLive)
                                  Container(
                                    height: 300,
                                    width: double.infinity,
                                    color: AppColors.grey600.withOpacity(0.3),
                                    child: const Center(child: Text('Live stream placeholder')),
                                  ),
                              ],
                              const SizedBox(height: 8),
                              if (post.likes.isNotEmpty || post.postType == 'invitation') ...[
                                Wrap(
                                  spacing: 4,
                                  children: [
                                    if (post.likes.isNotEmpty)
                                      FutureBuilder<List<Map<String, dynamic>>>(
                                        future: Future.wait(
                                          post.likes.take(3).map((userId) => FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(userId)
                                              .get()
                                              .then((doc) => {
                                                    'uid': userId,
                                                    'photoURL': doc.exists
                                                        ? (doc.data() as Map<String, dynamic>)['photoURL']
                                                        : null,
                                                  })),
                                        ),
                                        builder: (context, snapshot) {
                                          if (!snapshot.hasData) {
                                            return const SizedBox.shrink();
                                          }
                                          final likers = snapshot.data!;
                                          return Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: likers
                                                .map((liker) => Padding(
                                                      padding: const EdgeInsets.only(right: 4),
                                                      child: CircleAvatar(
                                                        radius: 12,
                                                        backgroundImage: liker['photoURL'] != null
                                                            ? NetworkImage(liker['photoURL']!)
                                                            : null,
                                                        child: liker['photoURL'] == null
                                                            ? const Icon(
                                                                Icons.person,
                                                                size: 12,
                                                                color: AppColors.grey600,
                                                              )
                                                            : null,
                                                      ),
                                                    ))
                                                .toList(),
                                          );
                                        },
                                      ),
                                    if (post.postType == 'invitation' && post.rsvpList.isNotEmpty)
                                      Text(
                                        '${post.rsvpList.length} joined',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: AppColors.grey600,
                                            ),
                                      ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 8),
                              Consumer<AuthProvider>(
                                builder: (context, authProvider, child) {
                                  final canInteract = authProvider.currentUser != null &&
                                      (post.visibility == 'public' ||
                                          post.userId == authProvider.currentUser!.uid ||
                                          (post.visibility == 'friends' &&
                                              authProvider.currentUser!.friends.contains(post.userId)));
                                  final isLiked = canInteract &&
                                      post.likes.contains(authProvider.currentUser?.uid ?? '');
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                                              color: AppColors.primaryTeal,
                                            ).animate(
                                              autoPlay: false,
                                              key: ValueKey('${post.postId}_like_$isLiked'),
                                           effects: [
                  ScaleEffect(
                    begin: const Offset(1.0, 1.0), // Uniform scale 1x
                    end: const Offset(1.2, 1.2),   // Uniform scale 1.2x
                    duration: const Duration(milliseconds: 100),
                    curve: Curves.easeInOut,
                  ),
                  ScaleEffect(
                    begin: const Offset(1.2, 1.2), // Uniform scale 1.2x
                    end: const Offset(1.0, 1.0),   // Uniform scale 1x
                    duration: const Duration(milliseconds: 100),
                    curve: Curves.easeInOut,
                  ),
                ],
                                            ),
                                            onPressed: canInteract
                                                ? () async {
                                                    await HapticFeedback.lightImpact();
                                                    if (isLiked) {
                                                      postProvider.unlikePost(
                                                        post.postId,
                                                        authProvider.currentUser!.uid,
                                                      );
                                                    } else {
                                                      postProvider.likePost(
                                                        post.postId,
                                                        authProvider.currentUser!.uid,
                                                      );
                                                    }
                                                  }
                                                : null,
                                        
                                          ),
                                          Text(
                                            '${post.likes.length}',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: AppColors.textPrimary,
                                                ),
                                          ),
                                          const SizedBox(width: 16),
                                          IconButton(
                                            icon: const Icon(Icons.comment, color: AppColors.primaryTeal),
                                            onPressed: canInteract
                                                ? () async {
                                                    await HapticFeedback.lightImpact();
                                                    _showCommentsBottomSheet(context, post);
                                                  }
                                                : null,
                                            
                                          ),
                                          Text(
                                            '${post.commentsCount}',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: AppColors.textPrimary,
                                                ),
                                          ),
                                        ],
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.share, color: AppColors.primaryTeal),
                                        onPressed: () async {
                                          await HapticFeedback.lightImpact();
                                          Share.share(
                                            'Check out this post on Duze: ${post.content} at ${post.placeName ?? 'nearby location'}! https://duze.app/post/${post.postId}',
                                            subject: 'Duze Post',
                                          );
                                        },
                                      
                                      ),
                                    ],
                                  );
                                },
                              ),
                              if (post.postType == 'invitation') ...[
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('RSVP sent!')),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryTeal,
                                    foregroundColor: AppColors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('Join'),
                                ),
                              ],
                            ],
                          ),
                        ).animate().fadeIn(
                              duration: const Duration(milliseconds: 600),
                              delay: Duration(milliseconds: i * 150),
                            ),
                      );
                      if ((i + 1) % 5 == 0 && _isAdLoaded && _nativeAd != null) {
                        postsWithAds.add(
                          Container(
                            height: 100,
                            margin: const EdgeInsets.only(bottom: 16, left: 0, right: 0),
                            child: AdWidget(ad: _nativeAd!),
                          ),
                        );
                      }
                    }
                    if (postProvider.isLoading) {
                      postsWithAds.add(
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator(color: AppColors.primaryTeal)),
                        ),
                      );
                    }
                    if (!postProvider.hasMorePosts && postProvider.posts.isEmpty) {
                      postsWithAds.add(
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: Text('No more posts to load')),
                        ),
                      );
                    }
                    return Column(children: postsWithAds);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SpeedDial(
            icon: Icons.add,
            activeIcon: Icons.close,
            backgroundColor: AppColors.primaryTeal,
            children: [
              SpeedDialChild(
                child: const Icon(Icons.post_add),
                label: 'Geotagged Post',
                onTap: () => _showPostBottomSheet(context, 'geotagged'),
              ),
              SpeedDialChild(
                child: const Icon(Icons.location_on),
                label: 'Check-In',
                onTap: () => _showPostBottomSheet(context, 'checkIn'),
              ),
              SpeedDialChild(
                child: const Icon(Icons.group_add),
                label: 'Invitation',
                onTap: () => _showPostBottomSheet(context, 'invitation'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Column(
      children: List.generate(
        3,
        (_) => CustomCard(
          glassEffect: true,
          margin: const EdgeInsets.only(bottom: 16, left: 0, right: 0),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(radius: 20, backgroundColor: AppColors.grey600.withOpacity(0.3)),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 100,
                        height: 16,
                        color: AppColors.grey600.withOpacity(0.3),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 50,
                        height: 12,
                        color: AppColors.grey600.withOpacity(0.3),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 200,
                color: AppColors.grey600.withOpacity(0.3),
              ),
            ],
          ),
        ).animate().fadeIn(duration: const Duration(milliseconds: 400)),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nativeAd?.dispose();
    _videoControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }
}