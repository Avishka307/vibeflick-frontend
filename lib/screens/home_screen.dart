import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_vibe_flick/screens/post_detail_page.dart';
import '../sample/nearby_post_card.dart';
import 'for_you_screen.dart';

// Global camera list for pre-loading
List<CameraDescription>? globalCameras;

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const String TAG = "HomeFragment";
  late TabController _tabController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    debugPrint("$TAG: HomeFragment created");
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentIndex = _tabController.index;
      });
    });

    // ✅ Check if user is guest
    _checkUserStatus();

    // 🚀 PRE-LOAD CAMERA IN BACKGROUND
    _preloadCameras();
  }

  void _checkUserStatus() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('👤 Guest user browsing videos');
    } else {
      debugPrint('✅ Logged in user: ${currentUser.uid}');
    }
  }

  // 🎥 Pre-load cameras when home screen opens
  Future<void> _preloadCameras() async {
    if (globalCameras == null) {
      try {
        debugPrint('📸 Pre-loading cameras in background...');
        globalCameras = await availableCameras();
        debugPrint('✅ Cameras pre-loaded: ${globalCameras?.length} cameras found');
      } catch (e) {
        debugPrint('❌ Error pre-loading cameras: $e');
      }
    } else {
      debugPrint('✅ Cameras already pre-loaded');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    debugPrint("ViewPagerAdapter: Creating tabs for user: $currentUserId");

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 80,
        flexibleSpace: SafeArea(
          child: _buildTikTokStyleTabBar(),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          // For You Tab
          ForYouScreen(),
          // Nearby Tab
          NearbyFeedScreen(),
          // Following Tab
          FollowingFeedScreen(),
        ],
      ),
    );
  }

  Widget _buildTikTokStyleTabBar() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTabItem("For You", 0),
          const SizedBox(width: 20),
          Container(
            width: 1,
            height: 16,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(width: 20),
          _buildTabItem("Nearby", 1),      // 📍 නව tab
          const SizedBox(width: 20),
          Container(
            width: 1,
            height: 16,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(width: 20),
          _buildTabItem("Following", 2),   // index 1 → 2 වෙනස් වුණා
        ],
      ),
    );
  }
  Widget _buildTabItem(String title, int index) {
    bool isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        _tabController.animateTo(index);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isSelected ? 18 : 17,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: Colors.white.withOpacity(isSelected ? 1.0 : 0.5),
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.3),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: 2,
            width: isSelected ? (title == "For You" ? 55 : 70) : 0,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 🆕 FOLLOWING FEED SCREEN - Uses PostDetailPage
// ═══════════════════════════════════════════════════════════════
class FollowingFeedScreen extends StatefulWidget {
  const FollowingFeedScreen({Key? key}) : super(key: key);

  @override
  State<FollowingFeedScreen> createState() => _FollowingFeedScreenState();
}

class _FollowingFeedScreenState extends State<FollowingFeedScreen>
    with AutomaticKeepAliveClientMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final PageController _pageController = PageController();

  List<String> _followingPostIds = [];
  bool _isLoading = true;
  String? _currentUserId;
  int _currentPageIndex = 0;

  @override
  bool get wantKeepAlive => true; // 🔧 Keep state alive

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid;

    // 🔧 Add delay before loading to ensure widget is mounted
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _loadFollowingPostIds();
      }
    });

    _pageController.addListener(() {
      if (!mounted) return;
      final newPage = _pageController.page?.round() ?? 0;
      if (newPage != _currentPageIndex) {
        setState(() {
          _currentPageIndex = newPage;
        });
        debugPrint('📄 Following feed - Page changed to: $newPage');
      }
    });
  }

  Future<void> _loadFollowingPostIds() async {
    if (!mounted) return;

    if (_currentUserId == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      debugPrint('📥 Loading following posts for user: $_currentUserId');

      // Get list of users that current user is following (active status only)
      final followingSnapshot = await _db
          .collection('follows')
          .where('followerId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'active')
          .get();

      debugPrint('👥 Found ${followingSnapshot.docs.length} following users');

      if (!mounted) return;

      if (followingSnapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _followingPostIds = [];
          });
        }
        return;
      }

      // Extract following user IDs
      List<String> followingUserIds = [];
      for (var doc in followingSnapshot.docs) {
        final followingId = doc.data()['followingId'] as String?;
        if (followingId != null) {
          followingUserIds.add(followingId);
        }
      }

      debugPrint('📋 Following user IDs: $followingUserIds');

      // Load followers-only posts from following users
      _followingPostIds.clear();

      for (String userId in followingUserIds) {
        if (!mounted) return;

        final postsSnapshot = await _db
            .collection('media_posts')
            .where('uid', isEqualTo: userId)
            .where('who_can_view', isEqualTo: 'followers')
            .where('is_active', isEqualTo: true)
            .orderBy('timestamp', descending: true)
            .limit(20)
            .get();

        debugPrint(
            '📊 User $userId has ${postsSnapshot.docs.length} followers posts');

        for (var doc in postsSnapshot.docs) {
          _followingPostIds.add(doc.id);
        }
      }

      debugPrint('✅ Loaded ${_followingPostIds.length} following post IDs');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading following posts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 🔧 Required for AutomaticKeepAliveClientMixin

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        ),
      );
    }

    if (_followingPostIds.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.shade400,
                      Colors.purple.shade400,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.people_outline_rounded,
                  size: 70,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'No Following Posts',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'You\'re not following anyone yet.\nFollow users to see their posts here!',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade400,
                  height: 1.6,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _loadFollowingPostIds,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ Vertical PageView with PostDetailPage for each post
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _followingPostIds.length,
        itemBuilder: (context, index) {
          final postId = _followingPostIds[index];

          // ✅ Use PostDetailPage with hideBackButton = true
          return PostDetailPage(
            postId: postId,
            hideBackButton: true,
            key: ValueKey(postId),
          );
        },
      ),
    );
  }
}