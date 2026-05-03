import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:my_vibe_flick/Notification/CommentNotification/fcm_service.dart';
import 'package:my_vibe_flick/screens/activity_user_profile.dart';
import 'package:my_vibe_flick/screens/notification_service.dart';
import 'package:my_vibe_flick/screens/post_detail_page.dart';
import 'firebase_options.dart'; // අලුතින් හැදුණු file එක
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/trending_screen.dart';
import 'screens/upload_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ ADD THIS LINE
import 'screens/banned_user_screen.dart'; // ✅ ADD
// =================== ✅ GLOBAL NAVIGATOR KEY ===================
// මේකෙන් app එකේ ඕනෑම තැනක ඉඳන් navigate කරන්න පුළුවන්
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final _appLinks = AppLinks();
// ✅ STEP 1: Register background message handler at TOP LEVEL
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await firebaseMessagingBackgroundHandler(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🔥 Initializing Firebase...');

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('✅ Firebase initialized');

  FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler);

  await NotificationService().initialize();

  FirebaseDatabase.instance.databaseURL =
  'https://vibeflick-5fe5c-default-rtdb.asia-southeast1.firebasedatabase.app';

  FirebaseDatabase.instance.setPersistenceEnabled(true);
  FirebaseDatabase.instance.setPersistenceCacheSizeBytes(10000000);

  // 🔥 SUPABASE INITIALIZE කරන්න
// ✅ VERIFIED CORRECT!
  await supabase.Supabase.initialize(
    url: 'https://ppwugappmmmdryqxufru.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBwd3VnYXBwbW1tZHJ5cXh1ZnJ1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA4NDkwMTMsImV4cCI6MjA4NjQyNTAxM30.l1GXZBy9oBzlMrAQYvZEnDZf3EGeS31dDj5xJR0BcGQ',
  );


  runApp(const VibeFlickApp());
}



class VibeFlickApp extends StatefulWidget {
  const VibeFlickApp({super.key});

  @override
  State<VibeFlickApp> createState() => _VibeFlickAppState();
}

class _VibeFlickAppState extends State<VibeFlickApp> {
  final FCMService _fcmService = FCMService();

  @override
  void initState() {
    super.initState();
    _initializeFCM();
    _setupAuthListener();
    _handleDeepLinks();
  }

  // ✅ STEP 4: Initialize FCM on app start
  Future<void> _initializeFCM() async {
    print('🔔 Initializing FCM Service...');
    await _fcmService.initialize();
    print('✅ FCM Service ready!');
  }

  void _setupAuthListener() {
    print('👂 Setting up auth state listener...');

    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        print('\n👤 ========== USER LOGGED IN ==========');
        print('   User ID: ${user.uid}');
        print('   Email: ${user.email}');

        // ✅ Update FCM token
        await _fcmService.updateTokenForCurrentUser();

        // ✅ Auto-generate username if not set
        await _autoSetUsernameIfNeeded(user);

        print('==========================================\n');
      } else {
        print('\n👤 User logged out\n');
      }
    });

    print('✅ Auth listener active');
  }

  // ✅ Auto username generator — Firestore query only, no server needed
  Future<void> _autoSetUsernameIfNeeded(User user) async {
    try {
      print('🔤 Checking username for: ${user.uid}');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      // Username already set — skip
      if (userDoc.exists) {
        final existingUsername = userDoc.data()?['username'] as String?;
        if (existingUsername != null && existingUsername.trim().length >= 3) {
          print('ℹ️ Username already set: "$existingUsername"');
          return;
        }
      }

      // Generate base username from email
      final email = user.email ?? '';
      final emailPrefix = email.split('@')[0];
      String baseUsername = emailPrefix
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');

      if (baseUsername.length > 20) baseUsername = baseUsername.substring(0, 20);
      if (baseUsername.length < 3) baseUsername = 'user_$baseUsername';

      print('🔤 Base username: "$baseUsername"');

      // Find unique username
      final uniqueUsername = await _findUniqueUsername(baseUsername, user.uid);

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'username': uniqueUsername,
        'usernameSetAt': FieldValue.serverTimestamp(),
        'usernameAutoGenerated': true,
      }, SetOptions(merge: true));

      // Reserve in RTDB
      await FirebaseDatabase.instance
          .ref('usernames/$uniqueUsername')
          .set(user.uid);

      print('✅ Auto username set: "$uniqueUsername"');

    } catch (e) {
      print('⚠️ Auto username error (non-critical): $e');
    }
  }

  Future<String> _findUniqueUsername(String base, String userId) async {
    // Check base username
    final baseSnap = await FirebaseDatabase.instance
        .ref('usernames/$base')
        .get();

    if (!baseSnap.exists) {
      print('✅ Base username available: "$base"');
      return base;
    }

    // Try with suffixes _1, _2 ...
    for (int i = 1; i <= 99; i++) {
      final candidate = '${base.substring(0, base.length > 17 ? 17 : base.length)}_$i';
      final snap = await FirebaseDatabase.instance
          .ref('usernames/$candidate')
          .get();

      if (!snap.exists) {
        print('✅ Found available username: "$candidate"');
        return candidate;
      }
    }

    // Fallback — timestamp suffix
    final fallback = 'user_${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    print('⚠️ Using fallback username: "$fallback"');
    return fallback;
  }
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VibeFlick',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      // ✅ මේකයි main වෙනස - CRITICAL!
      theme: ThemeData(
        brightness: Brightness.dark,
        // මුළු ඇප් එකම Dark Mode වලට ලෑස්ති කරනවා
        scaffoldBackgroundColor: Colors.black,
        // හැම පේජ් එකකම බැක්ග්‍රවුන්ඩ් එක කළු කරනවා
        primaryColor: const Color(0xFFFF3B5C), // ඔයාගේ Upload button එකේ පාට
      ),
      home: const SplashScreen(),
    );
  }

  void _handleDeepLinks() async {
    // Cold start (app closed වෙලා තිබ්බා)
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) _navigateToPost(uri);
    } catch (e) {
      debugPrint('Deep link cold start error: $e');
    }

    // Background start
    _appLinks.uriLinkStream.listen((uri) {
      _navigateToPost(uri);
    });
  }

  void _navigateToPost(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.isEmpty) return;

    // POST: /post/POST_ID
    if (segments[0] == 'post' && segments.length >= 2) {
      final postId = segments[1];
      if (postId.isNotEmpty) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) =>
                PostDetailPage(
                  postId: postId,
                  hideBackButton: false,
                ),
          ),
        );
      }
    }

    // USER by ID: /user/USER_ID
    else if (segments[0] == 'user' && segments.length >= 2) {
      final userId = segments[1];
      if (userId.isNotEmpty) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => ActivityUserProfile(userId: userId),
          ),
        );
      }
    }

    // USER by USERNAME: /u/USERNAME
    else if (segments[0] == 'u' && segments.length >= 2) {
      final username = segments[1];
      if (username.isNotEmpty) {
        _navigateToProfileByUsername(username);
      }
    }
  }

// Username → Firestore lookup → navigate
  void _navigateToProfileByUsername(String username) async {
    try {
      // Firestore එකෙන් username එකෙන් user find කරනවා
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final userId = query.docs.first.id;
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;

        if (userId == currentUserId) {
          // ඕනර්ගෙම profile — MainScreen එකේ Profile tab එකට යනවා
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainScreen()),
                (route) => false,
          );
          // Profile tab (index 4) select කරනවා
          // MainScreen state access කරන්න global key use කරනවා
        } else {
          // වෙන කෙනෙකුගේ profile — ActivityUserProfile
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => ActivityUserProfile(userId: userId),
            ),
          );
        }
      } else {
        debugPrint('⚠️ Username not found: $username');
      }
    } catch (e) {
      debugPrint('❌ Error finding user by username: $e');
    }
  }
}
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  // 🆕 ADD: Public method to set index (upload_screen.dart එකෙන් call කරන්න)
  void setCurrentIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  final List<Widget> _screens = [
    const HomeScreen(),
    const TrendingScreen(),
    const UploadScreen(),
    const InboxScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    // ✅ Real-time Ban Listener
    if (currentUser != null) {
      return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final status = data['accountStatus'] ?? 'active';
            if (status == 'banned') {
              return const BannedUserScreen();
            }
          }
          return _buildMainScaffold();
        },
      );
    }
    // ✅ END

    return _buildMainScaffold();
  }

// ✅ ADD: Extract කළ scaffold method
  Widget _buildMainScaffold() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _screens[_currentIndex],
      bottomNavigationBar: _currentIndex == 2 ? null : SafeArea(
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.9),
            border: Border(
              top: BorderSide(
                  color: Colors.grey[900]!.withOpacity(0.3), width: 0.5),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItemSvg('assets/images/home-svgrepo-com.svg', 'Home', 0),
              _buildNavItemSvg(
                  'assets/images/hash-tag-svgrepo-com.svg', 'Trending', 1),
              _buildUploadButton(),
              _buildNavItemSvg(
                  'assets/images/message-2-pending-svgrepo-com.svg', 'ChatBox',
                  3),
              _buildNavItemSvg(
                  'assets/images/profile-round-1342-svgrepo-com.svg ', 'Profile',
                  4),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ HOME DOUBLE TAP හැන්ඩ්ලර් - Scroll to top & refresh
  void _handleHomeDoubleTap() {
    print('🏠 Home double tapped - Scrolling to top & refreshing');

    // TODO: HomeScreen එකට scroll controller එකක් pass කරලා
    // scroll to top කරන්න ඕන. ඒ වගේම refresh function එකක් call කරන්න.
    //
    // Example implementation එකක්:
    // if (_screens[0] is HomeScreen) {
    //   (_screens[0] as HomeScreen).scrollToTopAndRefresh();
    // }

    // දැනට print එකක් දාලා තියෙන්නේ test කරන්න
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Home double tapped! 🏠'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Widget _buildNavItemSvg(String svgPath, String label, int index) {
    final bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      onDoubleTap: () {
        if (index == 0 && _currentIndex == 0) {
          _handleHomeDoubleTap();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ Profile icon එක විතරක් Icon widget එකක් use කරනවා
            index == 4
                ? Icon(
              Icons.person,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 22,
            )
                : SvgPicture.asset(
              svgPath,
              colorFilter: ColorFilter.mode(
                isSelected ? Colors.white : Colors.grey[600]!,
                BlendMode.srcIn,
              ),
              width: 22,
              height: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ UPLOAD බටන් එක - Original design එකම තියෙනවා (වෙනසක් නැහැ)
  Widget _buildUploadButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = 2;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 45,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B5C), // ✅ TikTok pink/red color
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Upload',
              style: TextStyle(
                color: _currentIndex == 2 ? Colors.white : Colors.grey[600], // ✅ White when selected
                fontSize: 10, // ✅ Reduced from 11 to 10
                fontWeight: _currentIndex == 2 ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}