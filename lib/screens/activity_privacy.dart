import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
class ActivityPrivacy extends StatefulWidget {
  const ActivityPrivacy({Key? key}) : super(key: key);

  @override
  State<ActivityPrivacy> createState() => _ActivityPrivacyState();
}

class _ActivityPrivacyState extends State<ActivityPrivacy> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _currentUserId;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _showProgress = false;

  // Privacy settings
  bool _privateAccount = false;
  bool _hideLocation = true;
  bool _hideEmail = true;
  bool _showLikedPosts = true;
  bool _showReposts = true;

  // ═══════════════════════════════════════════════════════════
  // 🆕 NEW: Followers / Following visibility settings
  // 'everyone' or 'only_me'
  // ═══════════════════════════════════════════════════════════
  String _followersVisibility = 'everyone';
  String _followingVisibility = 'everyone';

// ═══════════════════════════════════════════════════════════
// 🆕 NEARBY VIBES SETTINGS
// ═══════════════════════════════════════════════════════════
  bool _enableNearbyVibes = true;
  bool _locationPermissionActive = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeUser();
    _setupScrollListener();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeUser() {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      _currentUserId = currentUser.uid;
      _loadCurrentPrivacySettings();
    } else {
      _showError('Please log in to access privacy settings');
      Navigator.pop(context);
    }
  }

  void _setupScrollListener() {
    double previousOffset = 0;
    _scrollController.addListener(() {
      final currentOffset = _scrollController.offset;
      final delta = currentOffset - previousOffset;

      if (delta > 10 && !_showProgress) {
        setState(() => _showProgress = true);
      } else if (delta < -10 && _showProgress) {
        setState(() => _showProgress = false);
      }

      if (currentOffset == 0 ||
          currentOffset >= _scrollController.position.maxScrollExtent) {
        setState(() => _showProgress = false);
      }

      previousOffset = currentOffset;
    });
  }

  Future<void> _loadCurrentPrivacySettings() async {
    if (_currentUserId == null) return;

    try {
      final doc = await _db.collection('users').doc(_currentUserId).get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _privateAccount = data['private_account'] ?? false;
          _hideLocation = data['hide_location'] ?? true;
          _hideEmail = true; // Always true for security
          _showLikedPosts = data['show_liked_posts'] ?? true;
          _showReposts = data['show_reposts'] ?? true;
          // 🆕 NEW: Load followers/following visibility
          _followersVisibility = data['followers_visibility'] ?? 'everyone';
          _followingVisibility = data['following_visibility'] ?? 'everyone';
          _enableNearbyVibes = data['enable_nearby_vibes'] ?? true;
          _isLoading = false;
        });

        debugPrint('✅ Privacy settings loaded:');
        debugPrint('  - Private Account: $_privateAccount');
        debugPrint('  - Hide Location: $_hideLocation');
        debugPrint('  - Hide Email: $_hideEmail');
        debugPrint('  - Show Liked Posts: $_showLikedPosts');
        debugPrint('  - Show Reposts: $_showReposts');
        debugPrint('  - Followers Visibility: $_followersVisibility');
        debugPrint('  - Following Visibility: $_followingVisibility');
      } else {
        debugPrint('⚠️ User document does not exist, creating defaults');
        await _createDefaultPrivacySettings();
      }
    } catch (e) {
      debugPrint('❌ Failed to load privacy settings: $e');
      _showError('Failed to load privacy settings');
      setState(() {
        _privateAccount = false;
        _hideLocation = true;
        _hideEmail = true;
        _showLikedPosts = true;
        _showReposts = true;
        _followersVisibility = 'everyone';
        _followingVisibility = 'everyone';
        _isLoading = false;
      });
    }
  }

  Future<void> _createDefaultPrivacySettings() async {
    if (_currentUserId == null) return;

    try {
      await _db.collection('users').doc(_currentUserId).set({
        'private_account': false,
        'hide_location': true,
        'hide_email': true,
        'show_liked_posts': true,
        'show_reposts': true,
        // 🆕 NEW: Default visibility settings
        'followers_visibility': 'everyone',
        'following_visibility': 'everyone',
        'enable_nearby_vibes': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        _privateAccount = false;
        _hideLocation = true;
        _hideEmail = true;
        _showLikedPosts = true;
        _showReposts = true;
        _followersVisibility = 'everyone';
        _followingVisibility = 'everyone';
        _isLoading = false;
      });

      debugPrint('✅ Default privacy settings created');
    } catch (e) {
      debugPrint('❌ Failed to create default settings: $e');
      setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🆕 TIKTOK-STYLE BOTTOM SHEET CONFIRMATION
  // ═══════════════════════════════════════════════════════════

  Future<void> _showPrivacyConfirmationSheet(bool newValue) async {
    HapticFeedback.mediumImpact();

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1F1F1F),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A4A4A),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    margin: const EdgeInsets.only(bottom: 24),
                  ),

                  // Icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: newValue
                          ? const Color(0xFFFF3B5C).withOpacity(0.1)
                          : const Color(0xFF4CAF50).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      newValue ? Icons.lock_outline : Icons.public_outlined,
                      color: newValue ? const Color(0xFFFF3B5C) : const Color(
                          0xFF4CAF50),
                      size: 32,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Title
                  Text(
                    newValue
                        ? 'Switch to Private Account?'
                        : 'Switch to Public Account?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  // Description
                  Text(
                    newValue
                        ? 'Only people you approve will be able to see your posts, followers, and following lists. Your existing followers won\'t be removed.'
                        : 'Anyone can see your public posts and follow you without approval. Pending follow requests will be automatically approved.',
                    style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 15,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 28),

                  // Confirm Button
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context, true);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: newValue ? const Color(0xFFFF3B5C) : const Color(
                            0xFF4CAF50),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        newValue ? 'Switch to Private' : 'Switch to Public',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Cancel Button
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context, false);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    // User confirmed the change
    if (result == true) {
      await _updatePrivateAccountSetting(newValue);
    } else {
      // User cancelled - revert the switch state
      setState(() {
        _privateAccount = !newValue;
      });
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🆕 UPDATE PRIVATE ACCOUNT SETTING WITH PENDING REQUEST HANDLING
  // ═══════════════════════════════════════════════════════════
  Future<void> _updatePrivateAccountSetting(bool isPrivate) async {
    if (_currentUserId == null) return;

    debugPrint('=== Updating Private Account Setting ===');
    debugPrint('User ID: $_currentUserId');
    debugPrint('Private Account: $isPrivate');

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
        const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFF3B5C),
          ),
        ),
      );

      // Update user's privacy setting
      await _db.collection('users').doc(_currentUserId).update({
        'private_account': isPrivate,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // ═══════════════════════════════════════════════════════════
      // 🔥 CRITICAL: Handle pending follow requests when turning OFF privacy
      // ═══════════════════════════════════════════════════════════
      if (!isPrivate) {
        debugPrint(
            '🔓 Account turned public - Auto-approving pending requests...');

        // Get all pending follow requests
        final pendingRequests = await _db
            .collection('follows')
            .where('followingId', isEqualTo: _currentUserId)
            .where('status', isEqualTo: 'pending')
            .get();

        debugPrint('📋 Found ${pendingRequests.docs.length} pending requests');

        // Batch update all pending requests to 'active'
        final batch = _db.batch();

        for (var doc in pendingRequests.docs) {
          batch.update(doc.reference, {
            'status': 'active',
            'approvedAt': DateTime
                .now()
                .millisecondsSinceEpoch,
          });

          // Update counters for both users
          final followerId = doc.data()['followerId'];

          // Increment follower count for current user
          batch.update(
            _db.collection('users').doc(_currentUserId),
            {'followerCount': FieldValue.increment(1)},
          );

          // Increment following count for follower
          batch.update(
            _db.collection('users').doc(followerId),
            {'followingCount': FieldValue.increment(1)},
          );
        }

        await batch.commit();
        debugPrint('✅ All pending requests auto-approved');
      }

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      setState(() => _privateAccount = isPrivate);

      final message = isPrivate
          ? '🔒 Account is now private. Only approved followers can see your content.'
          : '🌍 Account is now public. Anyone can see your public posts.';

      _showSuccess(message);
      debugPrint('✅ Private account setting updated successfully');
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      debugPrint('❌ Failed to update private account: $e');
      setState(() => _privateAccount = !isPrivate);
      _showError('Failed to update privacy setting. Please try again.');
    }
  }

  Future<void> _updateLocationPrivacySetting(bool hideLocation) async {
    if (_currentUserId == null) return;

    debugPrint('=== Updating Location Privacy Setting ===');
    debugPrint('User ID: $_currentUserId');
    debugPrint('Hide Location: $hideLocation');

    // Haptic feedback
    HapticFeedback.mediumImpact();

    try {
      await _db.collection('users').doc(_currentUserId).update({
        'hide_location': hideLocation,
        'updated_at': FieldValue.serverTimestamp(),
      });

      setState(() => _hideLocation = hideLocation);

      final message = hideLocation
          ? '🛡️ Location privacy enabled. Your location is now hidden.'
          : '📍 Location privacy disabled. Your location may be visible.';

      _showSuccess(message);
      debugPrint('✅ Location privacy setting updated successfully');
    } catch (e) {
      debugPrint('❌ Failed to update location setting: $e');
      setState(() => _hideLocation = !hideLocation);
      _showError('Failed to update location setting. Please try again.');
    }
  }

  Future<void> _updateShowLikedPostsSetting(bool showLikedPosts) async {
    if (_currentUserId == null) return;

    debugPrint('=== Updating Show Liked Posts Setting ===');
    debugPrint('User ID: $_currentUserId');
    debugPrint('Show Liked Posts: $showLikedPosts');

    // Haptic feedback
    HapticFeedback.mediumImpact();

    try {
      await _db.collection('users').doc(_currentUserId).update({
        'show_liked_posts': showLikedPosts,
        'updated_at': FieldValue.serverTimestamp(),
      });

      setState(() => _showLikedPosts = showLikedPosts);

      final message = showLikedPosts
          ? '✅ Liked posts are now visible on your profile.'
          : '🔒 Liked posts are now hidden from your profile.';

      _showSuccess(message);
      debugPrint('✅ Show liked posts setting updated successfully');
    } catch (e) {
      debugPrint('❌ Failed to update show liked posts setting: $e');
      setState(() => _showLikedPosts = !showLikedPosts);
      _showError('Failed to update setting. Please try again.');
    }
  }

  Future<void> _updateShowRepostsSetting(bool showReposts) async {
    if (_currentUserId == null) return;

    debugPrint('=== Updating Show Reposts Setting ===');
    debugPrint('User ID: $_currentUserId');
    debugPrint('Show Reposts: $showReposts');

    // Haptic feedback
    HapticFeedback.mediumImpact();

    try {
      await _db.collection('users').doc(_currentUserId).update({
        'show_reposts': showReposts,
        'updated_at': FieldValue.serverTimestamp(),
      });

      setState(() => _showReposts = showReposts);

      final message = showReposts
          ? '✅ Reposts are now visible on your profile.'
          : '🔒 Reposts are now hidden from your profile.';

      _showSuccess(message);
      debugPrint('✅ Show reposts setting updated successfully');
    } catch (e) {
      debugPrint('❌ Failed to update show reposts setting: $e');
      setState(() => _showReposts = !showReposts);
      _showError('Failed to update setting. Please try again.');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🆕 NEW: Update Followers Visibility Setting
  // ═══════════════════════════════════════════════════════════
  Future<void> _updateFollowersVisibility(String visibility) async {
    if (_currentUserId == null) return;

    debugPrint('=== Updating Followers Visibility Setting ===');
    debugPrint('User ID: $_currentUserId');
    debugPrint('Followers Visibility: $visibility');

    HapticFeedback.mediumImpact();

    final previousValue = _followersVisibility;
    setState(() => _followersVisibility = visibility);

    try {
      await _db.collection('users').doc(_currentUserId).update({
        'followers_visibility': visibility,
        'updated_at': FieldValue.serverTimestamp(),
      });

      final message = visibility == 'everyone'
          ? '👥 Followers list is now visible to everyone.'
          : '🔒 Followers list is now visible only to you.';

      _showSuccess(message);
      debugPrint('✅ Followers visibility updated successfully');
    } catch (e) {
      debugPrint('❌ Failed to update followers visibility: $e');
      setState(() => _followersVisibility = previousValue);
      _showError('Failed to update setting. Please try again.');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🆕 NEW: Update Following Visibility Setting
  // ═══════════════════════════════════════════════════════════
  Future<void> _updateFollowingVisibility(String visibility) async {
    if (_currentUserId == null) return;

    debugPrint('=== Updating Following Visibility Setting ===');
    debugPrint('User ID: $_currentUserId');
    debugPrint('Following Visibility: $visibility');

    HapticFeedback.mediumImpact();

    final previousValue = _followingVisibility;
    setState(() => _followingVisibility = visibility);

    try {
      await _db.collection('users').doc(_currentUserId).update({
        'following_visibility': visibility,
        'updated_at': FieldValue.serverTimestamp(),
      });

      final message = visibility == 'everyone'
          ? '👥 Following list is now visible to everyone.'
          : '🔒 Following list is now visible only to you.';

      _showSuccess(message);
      debugPrint('✅ Following visibility updated successfully');
    } catch (e) {
      debugPrint('❌ Failed to update following visibility: $e');
      setState(() => _followingVisibility = previousValue);
      _showError('Failed to update setting. Please try again.');
    }
  }

// ═══════════════════════════════════════════════════════════
// 🆕 NEARBY VIBES: Check Location Permission
// ═══════════════════════════════════════════════════════════
  Future<void> _checkLocationPermission() async {
    final status = await Permission.location.status;
    setState(() {
      _locationPermissionActive = status.isGranted;
    });
  }

// ═══════════════════════════════════════════════════════════
// 🆕 NEARBY VIBES: Update Setting
// ═══════════════════════════════════════════════════════════
  Future<void> _updateNearbyVibesSetting(bool enabled) async {
    if (_currentUserId == null) return;

    HapticFeedback.mediumImpact();

    if (enabled && !_locationPermissionActive) {
      final status = await Permission.location.request();
      if (!status.isGranted) {
        _showError('📍 Location permission is required for Nearby Vibes.');
        return;
      }
      setState(() => _locationPermissionActive = true);
    }

    final previousValue = _enableNearbyVibes;
    setState(() => _enableNearbyVibes = enabled);

    try {
      await _db.collection('users').doc(_currentUserId).update({
        'enable_nearby_vibes': enabled,
        'updated_at': FieldValue.serverTimestamp(),
      });

      final message = enabled
          ? '📍 Nearby Vibes enabled! Discover posts near you.'
          : '🔒 Nearby Vibes disabled.';
      _showSuccess(message);
    } catch (e) {
      debugPrint('❌ Failed to update Nearby Vibes setting: $e');
      setState(() => _enableNearbyVibes = previousValue);
      _showError('Failed to update setting. Please try again.');
    }
  }

  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    await Future.delayed(const Duration(seconds: 1));
    await _loadCurrentPrivacySettings();
    setState(() => _isRefreshing = false);
    _showSuccess('Privacy settings refreshed');
  }

  void _showError(String message) {
    if (!mounted) return;
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Could not show error snackbar: $e');
    }
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Could not show success snackbar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: StreamBuilder<ConnectivityResult>(
        stream: Connectivity().onConnectivityChanged.map((e) => e.first).asyncMap((e) async => e),
        builder: (context, snapshot) {
          // Connection check
          final hasConnection = snapshot.hasData &&
              snapshot.data != ConnectivityResult.none;

          return Stack(
            children: [
              Column(
                children: [
                  _buildAppBar(),
                  if (_showProgress) _buildProgressBar(),
                  Expanded(
                    child: _isLoading
                        ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF3B5C),
                      ),
                    )
                        : RefreshIndicator(
                      onRefresh: _onRefresh,
                      color: const Color(0xFFFF3B5C),
                      backgroundColor: Colors.black54,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader('Account Privacy'),
                              _buildPrivacyCard(),
                              _buildSectionHeader('List Visibility'),
                              _buildVisibilityCard(),
                              _buildSectionHeader('Nearby Vibes'),
                              _buildNearbyVibesCard(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // ── No Connection Overlay ──
              if (!hasConnection)
                Positioned.fill(
                  child: Container(
                    color: const Color(0xFF1A1A1A).withOpacity(0.95),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C2C2C),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.wifi_off_rounded,
                            color: Color(0xFF888888),
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No Internet Connection',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Privacy settings require an active\nconnection to sync securely.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF888888),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(
                    Icons.arrow_back, size: 24, color: Colors.white),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
                padding: const EdgeInsets.all(4),
              ),
              const SizedBox(width: 8),
              const Text(
                'Privacy Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return const LinearProgressIndicator(
      minHeight: 3,
      backgroundColor: Colors.transparent,
      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF3B5C)),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF888888),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPrivacyCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildPrivacySwitch(
            title: 'Private Account',
            subtitle: '🔒 Only approved followers can see your content',
            value: _privateAccount,
            onChanged: (newValue) {
              // First update UI immediately for smooth animation
              setState(() => _privateAccount = newValue);
              // Then show confirmation sheet
              _showPrivacyConfirmationSheet(newValue);
            },
          ),
          _buildDivider(),
          _buildPrivacySwitch(
            title: 'Hide Location',
            subtitle: '🛡️ Prevent others from seeing your location',
            value: _hideLocation,
            onChanged: _updateLocationPrivacySetting,
          ),
          _buildDivider(),
          _buildPrivacySwitch(
            title: 'Hide Email',
            subtitle: '🔒 Your email is private and protected.\nOnly you can see it after logging in. This feature is enabled automatically for your safety.',
            value: _hideEmail,
            onChanged: (value) {
              if (!value) {
                setState(() => _hideEmail = true);
                _showError(
                    'Email privacy cannot be disabled for security reasons');
              }
            },
          ),
          _buildDivider(),
          _buildPrivacySwitch(
            title: 'Show Liked Posts',
            subtitle: '❤️ Control who can see the posts you\'ve liked on your profile',
            value: _showLikedPosts,
            onChanged: _updateShowLikedPostsSetting,
          ),
          _buildDivider(),
          _buildPrivacySwitch(
            title: 'Show Reposts',
            subtitle: '🔄 Control who can see the posts you\'ve reposted on your profile',
            value: _showReposts,
            onChanged: _updateShowRepostsSetting,
            isLast: true,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🆕 NEW: Visibility Card with Followers & Following rows
  // ═══════════════════════════════════════════════════════════
  Widget _buildVisibilityCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildVisibilityRow(
            icon: Icons.people_outline,
            title: 'Followers List',
            subtitle: 'Who can see your followers?',
            currentValue: _followersVisibility,
            onChanged: _updateFollowersVisibility,
          ),
          _buildDivider(),
          _buildVisibilityRow(
            icon: Icons.person_add_alt_1_outlined,
            title: 'Following List',
            subtitle: 'Who can see who you follow?',
            currentValue: _followingVisibility,
            onChanged: _updateFollowingVisibility,
            isLast: true,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🆕 NEW: Single visibility row with "Everyone" / "Only Me" buttons
  // ═══════════════════════════════════════════════════════════
  Widget _buildVisibilityRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String currentValue,
    required ValueChanged<String> onChanged,
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Icon(icon, color: const Color(0xFF888888), size: 20),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Toggle Buttons Row
          Row(
            children: [
              Expanded(
                child: _buildVisibilityButton(
                  label: 'Everyone',
                  icon: Icons.public,
                  isSelected: currentValue == 'everyone',
                  onTap: () => onChanged('everyone'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildVisibilityButton(
                  label: 'Only Me',
                  icon: Icons.lock_outline,
                  isSelected: currentValue == 'only_me',
                  onTap: () => onChanged('only_me'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🆕 NEW: Individual option button (Everyone / Only Me)
  // ═══════════════════════════════════════════════════════════
  Widget _buildVisibilityButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF3B5C).withOpacity(0.15)
              : const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF3B5C)
                : const Color(0xFF3A3A3A),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? const Color(0xFFFF3B5C)
                  : const Color(0xFF888888),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFFFF3B5C)
                    : const Color(0xFF888888),
                fontSize: 14,
                fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 iOS-STYLE ANIMATED SWITCH (from bottom_sheet_more_options.dart)
  // ═══════════════════════════════════════════════════════════
  Widget _buildPrivacySwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 14,
                    height: 1.4,
                  ),
                  maxLines: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // 🎨 iOS-Style Animated Switch
          GestureDetector(
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 52,
              height: 32,
              decoration: BoxDecoration(
                color: value ? const Color(0xFFFF3B5C) : const Color(
                    0xFF3A3A3A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 1,
      color: const Color(0xFF2C2C2C),
    );
  }

// ═══════════════════════════════════════════════════════════
// 🆕 NEARBY VIBES CARD
// ═══════════════════════════════════════════════════════════
  Widget _buildNearbyVibesCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildPrivacySwitch(
            title: 'Enable Nearby Vibes',
            subtitle:
            '📍 See text posts from people near your location. Toggle off to browse without sharing your presence.',
            value: _enableNearbyVibes,
            onChanged: _updateNearbyVibesSetting,
          ),
          _buildDivider(),
          _buildLocationPermissionStatus(),
        ],
      ),
    );
  }

// ═══════════════════════════════════════════════════════════
// 🆕 LOCATION PERMISSION STATUS ROW
// ═══════════════════════════════════════════════════════════
  Widget _buildLocationPermissionStatus() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _locationPermissionActive
                  ? const Color(0xFF4CAF50).withOpacity(0.12)
                  : const Color(0xFFFF3B5C).withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _locationPermissionActive
                  ? Icons.location_on_rounded
                  : Icons.location_off_rounded,
              size: 18,
              color: _locationPermissionActive
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFFF3B5C),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Location Permission',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _locationPermissionActive
                      ? 'Active — Location access granted'
                      : 'Inactive — Tap to enable in settings',
                  style: TextStyle(
                    color: _locationPermissionActive
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFF888888),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (!_locationPermissionActive)
            GestureDetector(
              onTap: () async {
                HapticFeedback.lightImpact();
                await openAppSettings();
                await Future.delayed(const Duration(milliseconds: 500));
                _checkLocationPermission();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B5C).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFFF3B5C).withOpacity(0.4),
                  ),
                ),
                child: const Text(
                  'Enable',
                  style: TextStyle(
                    color: Color(0xFFFF3B5C),
                    fontSize: 13,
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