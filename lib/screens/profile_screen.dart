import 'dart:ui';


import 'package:my_vibe_flick/screens/profile_share_bottom_sheet.dart';

import 'activity_user_profile.dart';
import 'qr_feature.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_vibe_flick/Tab/tab_private_page.dart';
import 'package:my_vibe_flick/Tab/tab_repost_page.dart';
import 'package:my_vibe_flick/screens/activity_setting_option.dart';
import 'follow_list_screen.dart';
import 'dart:async';
import 'activity_edite_profile.dart';
import '../Tab/tab_saved_page.dart';

import 'user_tab_media.dart';
import 'activity_bio_edit.dart';
import 'cover_image_uploader.dart';
import 'activity_account_settings.dart';
import 'social_cards_tabs.dart';
import '../Thought/user_thoughts_tab.dart'; // adjust path
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool _isRefreshing = false;
  int _activeTab = 0;

  // Tab controller for better performance
  late TabController _tabController;

  // ── Firebase ────────────────────────────────────────────
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── User Data ───────────────────────────────────────────
  Map<String, dynamic> _userData = {
    'name': 'Loading...',
    'username': '@loading',
    'following': 0,
    'followers': 0,
    'likes': 0,
    'birthday': '',
    'show_birthday_tag': true,
    'show_age': true,
    'region': '',
  };

  String? _profileImageUrl;
  String? _coverImageUrl;

  String _currentUserName = '';
  String _currentUserEmail = '';

  // ── Listeners ───────────────────────────────────────────
  StreamSubscription? _profileImageListener;
  StreamSubscription? _userDataListener;
  StreamSubscription? _postsListener;

// ── Suggested Users ─────────────────────────────────────
  List<Map<String, dynamic>> _suggestedUsers = [];
  bool _isSuggestionsVisible = true;
  bool _isLoadingSuggestions = true;
  DocumentSnapshot? _lastSuggestedUserDoc;
  bool _hasMoreSuggestions = true;
  bool _isLoadingMoreSuggestions = false;

  // ── Avatar colours ──────────────────────────────────────
  final List<String> _avatarColors = [
    '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FECA57',
    '#FF9FF3', '#54A0FF', '#5F27CD', '#00D2D3', '#FF9F43',
    '#10AC84', '#EE5A24', '#0984E3', '#A29BFE', '#FD79A8',
    '#E17055', '#81ECEC', '#74B9FF', '#FDCB6E', '#6C5CE7',
  ];

  // ── Tab definitions ─────────────────────────────────────
  final _tabs = [
    {'icon': Icons.article_outlined, 'label': 'Creation'},
    {'icon': Icons.bookmark_outline, 'label': 'Private'},
    {'icon': Icons.edit_note_rounded, 'label': 'Thoughts'}, // ← REPLACE
    {'icon': Icons.bookmark, 'label': 'Saved'},
  ];

  // ══════════════════════════════════════════════════════════
  //  LIFECYCLE
  // ══════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize TabController
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _activeTab = _tabController.index;
        });
      }
    });

    _initializeProfile();
    _loadSuggestedUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _cancelAllListeners();
    super.dispose();
  }


  // ══════════════════════════════════════════════════════════
  //  DATA LAYER
  // ══════════════════════════════════════════════════════════

  void _initializeProfile() {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      final userUid = currentUser.uid;
      _loadUserData();
      _setupUserDataListener(userUid);
      _listenToProfileImageChanges(userUid);
      _listenToUserPostsAndLikes(userUid);
      _loadProfileImageQuick();
    }
  }

  void _cancelAllListeners() {
    _profileImageListener?.cancel();
    _userDataListener?.cancel();
    _postsListener?.cancel();
  }

  Future<void> _loadUserData() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final doc = await _db.collection('users').doc(currentUser.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _currentUserName = data['name'] ?? '';
          _currentUserEmail = data['email'] ?? currentUser.email ?? '';
          _userData = {
            'name': data['name'] ?? 'Unknown User',
            'username': '@${data['username'] ?? data['uid'] ?? 'unknown'}',
            'following': data['followingCount'] ?? 0,
            'followers': data['followerCount'] ?? 0,
            'likes': _userData['likes'],
            'bio': data['bio'] ?? '',
            'birthday': data['birthday'] ?? '',
            'show_birthday_tag': data['show_birthday_tag'] ?? true,
            'show_age': data['show_age'] ?? true,
            'region': data['region'] ?? '',
          };
          _coverImageUrl =
              data['cover_image_url'] ??
                  data['coverImageUrl'] ??
                  data['cover_url'];
        });
        debugPrint(
            '✅ User data loaded — Following: ${_userData['following']}, Followers: ${_userData['followers']}');
      }
    } catch (e) {
      debugPrint('❌ Error loading user data: $e');
    }
  }

  void _setupUserDataListener(String userUid) {
    _userDataListener = _db
        .collection('users')
        .doc(userUid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        setState(() {
          _currentUserName = data['name'] ?? '';
          _currentUserEmail = data['email'] ?? '';
          _userData['following'] = data['followingCount'] ?? 0;
          _userData['followers'] = data['followerCount'] ?? 0;
          _userData['bio'] = data['bio'] ?? '';
          _userData['birthday'] = data['birthday'] ?? '';
          _userData['show_birthday_tag'] = data['show_birthday_tag'] ?? true;
          _userData['show_age'] = data['show_age'] ?? true;
          _userData['region'] = data['region'] ?? '';
          _coverImageUrl =
              data['cover_image_url'] ??
                  data['coverImageUrl'] ??
                  data['cover_url'];
        });
      }
    }, onError: (error) {
      debugPrint('❌ Error in user data listener: $error');
    });
  }

  void _listenToProfileImageChanges(String userUid) {
    _profileImageListener = _db
        .collection('users')
        .doc(userUid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        _currentUserName = data['name'] ?? '';
        _currentUserEmail = data['email'] ?? '';
        setState(() {
          _profileImageUrl =
              data['profileImageUrl'] ?? // ✅ මේක add කරන්න
                  data['profile_picture_url'] ??
                  data['profile_url'] ??
                  data['profileUrl'];
        });
      }
    });
  }

  void _loadProfileImageQuick() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    try {
      final doc = await _db.collection('users').doc(currentUser.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _currentUserName = data['name'] ?? '';
        _currentUserEmail = data['email'] ?? currentUser.email ?? '';
        setState(() {
          _profileImageUrl =
              data['profile_picture_url'] ??
                  data['profile_url'] ??
                  data['profileUrl'];
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading profile image: $e');
    }
  }

  void _listenToUserPostsAndLikes(String userUid) {
    _postsListener = _db
        .collection('media_posts')
        .where('uid', isEqualTo: userUid)
        .snapshots()
        .listen((snapshot) {
      int totalLikes = 0;
      for (var doc in snapshot.docs) {
        totalLikes += (doc.data()['likes'] as int? ?? 0);
      }
      setState(() {
        _userData['likes'] = totalLikes;
      });
      debugPrint('💾 Total likes updated: $totalLikes');
    }, onError: (error) {
      debugPrint('❌ Error in posts listener: $error');
    });
  }

  // ══════════════════════════════════════════════════════════
  //  FOLLOW STATUS CHECK FUNCTIONS
  // ══════════════════════════════════════════════════════════

  /// Check if a user account is private
  Future<bool> _isAccountPrivate(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data()?['private_account'] ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error checking private account: $e');
      return false;
    }
  }

  /// Check if current user is following target user (status = 'accepted')
  Future<bool> _isFollowing(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      final followDocId = '${currentUser.uid}_$targetUserId';
      final doc = await _db.collection('follows').doc(followDocId).get();

      if (doc.exists) {
        final status = doc.data()?['status'];
        return status == 'accepted'; // Only true if accepted
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error checking follow status: $e');
      return false;
    }
  }

  /// Check if current user has already sent a follow request (status = 'pending')
  Future<bool> _isRequested(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      final followDocId = '${currentUser.uid}_$targetUserId';
      final doc = await _db.collection('follows').doc(followDocId).get();

      if (doc.exists) {
        final status = doc.data()?['status'];
        return status == 'pending'; // Request sent but not accepted yet
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error checking request status: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════
  //  SUGGESTED USERS LOGIC (SMART ALGORITHM)
  // ══════════════════════════════════════════════════════════
  Future<void> _loadSuggestedUsers({bool loadMore = false}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    if (loadMore && (_isLoadingMoreSuggestions || !_hasMoreSuggestions)) return;

    if (!loadMore) {
      setState(() => _isLoadingSuggestions = true);
      _lastSuggestedUserDoc = null;
      _hasMoreSuggestions = true;
    } else {
      setState(() => _isLoadingMoreSuggestions = true);
    }

    try {
      // 1️⃣ Following IDs (cached - once only)
      final followingSnapshot = await _db
          .collection('follows')
          .where('followerId', isEqualTo: currentUser.uid)
          .get();

      final followingIds = followingSnapshot.docs
          .map((doc) => doc.data()['followingId'] as String)
          .toSet();

      // 2️⃣ Paginated users query - limit(15) per page
      Query query = _db.collection('users').limit(15);
      if (_lastSuggestedUserDoc != null) {
        query = query.startAfterDocument(_lastSuggestedUserDoc!);
      }

      final usersSnapshot = await query.get();

      if (usersSnapshot.docs.isEmpty) {
        setState(() {
          _hasMoreSuggestions = false;
          _isLoadingSuggestions = false;
          _isLoadingMoreSuggestions = false;
        });
        return;
      }

      // Save cursor for next page
      _lastSuggestedUserDoc = usersSnapshot.docs.last;
      if (usersSnapshot.docs.length < 15) _hasMoreSuggestions = false;

      List<Map<String, dynamic>> candidates = [];

      for (var doc in usersSnapshot.docs) {
        final userId = doc.id;
        final userData = doc.data() as Map<String, dynamic>;

        if (userId == currentUser.uid || followingIds.contains(userId))
          continue;

        int relevanceScore = 0;

        // Mutual follows check
        QuerySnapshot? mutualFollowsQuery;
        if (followingIds.isNotEmpty) {
          mutualFollowsQuery = await _db
              .collection('follows')
              .where('followerId', whereIn: followingIds.take(10).toList())
              .where('followingId', isEqualTo: userId)
              .get();
          relevanceScore += mutualFollowsQuery.docs.length * 10;
        }

        final followerCount = (userData['followerCount'] ?? 0) as int;
        relevanceScore += (followerCount / 10).round();
        if (userData['profile_picture_url'] != null) relevanceScore += 5;

        String? mutualFriendName;
        if (mutualFollowsQuery != null && mutualFollowsQuery.docs.isNotEmpty) {
          final mutualFollowerId = (mutualFollowsQuery.docs.first
              .data() as Map<String, dynamic>)['followerId'];
          final mutualFriendDoc = await _db.collection('users').doc(
              mutualFollowerId).get();
          if (mutualFriendDoc.exists) {
            mutualFriendName = mutualFriendDoc.data()?['name'];
          }
        }

        candidates.add({
          'userId': userId,
          'name': userData['name'] ?? 'Unknown',
          'username': userData['username'] ?? userId,
          'profileUrl': userData['profile_picture_url'] ??
              userData['profile_url'],
          'followerCount': followerCount,
          'mutualFriendName': mutualFriendName,
          'relevanceScore': relevanceScore,
          'isPrivate': userData['private_account'] ?? false,
        });
      }

      candidates.sort((a, b) =>
          b['relevanceScore'].compareTo(a['relevanceScore']));

      setState(() {
        if (loadMore) {
          _suggestedUsers.addAll(candidates);
        } else {
          _suggestedUsers = candidates;
        }
        _isLoadingSuggestions = false;
        _isLoadingMoreSuggestions = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading suggestions: $e');
      setState(() {
        _isLoadingSuggestions = false;
        _isLoadingMoreSuggestions = false;
      });
    }
  }

  void _dismissSuggestionsSection() {
    HapticFeedback.lightImpact();
    setState(() {
      _isSuggestionsVisible = false;
    });
  }

  // ── Avatar helpers ──────────────────────────────────────
  String _getAvatarText(String name, String email) {
    if (name.isNotEmpty) {
      final words = name.trim().split(RegExp(r'\s+'));
      if (words.length >= 2)
        return (words[0][0] + words[words.length - 1][0]).toUpperCase();
      return name.length >= 2 ? name.substring(0, 2).toUpperCase() : name[0]
          .toUpperCase();
    } else if (email.isNotEmpty) {
      final prefix = email.split('@')[0];
      return prefix.length >= 2
          ? prefix.substring(0, 2).toUpperCase()
          : prefix[0].toUpperCase();
    }
    return 'U';
  }

  Color _getAvatarColor(String name, String email) {
    final id = name.isNotEmpty ? name : email.isNotEmpty ? email : 'default';
    final idx = id.hashCode.abs() % _avatarColors.length;
    return Color(
        int.parse(_avatarColors[idx].substring(1), radix: 16) + 0xFF000000);
  }

  // ── Auto-generated cover gradient (Soft Pastel + Consistent hash) ──
  List<Color> _getAutoCoverGradient() {
    final id = _currentUserName.isNotEmpty
        ? _currentUserName
        : _currentUserEmail.isNotEmpty
        ? _currentUserEmail
        : 'default';
    final hash = id.hashCode.abs();

    // Soft pastel gradient pairs — light & airy
    final gradients = [
      [const Color(0xFFF0E0E0), const Color(0xFFE8D0D0)],
      // blush white → dusty rose
      [const Color(0xFFD1C4E9), const Color(0xFFBBBBF5)],
      // periwinkle → soft indigo
      [const Color(0xFFFFE0B2), const Color(0xFFFFF1A0)],
      // light orange → cream yellow
      [const Color(0xFFC9F0D3), const Color(0xFFB2E6C1)],
      // pale green → seafoam
      [const Color(0xFFB5EAD7), const Color(0xFFA3D9B1)],
      // mint → sage
      [const Color(0xFFF9C6C7), const Color(0xFFFAE3C6)],
      // blush pink → peach
      [const Color(0xFFA8D8EA), const Color(0xFFD4A5C9)],
      // sky blue → lavender
      [const Color(0xFFFFD3B6), const Color(0xFFFFC5E3)],
      // apricot → rose
      [const Color(0xFFCBE2F0), const Color(0xFFB8D4E3)],
      // powder blue → steel blue
      [const Color(0xFFE8C1E0), const Color(0xFFD4A8CC)],
      // orchid → mauve
    ];

    return gradients[hash % gradients.length];
  }

  // ── Helpers ─────────────────────────────────────────────
  Future<void> _onRefresh() async {
    setState(() {
      _isRefreshing = true;
    });
    await _loadUserData();
    _loadProfileImageQuick();
    await _loadSuggestedUsers();
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _isRefreshing = false;
    });
  }

  void _copyUsername() {
    final username = _userData['username'] as String;
    final clean = username.startsWith('@') ? username.substring(1) : username;
    Clipboard.setData(ClipboardData(text: '@$clean'));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text('Copied @$clean'),
        ]),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showQrBottomSheet() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          QrBottomSheet(
            uid: currentUser.uid,
            displayName: _userData['name'] as String? ?? '',
            avatarUrl: _profileImageUrl,
          ),
    );
  }

  void _navigateToBioEdit() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            BioEditActivityScreen(
                currentBio: _userData['bio'] as String? ?? ''),
      ),
    );
    if (result != null && result is String) {
      setState(() {
        _userData['bio'] = result;
      });
      HapticFeedback.mediumImpact();
    }
  }

  void _navigateToEditProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    );
    _onRefresh();
  }

// ── Cover Camera Tap → Bottom Sheet ─────────────────────
  void _onCoverCameraTap() {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1F1F1F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Drag handle ──
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A4A4A),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  margin: const EdgeInsets.only(bottom: 18),
                ),

                // ── Upload Photo ──
                _buildBottomSheetOption(
                  ctx: ctx,
                  icon: Icons.photo_library_outlined,
                  label: 'Upload Photo',
                  subtitle: 'Choose from Gallery',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _uploadCoverFromGallery();
                  },
                ),

                const Divider(color: Color(0xFF2C2C2C),
                    height: 1,
                    indent: 24,
                    endIndent: 24),

                // ── Take Photo ──
                _buildBottomSheetOption(
                  ctx: ctx,
                  icon: Icons.camera_alt_outlined,
                  label: 'Take Photo',
                  subtitle: 'Open Camera',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _uploadCoverFromCamera();
                  },
                ),

                const Divider(color: Color(0xFF2C2C2C),
                    height: 1,
                    indent: 24,
                    endIndent: 24),

                // ── Remove Cover ──
                _buildBottomSheetOption(
                  ctx: ctx,
                  icon: Icons.delete_outline,
                  label: 'Remove Cover',
                  subtitle: 'Revert to default gradient',
                  iconColor: const Color(0xFFE53935),
                  labelColor: const Color(0xFFE53935),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _removeCoverImage();
                  },
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

// ✅ FIXED: Upload Cover From Gallery (with delay)
  Future<void> _uploadCoverFromGallery() async {
    debugPrint('📸 Upload from gallery triggered');

    final uploader = CoverImageUploader();

    await Future.delayed(const Duration(milliseconds: 300));

    // ✅ Progress dialog show කරන්න
    _showCoverUploadDialog();

    final success = await uploader.uploadCoverImage(
      context: context,
      source: ImageSource.gallery,
      onSuccess: (coverUrl) {
        debugPrint('✅ Upload success callback received');
        Navigator.pop(context); // Close progress dialog
        setState(() {
          _coverImageUrl = coverUrl;
        });
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('✅ Cover photo updated!'),
            ]),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      },
      onError: (error) {
        debugPrint('❌ Upload error callback: $error');
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $error'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      },
    );

    debugPrint('📊 Upload completed with result: $success');
  }

// ✅ FIXED: Upload Cover From Camera (with delay)

  Future<void> _uploadCoverFromCamera() async {
    debugPrint('📷 Upload from camera triggered');

    final uploader = CoverImageUploader();

    await Future.delayed(const Duration(milliseconds: 300));

    // ✅ Progress dialog show කරන්න
    _showCoverUploadDialog();

    final success = await uploader.uploadCoverImage(
      context: context,
      source: ImageSource.camera,
      onSuccess: (coverUrl) {
        debugPrint('✅ Upload success callback received');
        Navigator.pop(context); // Close progress dialog
        setState(() {
          _coverImageUrl = coverUrl;
        });
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('✅ Cover photo updated!'),
            ]),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      },
      onError: (error) {
        debugPrint('❌ Upload error callback: $error');
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $error'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      },
    );

    debugPrint('📊 Upload completed with result: $success');
  }


  Future<void> _removeCoverImage() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final uploader = CoverImageUploader();
      final success = await uploader.removeCoverImage(currentUser.uid);

      if (success) {
        setState(() {
          _coverImageUrl = null;
        });
        HapticFeedback.mediumImpact();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Cover removed'),
              ]),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.black87,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error removing cover: $e');
    }
  }

  Widget _buildBottomSheetOption({
    required BuildContext ctx,
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
    Color labelColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Icon(icon, color: iconColor, size: 22)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                  )),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF888888),
                  )),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF555555), size: 20),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  int? _calculateAge(String birthday) {
    if (birthday.isEmpty) return null;
    try {
      final parts = birthday.split('-');
      if (parts.length != 3) return null;
      final birthDate = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      final now = DateTime.now();
      int age = now.year - birthDate.year;
      if (now.month < birthDate.month ||
          (now.month == birthDate.month && now.day < birthDate.day)) {
        age--;
      }
      return age >= 0 ? age : null;
    } catch (_) {
      return null;
    }
  }

  Widget _buildProfileTags() {
    final birthday = _userData['birthday'] as String? ?? '';
    final showBirthdayTag = _userData['show_birthday_tag'] as bool? ?? true;
    final showAge = _userData['show_age'] as bool? ?? true;
    final region = _userData['region'] as String? ?? '';

    final int? age = (showBirthdayTag && showAge)
        ? _calculateAge(birthday)
        : null;

    final List<Widget> chips = [];

    if (age != null) {
      chips.add(_buildTagChip(Icons.person_outline, 'Age $age'));
    }
    if (region.isNotEmpty) {
      chips.add(_buildTagChip(Icons.location_on_outlined, region));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(spacing: 8, runSpacing: 6, children: chips),
    );
  }

  Widget _buildTagChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xCCFFFFFF)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xCCFFFFFF),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  BUILD - OPTIMIZED WITH NESTEDSCROLLVIEW
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: RefreshIndicator(
        color: const Color(0xFFFF3B5C),
        backgroundColor: const Color(0xFF1E1E1E),
        onRefresh: _onRefresh,
        child: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: MediaQuery
                    .of(context)
                    .size
                    .width * 0.75,
                floating: false,
                pinned: false,
                backgroundColor: const Color(0xFF1A1A1A),
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildCoverSection(),
                ),
              ),

              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildSocialCards(),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              if (_isSuggestionsVisible && _suggestedUsers.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildSuggestedUsersSection(),
                ),

              SliverToBoxAdapter(
                child: Column(
                  children: const [
                    Divider(color: Color(0xFF2C2C2C), height: 1, indent: 0),
                    SizedBox(height: 4),
                  ],
                ),
              ),

              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyTabBarDelegate(
                  child: _buildTabBar(),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildTabContent(0),
              _buildTabContent(1),
              _buildTabContent(2),
              _buildTabContent(3),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  SUGGESTED FOR YOU SECTION
  // ══════════════════════════════════════════════════════════
  Widget _buildSuggestedUsersSection() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                const Text(
                  'Suggested for you',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _dismissSuggestionsSection,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Color(0xFF888888),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_isLoadingSuggestions)
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 5,
                itemBuilder: (context, index) => _buildShimmerCard(),
              ),
            )
          else
            SizedBox(
              height: 200,
              child: NotificationListener<ScrollNotification>(
                onNotification: (scrollInfo) {
                  // Load more when near end
                  if (scrollInfo.metrics.pixels >=
                      scrollInfo.metrics.maxScrollExtent - 200) {
                    _loadSuggestedUsers(loadMore: true);
                  }
                  return false;
                },
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _suggestedUsers.length +
                      (_isLoadingMoreSuggestions ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _suggestedUsers.length) {
                      // Loading more indicator
                      return Container(
                        width: 80,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(
                          color: Color(0xFFFF3B5C),
                          strokeWidth: 2,
                        ),
                      );
                    }
                    return _buildSuggestedUserCard(
                        _suggestedUsers[index], index);
                  },
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSuggestedUserCard(Map<String, dynamic> user, int index) {
    final name = user['name'] as String;
    final username = user['username'] as String;
    final profileUrl = user['profileUrl'] as String?;
    final followerCount = (user['followerCount'] ?? 0) as int;
    final mutualFriendName = user['mutualFriendName'] as String?;
    final userId = user['userId'] as String;

    return GestureDetector(
      // ✅ Card click → ActivityUserProfile
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ActivityUserProfile(userId: userId),
          ),
        );
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFF3B5C), width: 2),
              ),
              child: ClipOval(
                child: profileUrl != null && profileUrl.isNotEmpty
                    ? CachedNetworkImage(
                  imageUrl: profileUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _buildUserAvatar(name, username),
                  errorWidget: (_, __, ___) => _buildUserAvatar(name, username),
                )
                    : _buildUserAvatar(name, username),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                mutualFriendName != null
                    ? 'Followed by $mutualFriendName'
                    : '${_formatNumber(followerCount)} followers',
                style: const TextStyle(fontSize: 11, color: Color(0xFF666666)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),

            // ✅ Follow button - StreamBuilder (real-time)
            StreamBuilder<DocumentSnapshot>(
              stream: _db
                  .collection('follows')
                  .doc('${_auth.currentUser?.uid}_$userId')
                  .snapshots(),
              builder: (context, snapshot) {
                bool isFollowing = false;
                bool isPending = false;

                if (snapshot.hasData && snapshot.data!.exists) {
                  final status = (snapshot.data!.data()
                  as Map<String, dynamic>?)?['status'] ?? '';
                  isFollowing = status == 'accepted' || status == 'active';
                  isPending = status == 'pending';
                }

                Color buttonColor;
                String buttonText;

                if (isFollowing) {
                  buttonColor = const Color(0xFF2C2C2C);
                  buttonText = 'Following';
                } else if (isPending) {
                  buttonColor = const Color(0xFF666666);
                  buttonText = 'Requested';
                } else {
                  buttonColor = const Color(0xFFFF3B5C);
                  buttonText = 'Follow';
                }

                return GestureDetector(
                  onTap: () =>
                      _handleSuggestedUserFollow(
                        userId: userId,
                        username: name,
                        isFollowing: isFollowing,
                        isPending: isPending,
                        isPrivate: user['isPrivate'] as bool? ?? false,
                      ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 8),
                    decoration: BoxDecoration(
                      color: buttonColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      buttonText,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserAvatar(String name, String email) {
    return Container(
      decoration: BoxDecoration(
        color: _getAvatarColor(name, email),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _getAvatarText(name, email),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  COVER SECTION
  // ══════════════════════════════════════════════════════════
  Widget _buildCoverSection() {
    final double screenW = MediaQuery
        .of(context)
        .size
        .width;
    final double coverH = screenW * 0.72;

    return SizedBox(
      width: screenW,
      height: coverH,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildCoverBackground(screenW, coverH),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: coverH * 0.75,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.30),
                    Colors.black.withOpacity(0.58),
                    Colors.black.withOpacity(0.80),
                    const Color(0xFF1A1A1A),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(top: 0, left: 0, right: 0, child: _buildTopAppBar()),
          // ⚠️ Account Warning Banner
          _buildAccountWarningBanner(),
          Positioned(
            bottom: 0, // -10 → 0
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min, // ✅ already there, keep it
                children: [
                  _buildAvatarAndNameRow(),
                  const SizedBox(height: 12),
                  _buildBioSection(),
                  const SizedBox(height: 3),
                  _buildStatsAndEditRow(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildAccountWarningBanner() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('users').doc(currentUser.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final accountStatus = data['accountStatus'] ?? 'active';
        final strikes = data['strikes'] ?? 0;

        if (accountStatus == 'active' && strikes == 0) return const SizedBox.shrink();

        Color bannerColor;
        IconData bannerIcon;
        String bannerText;

        if (accountStatus == 'banned') {
          bannerColor = const Color(0xFFDC2626);
          bannerIcon = Icons.block;
          bannerText = '💀 ඔබේ ගිණුම ස්ථිරවම අත්හිටුවා ඇත';
        } else if (accountStatus == 'posting_restricted') {
          final banUntil = data['postingBannedUntil'] as int?;
          String countdown = '';
          if (banUntil != null) {
            final remaining = DateTime.fromMillisecondsSinceEpoch(banUntil).difference(DateTime.now());
            if (remaining.isNegative) return const SizedBox.shrink();
            countdown = ' (${remaining.inHours}h remaining)';
          }
          bannerColor = const Color(0xFFEA580C);
          bannerIcon = Icons.pause_circle_outline;
          bannerText = '🚫 Posting restricted$countdown';
        } else if (strikes >= 1) {
          bannerColor = const Color(0xFFD97706);
          bannerIcon = Icons.warning_amber_rounded;
          bannerText = '⚠️ Account Warning: ඔබේ ගිණුම නිරීක්ෂණය වෙමින් පවතී';
        } else {
          return const SizedBox.shrink();
        }

        return Positioned(
          top: MediaQuery.of(context).padding.top + 60,
          left: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bannerColor.withOpacity(0.92),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: bannerColor, width: 1),
            ),
            child: Row(
              children: [
                Icon(bannerIcon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    bannerText,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  Widget _buildCoverBackground(double w, double h) {
    if (_coverImageUrl != null && _coverImageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: _coverImageUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => _coverGradientWithPattern(w, h),
        errorWidget: (_, __, ___) => _coverGradientWithPattern(w, h),
      );
    }
    return _coverGradientWithPattern(w, h);
  }

  Widget _coverGradientWithPattern(double w, double h) {
    final colors = _getAutoCoverGradient();

    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
          ),

          Opacity(
            opacity: 0.18,
            child: CustomPaint(
              painter: _AbstractDotsPainter(
                  seedHash: _currentUserName.isNotEmpty
                      ? _currentUserName.hashCode.abs()
                      : _currentUserEmail.isNotEmpty
                      ? _currentUserEmail.hashCode.abs()
                      : 0),
              child: SizedBox(width: w, height: h),
            ),
          ),

          Center(
            child: Opacity(
              opacity: 0.22,
              child: Icon(
                Icons.landscape_outlined,
                color: Colors.white,
                size: 52,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopAppBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery
          .of(context)
          .padding
          .top + 14, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              debugPrint('➕ Plus button tapped');
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(),
            ),
          ),

          Row(
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ActivitySettingOption(),
                    ),
                  );
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.3), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                      Icons.settings_outlined, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),

              GestureDetector(
                onTap: _showQrBottomSheet,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.3), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),

                  child: const Icon(
                      Icons.qr_code_2_outlined, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  ProfileShareBottomSheet.show(
                    context,
                    profileUserId: _auth.currentUser?.uid ?? '',
                    profileUsername: (_userData['username'] as String? ?? '')
                        .replaceAll('@', ''),
                    profileDisplayName: _userData['name'] as String? ?? '',
                    profileImageUrl: _profileImageUrl,
                  );
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.3), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.share, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarAndNameRow() {
    final username = _userData['username'] as String;
    final cleanId = username.startsWith('@') ? username.substring(1) : username;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildProfileImage(),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _userData['name'] as String,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Color(0xAA000000),
                    offset: Offset(1, 1),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            // ✅ මේක තමයි වෙනස් කළ යුත්තේ - GestureDetector එකක් දාල username එක clickable කරනව
            GestureDetector(
              onTap: _copyUsername,
              child: Row(
                children: [
                  Text(
                    '@$cleanId',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xCCCCCCCC),
                      shadows: [
                        Shadow(
                          color: Color(0xCC000000),
                          offset: Offset(1, 1),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.content_copy,
                    size: 12,
                    color: Color(0xCCCCCCCC),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBioSection() {
    final bio = _userData['bio'] as String? ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _navigateToBioEdit,
          child: Text(
            bio.isEmpty ? 'Tap here to fill in your bio' : bio,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: bio.isEmpty
                  ? const Color(0xAADDDDDD)
                  : const Color(0xDDDDDDDD),
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: _buildProfileTags(),
        ),
      ],
    );
  }

  Widget _buildStatsAndEditRow() {
    final following = _formatNumber((_userData['following'] ?? 0) as int);
    final followers = _formatNumber((_userData['followers'] ?? 0) as int);
    final likes = _formatNumber((_userData['likes'] ?? 0) as int);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildTappableStatItem(following, 'Following', _onFollowingTap),
        const SizedBox(width: 20),
        _buildTappableStatItem(followers, 'Followers', _onFollowersTap),
        const SizedBox(width: 20),
        _buildTappableStatItem(likes, 'Likes', _onLikesTap),
        const Spacer(),
        GestureDetector(
          onTap: _navigateToEditProfile,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.white.withOpacity(0.3), width: 1),
            ),
            child: const Text(
              'Edit profile',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _onCoverCameraTap,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withOpacity(0.3), width: 1),
            ),
            child: const Icon(
                Icons.camera_alt_outlined, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildTappableStatItem(String number, String label,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(right: 4, top: 4, bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              number,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xCCCCCCCC),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── NEW: Followers number tapped ──
  void _onFollowersTap() {
    HapticFeedback.lightImpact();
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FollowListScreen(
              type: 'followers',
              targetUserId: currentUser.uid,
              currentUserId: currentUser.uid,
              db: _db,
              onFollowTap: _handleFollowTap,
            ),
      ),
    );
  }

// ── NEW: Following number tapped ──
  void _onFollowingTap() {
    HapticFeedback.lightImpact();
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FollowListScreen(
              type: 'following',
              targetUserId: currentUser.uid,
              currentUserId: currentUser.uid,
              db: _db,
              onFollowTap: _handleFollowTap,
            ),
      ),
    );
  }

  Future<void> _handleFollowTap(String userId, String username) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid == userId) return;

    HapticFeedback.lightImpact();

    final followDocId = '${currentUser.uid}_$userId';
    final followRef = _db.collection('follows').doc(followDocId);

    try {
      final followDoc = await followRef.get();

      if (followDoc.exists) {
        // Unfollow
        final status = followDoc.data()?['status'];
        await followRef.delete();
        if (status == 'active') {
          await _db.collection('users').doc(currentUser.uid)
              .update({'followingCount': FieldValue.increment(-1)});
          await _db.collection('users').doc(userId)
              .update({'followerCount': FieldValue.increment(-1)});
        }
      } else {
        // Follow
        final targetDoc = await _db.collection('users').doc(userId).get();
        final isPrivate = targetDoc.data()?['private_account'] ?? false;

        final currentUserDoc = await _db.collection('users')
            .doc(currentUser.uid).get();
        final currentName = currentUserDoc.data()?['name'] ?? 'User';

        // ✅ Rules: hasAll(['followerId','followerName','followingId','followingName','status','timestamp'])
        await followRef.set({
          'followerId': currentUser.uid,
          'followerName': currentName,
          'followingId': userId,
          'followingName': username,
          'status': isPrivate ? 'pending' : 'active',
          'timestamp': DateTime
              .now()
              .millisecondsSinceEpoch,
        });

        if (!isPrivate) {
          await _db.collection('users').doc(currentUser.uid)
              .update({'followingCount': FieldValue.increment(1)});
          await _db.collection('users').doc(userId)
              .update({'followerCount': FieldValue.increment(1)});
        }
      }
    } catch (e) {
      debugPrint('❌ Follow error: $e');
    }
  }

  // ── NEW: Likes number tapped ──
  void _onLikesTap() {
    HapticFeedback.lightImpact();
    _showLikesTotalSheet();
  }

  void _showLikesTotalSheet() {
    final likes = _formatNumber((_userData['likes'] ?? 0) as int);
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (_) =>
          Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 36),
            child: _LikesCard(likesText: likes),
          ),
    );
  }


  Widget _buildProfileImage() {
    final heroTag = 'profile_image_${_auth.currentUser?.uid ?? 'current'}';

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        _showProfileImagePreview();
      },
      child: Stack(
        children: [
          Hero(
            tag: heroTag,
            child: Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
              ),
              child: ClipOval(
                child: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                  imageUrl: _profileImageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _buildAvatarPlaceholder(),
                  errorWidget: (_, __, ___) => _buildAvatarPlaceholder(),
                )
                    : _buildAvatarPlaceholder(),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                _navigateToEditProfile();
              },
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC400),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProfileImagePreview() {
    final heroTag = 'profile_image_${_auth.currentUser?.uid ?? 'current'}';

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              fit: StackFit.expand,
              children: [
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    color: Colors.black.withOpacity(0.7),
                  ),
                ),
                Center(
                  child: Hero(
                    tag: heroTag,
                    child: Container(
                      width: MediaQuery
                          .of(context)
                          .size
                          .width * 0.85,
                      height: MediaQuery
                          .of(context)
                          .size
                          .width * 0.85,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _profileImageUrl != null &&
                            _profileImageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                          imageUrl: _profileImageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _buildAvatarPlaceholder(),
                          errorWidget: (_, __, ___) =>
                              _buildAvatarPlaceholder(),
                        )
                            : _buildAvatarPlaceholder(),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: MediaQuery
                      .of(context)
                      .padding
                      .top + 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatarPlaceholder() {
    return Container(
      decoration: BoxDecoration(
          color: _getAvatarColor(_currentUserName, _currentUserEmail),
          shape: BoxShape.circle),
      child: Center(
        child: Text(
          _getAvatarText(_currentUserName, _currentUserEmail),
          style: const TextStyle(
              fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  SOCIAL CARDS
  // ══════════════════════════════════════════════════════════
  Widget _buildSocialCards() {
    return Row(
      children: [
        Expanded(child: _buildSocialCard(
          title: 'History',
          subtitle: 'Your activity log',
          accentColor: const Color(0xFFFFFFFF),
          icon: Icons.history,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => const SocialCardsTabs(initialTab: 0),
            ));
          },
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildSocialCard(
          title: 'Contact',
          subtitle: 'Connect with people',
          accentColor: const Color(0xFFFFFFFF),
          icon: Icons.people_alt_rounded,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => const SocialCardsTabs(initialTab: 1),
            ));
          },
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildSocialCard(
          title: 'Drafts',
          subtitle: 'Unfinished vibes',
          accentColor: const Color(0xFFFFFFFF),
          icon: Icons.pending_actions_rounded,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => const SocialCardsTabs(initialTab: 2),
            ));
          },
        )),
      ],
    );
  }

  Widget _buildSocialCard({
    required String title,
    required String subtitle,
    required Color accentColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(5),
          border: Border(
            top: BorderSide(color: accentColor, width: 2.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accentColor, size: 20),
                const Spacer(),
                const Icon(
                    Icons.chevron_right, color: Color(0xFF666666), size: 18),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              title,
              style: const TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: Color(0xFF888888)),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  TAB BAR - OPTIMIZED
  // ══════════════════════════════════════════════════════════
  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          ...List.generate(_tabs.length, (index) {
            final bool active = _activeTab == index;
            final String label = _tabs[index]['label'] as String;
            final bool showLock = (index == 2);

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  _tabController.animateTo(index);
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (showLock)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(Icons.lock_outline, size: 14,
                                color: active ? Colors.white : const Color(
                                    0xFF666666)),
                          ),
                        Text(label, style: TextStyle(
                          fontSize: 16,
                          fontWeight: active ? FontWeight.w700 : FontWeight
                              .w400,
                          color: active ? Colors.white : const Color(
                              0xFF666666),
                        )),
                      ],
                    ),
                    if (active)
                      Container(
                        height: 3, width: 30,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      )
                    else
                      const SizedBox(height: 9),
                  ],
                ),
              ),
            );
          }),
          GestureDetector(
            onTap: () {
              debugPrint('🔍 Search tapped');
            },
            child: const Icon(
                Icons.search_outlined, color: Color(0xFF666666), size: 22),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  TAB CONTENT - LAZY LOADING
  // ══════════════════════════════════════════════════════════
  Widget _buildTabContent(int index) {
    switch (index) {
      case 0:
        return const UserTabMedia();
      case 1:
        return const TabPrivatePage();
      case 2:
        return UserThoughtsTab(
          userId: _auth.currentUser?.uid ?? '',
          isOwner: true, // owner always sees all posts incl. anonymous
        );

      case 3:
        return const TabSavedPage();
      default:
        return const SizedBox.shrink();
    }
  }

  void _showCoverUploadDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => const _CoverUploadProgressDialog(),
    );
  }

  Widget _buildShimmerCard() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return AnimatedBuilder(
          animation: AlwaysStoppedAnimation(value),
          builder: (context, _) {
            return Container(
              width: 160,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  // Shimmer sweep
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.03),
                            Colors.white.withOpacity(0.10 * value),
                            Colors.white.withOpacity(0.03),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  // Content placeholders
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      // Avatar placeholder
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.08),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Name placeholder
                      Container(
                        width: 90,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Subtitle placeholder
                      Container(
                        width: 60,
                        height: 9,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Button placeholder
                      Container(
                        width: 80,
                        height: 30,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B5C).withOpacity(0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
      onEnd: () => setState(() {}), // restart animation loop
    );
  }

  Future<void> _handleSuggestedUserFollow({
    required String userId,
    required String username,
    required bool isFollowing,
    required bool isPending,
    required bool isPrivate,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    HapticFeedback.lightImpact();
    final followDocId = '${currentUser.uid}_$userId';
    final followRef = _db.collection('follows').doc(followDocId);

    try {
      if (isFollowing || isPending) {
        // Unfollow / cancel request
        await followRef.delete();
        if (isFollowing) {
          await _db.collection('users').doc(currentUser.uid).update({
            'followingCount': FieldValue.increment(-1),
          });
          await _db.collection('users').doc(userId).update({
            'followerCount': FieldValue.increment(-1),
          });
        }
        debugPrint('✅ Unfollowed: $userId');
      } else {
        // Follow
        final currentUserDoc = await _db.collection('users').doc(
            currentUser.uid).get();
        final currentUsername = currentUserDoc.data()?['name'] ?? 'User';

        await followRef.set({
          'followerId': currentUser.uid,
          'followerName': currentUsername,
          'followingId': userId,
          'followingName': username,
          'status': isPrivate ? 'pending' : 'active',
          'timestamp': DateTime
              .now()
              .millisecondsSinceEpoch,
        });

        if (!isPrivate) {
          await _db.collection('users').doc(currentUser.uid).update({
            'followingCount': FieldValue.increment(1),
          });
          await _db.collection('users').doc(userId).update({
            'followerCount': FieldValue.increment(1),
          });
          debugPrint('✅ Followed: $userId');
        } else {
          debugPrint('⏳ Follow request sent: $userId');
        }
      }
    } catch (e) {
      debugPrint('❌ Follow error: $e');
    }
  }


}

class _CoverUploadProgressDialog extends StatefulWidget {
  const _CoverUploadProgressDialog();

  @override
  State<_CoverUploadProgressDialog> createState() =>
      _CoverUploadProgressDialogState();
}

class _CoverUploadProgressDialogState
    extends State<_CoverUploadProgressDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;

  final List<String> _steps = [
    'Preparing image...',
    'Compressing...',
    'Uploading to server...',
    'Almost done...',
  ];

  int _stepIndex = 0;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    // Cycle through step labels so user sees progress
    _startStepCycle();
  }

  void _startStepCycle() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _stepIndex = 1);

      Future.delayed(const Duration(seconds: 5), () {
        if (!mounted) return;
        setState(() => _stepIndex = 2);

        Future.delayed(const Duration(seconds: 10), () {
          if (!mounted) return;
          setState(() => _stepIndex = 3);
        });
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeIn,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 48),
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Animated ring ──────────────────────
              const SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  color: Color(0xFFFF3B5C),
                  strokeWidth: 3.5,
                ),
              ),

              const SizedBox(height: 24),

              // ── Title ──────────────────────────────
              const Text(
                'Uploading Cover Photo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 10),

              // ── Step label ─────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _steps[_stepIndex],
                  key: ValueKey(_stepIndex),
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 13,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Thin progress bar ──────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  backgroundColor: const Color(0xFF2C2C2C),
                  color: const Color(0xFFFF3B5C),
                  minHeight: 4,
                ),
              ),

              const SizedBox(height: 16),

              // ── Hint ───────────────────────────────
              const Text(
                'Please wait, don\'t close the app',
                style: TextStyle(
                  color: Color(0xFF555555),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ══════════════════════════════════════════════════════════
//  STICKY TAB BAR DELEGATE
// ══════════════════════════════════════════════════════════
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyTabBarDelegate({required this.child});

  @override
  double get minExtent => 60;

  @override
  double get maxExtent => 60;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return false;
  }
}
class _LikesCard extends StatelessWidget {
  final String likesText;
  const _LikesCard({required this.likesText});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // love.png image — Icons.favorite fallback දෙනවා asset නැත්නම්
          Image.asset(
            'assets/images/love.png',
            width: 72,
            height: 72,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.favorite,
              color: Color(0xFFFF3B5C),
              size: 72,
            ),
          ),

          const SizedBox(height: 20),

          Text(
            likesText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Total Likes',
            style: TextStyle(
              color: Color(0xFF888888),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            'Combined across all posts',
            style: TextStyle(color: Color(0xFF555555), fontSize: 13),
          ),

          const SizedBox(height: 24),

          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Close',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  ABSTRACT DOTS PATTERN PAINTER
// ══════════════════════════════════════════════════════════
class _AbstractDotsPainter extends CustomPainter {
  final int seedHash;
  _AbstractDotsPainter({required this.seedHash});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;

    int seed = seedHash;
    double next() {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
      return seed / 0x7FFFFFFF;
    }

    paint.color = Colors.white.withOpacity(0.25);
    for (int i = 0; i < 5; i++) {
      final cx = next() * size.width;
      final cy = next() * size.height;
      final r  = 30.0 + next() * 60.0;
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }

    paint.color = Colors.white.withOpacity(0.45);
    for (int i = 0; i < 12; i++) {
      final cx = next() * size.width;
      final cy = next() * size.height;
      final r  = 3.0 + next() * 5.0;
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }

    paint.color = Colors.white.withOpacity(0.6);
    for (int i = 0; i < 18; i++) {
      final cx = next() * size.width;
      final cy = next() * size.height;
      final r  = 1.0 + next() * 2.5;
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }

    paint
      ..color = Colors.white.withOpacity(0.12)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 6; i++) {
      final x1 = next() * size.width;
      final y1 = next() * size.height;
      final x2 = next() * size.width;
      final y2 = next() * size.height;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AbstractDotsPainter oldDelegate) {
    return oldDelegate.seedHash != seedHash;
  }

}
class _ProfileTag {
  final IconData icon;
  final String label;
  const _ProfileTag({required this.icon, required this.label});
}
