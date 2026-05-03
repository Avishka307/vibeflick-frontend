import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;
import 'package:my_vibe_flick/screens/user_options_bottom_sheet.dart';
import 'package:my_vibe_flick/screens/user_tab_likes.dart';
import 'package:shimmer/shimmer.dart';  // 🆕 ADDED: Shimmer package


import 'follow_list_screen.dart';
import 'user_tab_repost_page.dart';
import 'user_tab_media.dart';
import 'chat_screen.dart';  // 🆕 Add this import
import '../Thought/user_thoughts_tab.dart'; // adjust path
class ActivityUserProfile extends StatefulWidget {
  final String? userId;

  const ActivityUserProfile({Key? key, this.userId}) : super(key: key);

  @override
  State<ActivityUserProfile> createState() => _ActivityUserProfileState();
}

class _ActivityUserProfileState extends State<ActivityUserProfile>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late TabController _tabController;
  int _activeTab = 0;

  String? _currentUserId;
  String? _cachedTargetName;
  String? _cachedTargetUsername;
  String? _cachedTargetAvatarUrl;
// 🆕 Privacy settings from target user
  bool _showLikedPostsEnabled = true;
  bool _showRepostsEnabled = true;
  bool _isLoadingPrivacy = true;
  bool _enableNearbyVibes = false;
  bool _isBlockedUser = false; // 🆕
// 🆕 Dynamic tabs based on privacy settings

  List<Map<String, dynamic>> _visibleTabs = [];

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid;

    // 🆕 Load privacy settings first, then initialize tabs
    _loadPrivacySettings();
    // 🆕 Block status check
    _checkIfBlocked();

    debugPrint(
        '🔍 ActivityUserProfile initialized for userId: ${widget.userId}');
    debugPrint('👤 Current logged-in user: $_currentUserId');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

// ═══════════════════════════════════════════════════════════
// 🆕 ADD THESE METHODS TO activity_user_profile.dart
// Location: Inside _ActivityUserProfileState class
// ═══════════════════════════════════════════════════════════

  /// Handle follow/unfollow with privacy check and real-time updates
// ═══════════════════════════════════════════════════════════
// 🆕 REPLACE THIS METHOD IN activity_user_profile.dart
// Location: Inside _ActivityUserProfileState class
// ═══════════════════════════════════════════════════════════

  /// Handle follow/unfollow with privacy check and real-time updates WITH FCM
  Future<void> _handleFollowToggle(String targetUserId,
      String targetUsername) async {
    if (_currentUserId == null || _currentUserId == targetUserId) {
      return;
    }

    try {
      final followDocId = '${_currentUserId}_$targetUserId';
      final followRef = _db.collection('follows').doc(followDocId);
      final followDoc = await followRef.get();

      if (followDoc.exists) {
        // ═══════════════ UNFOLLOW ═══════════════
        final currentStatus = followDoc.data()?['status'];

        debugPrint(
            '💔 Unfollowing user: $targetUserId (Current status: $currentStatus)');

        await followRef.delete();

        // Only decrement counters if the follow was 'active'
        if (currentStatus == 'active') {
          await _db.collection('users').doc(_currentUserId).update({
            'followingCount': FieldValue.increment(-1),
          });

          await _db.collection('users').doc(targetUserId).update({
            'followerCount': FieldValue.increment(-1),
          });
        }

        debugPrint('✅ Unfollow completed');
      } else {
        // ═══════════════ FOLLOW ═══════════════
        debugPrint('💙 Following user: $targetUserId');

        // Check if target user has private account
        final targetUserDoc = await _db
            .collection('users')
            .doc(targetUserId)
            .get();
        final isPrivateAccount = targetUserDoc.data()?['private_account'] ??
            false;

        final currentUserDoc = await _db
            .collection('users')
            .doc(_currentUserId)
            .get();
        final currentUsername = currentUserDoc.data()?['name'] ?? 'User';

        final followData = {
          'followerId': _currentUserId,
          'followerName': currentUsername,
          'followingId': targetUserId,
          'followingName': targetUsername,
          'status': isPrivateAccount ? 'pending' : 'active',
          'timestamp': DateTime
              .now()
              .millisecondsSinceEpoch,
        };

        await followRef.set(followData);

        // ✅ Only update counters if NOT private OR if accepting immediately
        if (!isPrivateAccount) {
          await _db.collection('users').doc(_currentUserId).update({
            'followingCount': FieldValue.increment(1),
          });

          await _db.collection('users').doc(targetUserId).update({
            'followerCount': FieldValue.increment(1),
          });

          debugPrint('✅ Follow completed (Public account)');
        } else {
          debugPrint(
              '⏳ Follow request sent (Private account - pending approval)');

          // Send notification to target user
          await _db.collection('users').doc(targetUserId).collection(
              'notifications').add({
            'type': 'follow_request',
            'fromUserId': _currentUserId,
            'fromUserName': currentUsername,
            'toUserId': targetUserId,
            'timestamp': DateTime
                .now()
                .millisecondsSinceEpoch,
            'isRead': false,
          });
        }

        // 🔔 ✅ SEND FCM NOTIFICATION
        _sendFollowNotificationInBackground(
            targetUserId, targetUsername, isPrivateAccount, currentUsername);
      }
    } catch (e) {
      debugPrint('❌ Error toggling follow: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update follow status'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

// 🆕 NEW METHOD: Send follow notification in background (activity_user_profile.dart)
  void _sendFollowNotificationInBackground(String targetUserId,
      String targetUsername,
      bool isPrivate,
      String currentUsername,) {
    if (_currentUserId == null || _currentUserId == targetUserId) {
      debugPrint('⏭️ Skipping self-notification');
      return;
    }

    _sendFollowNotificationToBackend(
      targetUserId,
      targetUsername,
      currentUsername,
      isPrivate,
    ).then((_) {
      debugPrint('✅ Background follow notification sent');
    }).catchError((error) {
      debugPrint('⚠️ Follow notification failed (non-critical): $error');
    });
  }

// 🆕 NEW METHOD: Send notification to backend (activity_user_profile.dart)
  Future<void> _sendFollowNotificationToBackend(String targetUserId,
      String targetUsername,
      String currentUsername,
      bool isPrivate,) async {
    try {
      debugPrint('\n🔔 ========== SENDING FOLLOW NOTIFICATION ==========');
      debugPrint('📤 From: $currentUsername ($_currentUserId)');
      debugPrint('📥 To: $targetUsername ($targetUserId)');
      debugPrint('🔒 Private: $isPrivate');

      const backendUrl = 'https://avishka-tiktok-api.zeabur.app/api/follow-notification';

      final requestBody = {
        'fromUserId': _currentUserId,
        'fromUserName': currentUsername,
        'toUserId': targetUserId,
        'toUserName': targetUsername,
        'followStatus': isPrivate ? 'pending' : 'active',
      };

      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Timeout'),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Follow notification sent to backend');
      } else {
        debugPrint('⚠️ Backend error: ${response.statusCode}');
      }
      debugPrint('==========================================\n');
    } catch (e) {
      debugPrint('❌ Follow notification error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════
  //  UTILITY  — kept exactly as originalTab
  // ══════════════════════════════════════════════════════════

  void _copyUsername(String username) {
    if (username.isNotEmpty) {
      final cleanUsername =
      username.startsWith('@') ? username.substring(1) : username;
      Clipboard.setData(ClipboardData(text: '@$cleanUsername'));
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Copied @$cleanUsername'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black87,
          duration: const Duration(seconds: 2),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      debugPrint('📋 Username copied: @$cleanUsername');
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
// ══════════════════════════════════════════════════════════
//  BIRTHDAY & REGION TAG HELPERS
// ══════════════════════════════════════════════════════════

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

  Widget _buildProfileTags(Map<String, dynamic> userData) {
    final birthday = userData['birthday'] as String? ?? '';
    final showBirthdayTag = userData['show_birthday_tag'] as bool? ?? true;
    final showAge = userData['show_age'] as bool? ?? true;
    final region = userData['region'] as String? ?? '';
    final showRegionTag = userData['show_region_tag'] as bool? ?? true;

    final int? age = (showBirthdayTag && showAge) ? _calculateAge(birthday) : null;

    final List<Widget> chips = [];

    if (age != null) {
      chips.add(_buildTagChip(Icons.person_outline, 'Age $age'));
    }

    if (region.isNotEmpty && showRegionTag) {
      chips.add(_buildTagChip(Icons.location_on_outlined, region));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(spacing: 8, runSpacing: 6, children: chips),
    );
  }

  Widget _buildTagChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
              shadows: [
                Shadow(
                  offset: Offset(1, 1),
                  blurRadius: 2.0,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {

    // 🆕 Blocked user — "User not found" screen පෙන්වනවා
    if (_isBlockedUser) {
      return Scaffold(
        backgroundColor: const Color(0xFF0E0E0E),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off_outlined,
                  color: Colors.white.withOpacity(0.3), size: 56),
              const SizedBox(height: 16),
              const Text('User not found',
                  style: TextStyle(color: Colors.white,
                      fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('This account is not available.',
                  style: TextStyle(color: Colors.white.withOpacity(0.45),
                      fontSize: 13.5)),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFF1A1A1A),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── 1. Cover + overlaid back/dots + avatar + info ──
            _buildCoverSection(),
            // ─── 2. Divider ────────────────────────────────────
            const SizedBox(height: 14),
            const Divider(color: Color(0xFF2C2C2C), height: 1, indent: 0),
            // ─── 3. Tab bar (Notes | Saves + 🔍) ──────────────
            const SizedBox(height: 4),
            _buildTabBar(),
            // ─── 4. Tab content  ← KEPT EXACTLY AS ORIGINAL ──
            _buildTabContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverSection() {
    if (widget.userId == null) {
      return const SizedBox(height: 200,
          child: Center(child: Text(
              'User not found', style: TextStyle(color: Colors.white))));
    }

    final double screenW = MediaQuery
        .of(context)
        .size
        .width;
    // Increased cover height to accommodate new layout
    final double coverH = screenW * 0.99;

    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('users').doc(widget.userId).snapshots(),
      builder: (context, snapshot) {
        // Extract all user fields
        String name = 'User';
        String username = '';
        String bio = '';
        String location = '';
        String? profileImageUrl;
        String? coverImageUrl;

        if (snapshot.hasData && snapshot.data != null &&
            snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          name = data['name'] ?? 'User';
          username = data['username'] ?? data['uid'] ?? '';
          bio = data['bio'] ?? '';
          location = data['location'] ?? data['address'] ?? '';
          profileImageUrl =
              data['profile_picture_url'] ??
                  data['profile_url'] ??
                  data['profileUrl'];

          // ✅ FIXED: Properly load cover image from all possible fields
          coverImageUrl =
              data['cover_image_url'] ??
                  data['coverImageUrl'] ??
                  data['cover_url'];
       // 🆕 Cache target user data for more-options sheet
          _cachedTargetName      = data['name']                as String? ?? '';
          _cachedTargetUsername  = data['username']             as String? ?? '';
          _cachedTargetAvatarUrl = data['profile_picture_url']  as String? ?? '';
          // 🔍 Debug log to verify cover image URL
          if (coverImageUrl != null && coverImageUrl.isNotEmpty) {
            debugPrint(
                '✅ Cover image loaded for ${widget.userId}: $coverImageUrl');
          } else {
            debugPrint('⚠️ No cover image found for ${widget.userId}');
          }
        }

        return SizedBox(
          width: screenW,
          height: coverH,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── 1. Cover background ──
              _buildCoverBackground(coverImageUrl, screenW, coverH),

              // ── 2. Bottom overlay gradient (premium blend) ──
              // ── 2. Bottom overlay gradient (premium glass blend) ──
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: coverH * 0.55,  // ← උඩට වැඩිය
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.15),
                            Colors.black.withOpacity(0.45),
                            Colors.black.withOpacity(0.75),
                            Colors.black.withOpacity(0.92),
                            const Color(0xFF1A1A1A),
                          ],
                          stops: const [0.0, 0.25, 0.50, 0.70, 0.88, 1.0],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── 3. Top bar: back arrow + three dots ──
              Positioned(
                top: 0, left: 0, right: 0,
                child: _buildOverlayTopBar(),
              ),

              // ── 4. Profile info block (bottom-anchored) ──
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar + name/id row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildProfileImage(profileImageUrl, name),
                          const SizedBox(width: 30),
                          // Name + ID + location
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        offset: const Offset(1.0, 1.5),
                                        blurRadius: 3.0,
                                        color: Colors.black.withOpacity(0.8),
                                      ),
                                    ],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ), const SizedBox(height: 10),
                                GestureDetector(
                                  onTap: () => _copyUsername(username),
                                  child: Text(
                                    '@$username',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          offset: const Offset(1.0, 1.0),
                                          blurRadius: 2.0,
                                          color: Colors.black.withOpacity(0.7),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Location line (if available)
                                if (location.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined,
                                          color: Color(0xFFFFFFFF), size: 13),
                                      const SizedBox(width: 3),
                                      Text(
                                        location,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFFFFFFF),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Bio
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          bio,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.9,
                            color: const Color(0xCCC2BCBC),
                            shadows: [
                              Shadow(
                                offset: const Offset(1.0, 1.0),
                                blurRadius: 2.0,
                                color: Colors.black.withOpacity(0.5),
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],// 🆕 ADD BIRTHDAY & REGION TAGS HERE
                      // 🆕 ADD BIRTHDAY & REGION TAGS HERE
                      Builder(
                        builder: (context) {
                          if (!snapshot.hasData || !snapshot.data!.exists) {
                            return const SizedBox.shrink();
                          }

                          final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};

                          return _buildProfileTags({
                            'birthday': userData['birthday'] ?? '',
                            'show_birthday_tag': userData['show_birthday_tag'] ?? true,
                            'show_age': userData['show_age'] ?? true,
                            'region': userData['region'] ?? '',
                            'show_region_tag': userData['show_region_tag'] ?? true,
                          });
                        },
                      ),


                      // ── NEW LAYOUT: Stats + Follow/Message ──
                      const SizedBox(height: 16),
                      _buildStatsAndActionsRow(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════
  // 🆕 IMPROVED: Cover background with Shimmer effect
  // ══════════════════════════════════════════════════════════
  Widget _buildCoverBackground(String? coverUrl, double w, double h) {
    if (coverUrl != null && coverUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: coverUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => _buildShimmerPlaceholder(w, h),
        // 🆕 Shimmer එකතු කළා
        errorWidget: (_, __, ___) => _coverFallback(w, h),
      );
    }
    return _coverFallback(w, h);
  }

  // 🆕 NEW METHOD: Shimmer placeholder for cover image
  Widget _buildShimmerPlaceholder(double w, double h) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF2A2A2A),
      highlightColor: const Color(0xFF3A3A3A),
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF2A2A2A),
              const Color(0xFF3A3A3A),
              const Color(0xFF2A2A2A),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }

  Widget _coverFallback(double w, double h) {
    // Soft pastel gradient when no cover photo exists
    final colors = _getAutoCoverGradient();

    return SizedBox(
      width: w,
      height: h,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),
      ),
    );
  }

  // ── Auto-generated cover gradient (Soft Pastel + Consistent hash) ──
  List<Color> _getAutoCoverGradient() {
    // Use userId as seed for consistent gradient per user
    final id = widget.userId ?? 'default';
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

  // ── Overlay top bar (back ← and ···) ──
  Widget _buildOverlayTopBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery
          .of(context)
          .padding
          .top + 10, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back arrow
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chevron_left,
                  color: Colors.white, size: 22),
            ),
          ),
          // Three dots
          // Three dots
          GestureDetector(
            onTap: () async {
              // Use cached values if available; otherwise fetch once.
              String name     = _cachedTargetName     ?? '';
              String username = _cachedTargetUsername  ?? '';
              String avatar   = _cachedTargetAvatarUrl ?? '';
              if (name.isEmpty) {
                try {
                  final doc = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.userId)
                      .get();
                  final d = doc.data() ?? {};
                  name     = d['name']                as String? ?? '';
                  username = d['username']             as String? ?? '';
                  avatar   = d['profile_picture_url']  as String? ?? '';
                } catch (_) {}
              }
              if (!mounted) return;
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => UserMoreOptionsSheet(
                  currentUserId:   _currentUserId!,
                  targetUserId:    widget.userId!,
                  targetUsername:  username,
                  targetName:      name,
                  targetAvatarUrl: avatar,
                ),
              );
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.more_horiz,
                  color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

// ══════════════════════════════════════════════════════════
// 🆕 IMPROVED: Profile image with Shimmer effect
// ══════════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════
// REPLACE: existing _buildProfileImage() method
// Location: _ActivityUserProfileState class
// ══════════════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════
// REPLACE: existing _buildProfileImage() method
// Location: _ActivityUserProfileState class
// ══════════════════════════════════════════════════════════════
  Widget _buildProfileImage(String? url, String name) {
    final heroTag = 'profile_image_${widget.userId ?? 'user'}';

    String initials = 'U';
    if (name.isNotEmpty) {
      final words = name.trim().split(RegExp(r'\s+'));
      if (words.length >= 2) {
        initials = (words[0][0] + words[words.length - 1][0]).toUpperCase();
      } else {
        initials = name.length >= 2
            ? name.substring(0, 2).toUpperCase()
            : name[0].toUpperCase();
      }
    }

    final hash   = name.hashCode.abs();
    final colours = [
      const Color(0xFF3B82F6), const Color(0xFFE53935),
      const Color(0xFF10B981), const Color(0xFF8B5CF6),
      const Color(0xFFF59E0B), const Color(0xFFEC4899),
    ];
    final bgColor = colours[hash % colours.length];

    Widget inner = Container(
      color: bgColor,
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );

    if (url != null && url.isNotEmpty) {
      inner = CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => _buildProfileShimmer(),
        errorWidget: (_, __, ___) => inner,
      );
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        _showProfileImagePreview(url, name, bgColor, initials);
      },
      child: Hero(
        tag: heroTag,
        child: Stack(
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
              ),
              child: ClipOval(child: inner),
            ),
            // 🆕 Verified badge — ghost accounts & real users
            FutureBuilder<DocumentSnapshot>(
              future: _db.collection('users').doc(widget.userId).get(),
              builder: (context, snap) {
                final data = snap.data?.data() as Map<String, dynamic>? ?? {};
                final isVerified = data['isVerified'] as bool? ?? false;
                if (!isVerified) return const SizedBox.shrink();
                return Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1DA1F2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 12,
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

  // 🆕 NEW METHOD: Shimmer effect for profile image
  Widget _buildProfileShimmer() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF2A2A2A),
      highlightColor: const Color(0xFF4A4A4A),
      child: Container(
        width: 78,
        height: 78,
        decoration: const BoxDecoration(
          color: Color(0xFF2A2A2A),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  REDESIGNED: Stats LEFT + Follow/Message buttons RIGHT (same row)
  //  Layout:  [Following | Followers | Likes]   [Follow] [💬]
  // ══════════════════════════════════════════════════════════
  Widget _buildStatsAndActionsRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Left: Stats ──
        Expanded(child: _buildRealTimeStatsRow()),
        // ── Right: Follow + Message buttons ──
        _buildFollowAndMessageButtons(),
      ],
    );
  }

  // Real-time stats from Firestore (unchanged logic)
  Widget _buildRealTimeStatsRow() {
    if (widget.userId == null) {
      return _statsRowWidgets('0', '0', '0');
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('users').doc(widget.userId).snapshots(),
      builder: (context, userSnap) {
        int following = 0,
            followers = 0;
        if (userSnap.hasData && userSnap.data!.exists) {
          final d = userSnap.data!.data() as Map<String, dynamic>? ?? {};
          following = d['followingCount'] as int? ?? 0;
          followers = d['followerCount'] as int? ?? 0;
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('media_posts')
              .where('uid', isEqualTo: widget.userId)
              .snapshots(),
          builder: (context, postsSnap) {
            int totalLikes = 0;
            if (postsSnap.hasData) {
              for (var doc in postsSnap.data!.docs) {
                totalLikes += ((doc.data() as Map<String, dynamic>)['likes']
                as int? ??
                    0);
              }
            }
            return _statsRowWidgets(
                _formatCount(following),
                _formatCount(followers),
                _formatCount(totalLikes));
          },
        );
      },
    );
  }
  Widget _statsRowWidgets(String following, String followers, String likes) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _buildTappableStatItem(following, 'Following', _onFollowingTap),
        const SizedBox(width: 25),
        _buildTappableStatItem(followers, 'Followers', _onFollowersTap),
        const SizedBox(width: 25),
        _buildTappableStatItem(likes, 'Likes', _onLikesTap),
      ],
    );
  }
  Widget _buildTappableStatItem(String number, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(right: 4, bottom: 4, top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              number,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                shadows: [
                  Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 3.0,
                      color: Colors.black54),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xCCCCCCCC),
                shadows: [
                  Shadow(
                    offset: Offset(1, 1),
                    blurRadius: 2.0,
                    color: Colors.black,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Future<void> _onFollowersTap() async {
    if (widget.userId == null) return;
    HapticFeedback.lightImpact();

    if (widget.userId == _currentUserId) {
      _openFollowScreen('followers', showFollowButtons: false); // ← වෙනස් කළා
      return;
    }

    try {
      final doc = await _db.collection('users').doc(widget.userId).get();
      final visibility =
      (doc.data()?['followers_visibility'] ?? 'everyone') as String;
      if (visibility == 'only_me') {
        _showPrivateListToast();
        return;
      }
    } catch (_) {}

    _openFollowScreen('followers', showFollowButtons: true); // ← වෙනස් කළා
  }

  Future<void> _onFollowingTap() async {
    if (widget.userId == null) return;
    HapticFeedback.lightImpact();

    if (widget.userId == _currentUserId) {
      _openFollowScreen('following', showFollowButtons: false); // ← වෙනස් කළා
      return;
    }

    try {
      final doc = await _db.collection('users').doc(widget.userId).get();
      final visibility =
      (doc.data()?['following_visibility'] ?? 'everyone') as String;
      if (visibility == 'only_me') {
        _showPrivateListToast();
        return;
      }
    } catch (_) {}

    _openFollowScreen('following', showFollowButtons: true); // ← වෙනස් කළා
  }

  // ── NEW: Likes number tapped → show total count sheet (no list) ──
  void _onLikesTap() {
    HapticFeedback.lightImpact();
    _showLikesTotalSheet();
  }

  // ── NEW: "This list is private" snackbar toast ──
  void _showPrivateListToast() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text(
              'This list is private',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2C2C2C),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _openFollowScreen(String type, {required bool showFollowButtons}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FollowListScreen(
          type: type,
          targetUserId: widget.userId!,
          currentUserId: _currentUserId,
          db: _db,
          onFollowTap: _handleFollowToggle, // ← null වෙනුවට සෑමවිටම pass කරනවා
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
          'timestamp': DateTime.now().millisecondsSinceEpoch,
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
  // ── NEW: Likes total bottom sheet (heart icon + formatted count) ──
  // Does NOT show who liked — just the aggregate number (privacy-safe).
  void _showLikesTotalSheet() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 36),
        child: StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('media_posts')
              .where('uid', isEqualTo: widget.userId)
              .snapshots(),
          builder: (context, snap) {
            int total = 0;
            if (snap.hasData) {
              for (final d in snap.data!.docs) {
                total += ((d.data() as Map<String, dynamic>)['likes']
                as int? ??
                    0);
              }
            }
            return _LikesCard(likesText: _formatCount(total));
          },
        ),
      ),
    );
  }



  Widget _buildStatItem(String number, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            number,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              shadows: [
                Shadow(offset: Offset(0, 1),
                    blurRadius: 3.0,
                    color: Colors.black54),
              ],
            )
        ),
        const SizedBox(height: 2),
        Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xCCCCCCCC),
              shadows: [
                Shadow(
                  offset: Offset(1, 1),
                  blurRadius: 2.0,
                  color: Colors.black,
                ),
              ],
            )
        ),
      ],
    );
  }

  // ── Follow pill + Message circle ──
  Widget _buildFollowAndMessageButtons() {
    // If viewing own profile → hide Follow, show only Message
    if (widget.userId == _currentUserId || widget.userId == null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _messageCircleButton(),
        ],
      );
    }

    final followDocId = '${_currentUserId}_${widget.userId}';

    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('follows').doc(followDocId).snapshots(),
      builder: (context, followSnap) {
        final bool isFollowing =
            followSnap.hasData && followSnap.data != null &&
                followSnap.data!.exists;

        return Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _followPillButton(isFollowing),
            const SizedBox(width: 8),
            _messageCircleButton(),
          ],
        );
      },
    );
  }

  // Red / outlined Follow pill
  Widget _followPillButton(bool isFollowing) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('users').doc(widget.userId).snapshots(),
      builder: (context, userSnap) {
        String userName = 'User';
        if (userSnap.hasData && userSnap.data!.exists) {
          userName =
              (userSnap.data!.data() as Map<String, dynamic>?)?['name'] ??
                  'User';
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          height: 46,
          decoration: BoxDecoration(
            color: isFollowing
                ? Colors.white.withOpacity(0.15)
                : const Color(0xFFE1306C),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isFollowing
                  ? Colors.white.withOpacity(0.3)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () {
                // _toggleFollow method removed - add your own implementation here
                _handleFollowToggle(widget.userId!, userName);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Text(
                      isFollowing ? 'Following' : 'Follow',
                      key: ValueKey(isFollowing),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _messageCircleButton() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('users').doc(widget.userId).snapshots(),
      builder: (context, userSnap) {
        String receiverName = 'User';
        String receiverAvatar = '';

        if (userSnap.hasData && userSnap.data!.exists) {
          final data = userSnap.data!.data() as Map<String, dynamic>? ?? {};
          receiverName = data['name'] ?? 'User';
          receiverAvatar =
              data['profile_picture_url'] ?? data['profile_url'] ?? '';
        }

        return GestureDetector(
          onTap: () => _handleMessageTap(receiverName, receiverAvatar),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SvgPicture.asset(
                'assets/images/message-2-pending-svgrepo-com.svg',
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════
  //  TAB BAR  –  Notes | Saves  +  🔍
  // ══════════════════════════════════════════════════════════
  Widget _buildTabBar() {
    if (_isLoadingPrivacy) {
      return Container(
        color: const Color(0xFF1A1A1A),
        padding: const EdgeInsets.fromLTRB(20, 26, 10, 16),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: Color(0xFFFF3B5C),
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.fromLTRB(20, 26, 10, 16),
      child: Row(
        children: [
          ...List.generate(_visibleTabs.length, (index) {
            final bool active = _activeTab == index;
            final String label = _visibleTabs[index]['label'] as String;

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _activeTab = index;
                    _tabController.animateTo(index);
                  });
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? Colors.white : const Color(0xFF666666),
                        letterSpacing: active ? 0.2 : 0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 2.5,
                      width: active ? 32 : 0,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEA314E),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          GestureDetector(
            onTap: () {
              debugPrint('🔍 Search tapped');
              HapticFeedback.lightImpact();
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              child: const Icon(
                Icons.search_outlined,
                color: Color(0xFF888888),
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  TAB CONTENT  ← KEPT EXACTLY AS ORIGINAL
  // ══════════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════
// REPLACE: existing _buildTabContent() method
// Location: _ActivityUserProfileState class
// ══════════════════════════════════════════════════════════════
  Widget _buildTabContent() {
    if (_isLoadingPrivacy) {
      return const SizedBox(
        height: 500,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF3B5C)),
        ),
      );
    }

    List<Widget> tabPages = [];

    for (var tab in _visibleTabs) {
      final label = tab['label'] as String;

      if (label == 'Creation') {
        // ── Ghost account or Official account → Pexels grid ──
        if (widget.userId == 'vibeflick_official') {
          tabPages.add(
            const SingleChildScrollView(
              physics: NeverScrollableScrollPhysics(),
              child: PexelsOfficialProfileGrid(),
            ),
          );
        } else {
          // 🆕 Ghost account check
          tabPages.add(_buildCreationTab());
        }
      } else if (label == 'Reposts') {
        tabPages.add(UserTabRepostPage(userId: widget.userId));
      } else if (label == 'Likes') {
        tabPages.add(UserTabLikes(userId: widget.userId));
      } else if (label == 'Thoughts') {
        tabPages.add(UserThoughtsTab(
          userId: widget.userId ?? '',
          isOwner: false,
        ));
      }
    }

    return SizedBox(
      height: 500,
      child: TabBarView(
        controller: _tabController,
        children: tabPages,
      ),
    );
  }

// 🆕 ADD THIS METHOD: Creation tab with ghost account support
// Location: Inside _ActivityUserProfileState class
// Add after _buildTabContent()
  Widget _buildCreationTab() {
    if (widget.userId == null) {
      return UserTabMedia(userId: widget.userId);
    }

    return FutureBuilder<DocumentSnapshot>(
      future: _db.collection('users').doc(widget.userId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return UserTabMedia(userId: widget.userId);
        }

        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final isGhost    = data['isGhostAccount'] as bool? ?? false;
        final category   = data['pexelsCategory'] as String? ?? '';

        if (isGhost && category.isNotEmpty) {
          // 🎯 Ghost account → category-specific Pexels grid
          return SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: PexelsCategoryProfileGrid(category: category),
          );
        }

        // Normal user → regular media tab
        return UserTabMedia(userId: widget.userId);
      },
    );
  }
  // ══════════════════════════════════════════════════════════
//  MESSAGE TAP HANDLER - Navigate to Chat Screen
// ══════════════════════════════════════════════════════════
  void _handleMessageTap(String receiverName, String receiverAvatar) async {
    if (widget.userId == null || _currentUserId == null) {
      debugPrint('❌ Cannot open chat: userId or currentUserId is null');
      return;
    }

    if (widget.userId == _currentUserId) {
      debugPrint('⚠️ Cannot message yourself');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You cannot message yourself'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    debugPrint('💬 Opening chat with: $receiverName (${widget.userId})');

    // Get current user's name and avatar
    final currentUserDoc = await _db
        .collection('users')
        .doc(_currentUserId)
        .get();
    final currentUserName = currentUserDoc.data()?['name'] ?? 'User';
    final currentUserAvatar = currentUserDoc.data()?['profile_picture_url'] ??
        currentUserDoc.data()?['profile_url'] ?? '';

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ChatScreen(
                currentUserId: _currentUserId!,
                currentUserName: currentUserName,
                currentUserAvatar: currentUserAvatar,
                receiverId: widget.userId!,
                receiverName: receiverName,
                receiverAvatar: receiverAvatar,
              ),
        ),
      );
    }
  }

  void _showProfileImagePreview(String? url, String name, Color bgColor,
      String initials) {
    final heroTag = 'profile_image_${widget.userId ?? 'user'}';

    Widget inner = Container(
      color: bgColor,
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 80,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );

    if (url != null && url.isNotEmpty) {
      inner = CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => inner,
      );
    }

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
                      child: ClipOval(child: inner),
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
// ══════════════════════════════════════════════════════════
// 🆕 BLOCK CHECK
// ══════════════════════════════════════════════════════════
  Future<void> _checkIfBlocked() async {
    final myId = _currentUserId;
    final theirId = widget.userId;
    if (myId == null || theirId == null || myId == theirId) return;

    try {
      final results = await Future.wait([
        _db.collection('blocked_users')
            .where('blockerId', isEqualTo: myId)
            .where('blockedId', isEqualTo: theirId)
            .limit(1).get(),
        _db.collection('blocked_users')
            .where('blockerId', isEqualTo: theirId)
            .where('blockedId', isEqualTo: myId)
            .limit(1).get(),
      ]);

      if (mounted) {
        setState(() {
          _isBlockedUser = results.any((snap) => snap.docs.isNotEmpty);
        });
      }
    } catch (e) {
      debugPrint('❌ Block check error: $e');
    }
  }


// 🆕 LOAD PRIVACY SETTINGS FROM FIREBASE
// ══════════════════════════════════════════════════════════
  Future<void> _loadPrivacySettings() async {
    if (widget.userId == null) {
      _initializeTabsWithDefaults();
      return;
    }

    try {
      debugPrint('📥 Loading privacy settings for user: ${widget.userId}');

      final userDoc = await _db.collection('users').doc(widget.userId).get();

      if (userDoc.exists) {
        final data = userDoc.data()!;

        setState(() {
          _showLikedPostsEnabled = data['show_liked_posts'] ?? true;
          _showRepostsEnabled = data['show_reposts'] ?? true;
          _enableNearbyVibes = data['enable_nearby_vibes'] ?? false;  // ← මේක add කරන්න
          _isLoadingPrivacy = false;
        });

        debugPrint('✅ Privacy settings loaded:');
        debugPrint('   - Show Liked Posts: $_showLikedPostsEnabled');
        debugPrint('   - Show Reposts: $_showRepostsEnabled');
      } else {
        debugPrint('⚠️ User document not found, using defaults');
        setState(() {
          _showLikedPostsEnabled = true;
          _showRepostsEnabled = true;
          _isLoadingPrivacy = false;
        });
      }

      // Now initialize tabs based on loaded settings
      _initializeTabs();
    } catch (e) {
      debugPrint('❌ Error loading privacy settings: $e');
      _initializeTabsWithDefaults();
    }
  }

// ══════════════════════════════════════════════════════════
// 🆕 INITIALIZE TABS DYNAMICALLY BASED ON PRIVACY SETTINGS
// ══════════════════════════════════════════════════════════
  void _initializeTabs() {
    final bool isOwnProfile = _currentUserId == widget.userId;

    List<Map<String, dynamic>> tabs = [
      {'label': 'Creation', 'icon': Icons.grid_on},
    ];

    // 🔥 OWNER: Show all tabs
    if (isOwnProfile) {
      tabs.add({'label': 'Reposts', 'icon': Icons.repeat});
      tabs.add({'label': 'Likes', 'icon': Icons.favorite_outline});
      // ↓ මේක add කරන්න මෙතනට
      if (_enableNearbyVibes) {
        tabs.add({'label': 'Thoughts', 'icon': Icons.edit_note_rounded});
      }

      debugPrint('👤 Own profile - Showing all tabs (3 tabs)');
    }
    // 🌍 VISITOR: Show tabs based on privacy settings
    else {
      if (_showRepostsEnabled) {
        tabs.add({'label': 'Reposts', 'icon': Icons.repeat});
        debugPrint('✅ Reposts tab visible (setting enabled)');
      } else {
        debugPrint('🔒 Reposts tab hidden (setting disabled)');
      }

      if (_showLikedPostsEnabled) {
        tabs.add({'label': 'Likes', 'icon': Icons.favorite_outline});
        debugPrint('✅ Likes tab visible (setting enabled)');
      } else {
        debugPrint('🔒 Likes tab hidden (setting disabled)');
      }
    }

    setState(() {
      _visibleTabs = tabs;
      _tabController = TabController(length: tabs.length, vsync: this);
    });

    debugPrint('📊 Total visible tabs: ${tabs.length}');
  }

  void _initializeTabsWithDefaults() {
    setState(() {
      _showLikedPostsEnabled = true;
      _showRepostsEnabled = true;
      _isLoadingPrivacy = false;
    });
    _initializeTabs();
  }
}

// ══════════════════════════════════════════════════════════════
// ADD TO END OF FILE: PexelsCategoryProfileGrid widget
// Location: activity_user_profile.dart — after PexelsOfficialProfileGrid
// ══════════════════════════════════════════════════════════════

// Category → Pexels video search keyword map
const Map<String, String> _pexelsCategoryKeywords = {
  'Travel':      'travel adventure landscape',
  'Fitness':     'fitness workout exercise',
  'Cooking':     'cooking food recipe kitchen',
  'Food':        'food restaurant delicious',
  'Tech':        'technology innovation computer',
  'Art':         'art creative painting',
  'Fashion':     'fashion style clothing',
  'Gaming':      'gaming esports video game',
  'Music':       'music concert instrument',
  'Comedy':      'comedy fun entertainment',
  'Education':   'education learning study',
  'Photography': 'photography camera portrait',
  'Beauty':      'beauty makeup cosmetics',
  'DIY':         'diy crafts handmade',
};

class PexelsCategoryProfileGrid extends StatefulWidget {
  final String category;

  const PexelsCategoryProfileGrid({
    super.key,
    required this.category,
  });

  @override
  State<PexelsCategoryProfileGrid> createState() =>
      _PexelsCategoryProfileGridState();
}

class _PexelsCategoryProfileGridState
    extends State<PexelsCategoryProfileGrid> {
  static const String _pexelsApiKey =
      'IlqjoaL1ckMPQJqN9EutMDfdoVw1oQMF4hyL4TSzrOPgMp4HKgDNdwoX';

  List<Map<String, dynamic>> _videos = [];
  bool _isLoading    = true;
  bool _isLoadingMore = false;
  int  _currentPage  = 1;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  String get _searchQuery {
    final keyword = _pexelsCategoryKeywords[widget.category];
    if (keyword != null && keyword.isNotEmpty) return keyword;
    return widget.category.toLowerCase();
  }

  Future<void> _loadVideos({bool loadMore = false}) async {
    if (loadMore && _isLoadingMore) return;
    setState(() {
      if (loadMore) _isLoadingMore = true;
      else          _isLoading     = true;
    });

    try {
      final page = loadMore ? _currentPage + 1 : 1;
      final encodedQuery = Uri.encodeComponent(_searchQuery);
      final uri = Uri.parse(
        'https://api.pexels.com/videos/search?query=$encodedQuery&page=$page&per_page=20',
      );

      final response = await http.get(uri, headers: {
        'Authorization': _pexelsApiKey,
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data    = json.decode(response.body) as Map<String, dynamic>;
        final videos  = (data['videos'] as List?) ?? [];

        final parsed = videos.map<Map<String, dynamic>>((video) {
          return {
            'id':            'pexels_ghost_${video['id']}',
            'thumbnail_url': video['image'] as String? ?? '',
            'media_url':     _selectSD(video['video_files'] as List? ?? []),
            'type':          'video',
            'isPexels':      true,
          };
        }).where((p) => (p['thumbnail_url'] as String).isNotEmpty).toList();

        setState(() {
          if (loadMore) {
            _videos.addAll(parsed);
            _currentPage = page;
            _isLoadingMore = false;
          } else {
            _videos     = parsed;
            _currentPage = 1;
            _isLoading   = false;
          }
        });
      } else {
        setState(() {
          _isLoading     = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('❌ PexelsCategoryProfileGrid error: $e');
      setState(() {
        _isLoading     = false;
        _isLoadingMore = false;
      });
    }
  }

  String _selectSD(List<dynamic> files) {
    final sd = files.where((f) {
      final w = (f['width'] as num?)?.toInt() ?? 0;
      return w > 0 && w < 1280;
    }).toList()
      ..sort((a, b) =>
          ((b['width'] as num?)?.toInt() ?? 0)
              .compareTo((a['width'] as num?)?.toInt() ?? 0));

    if (sd.isNotEmpty)    return sd.first['link'] as String? ?? '';
    if (files.isNotEmpty) return files.first['link'] as String? ?? '';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 1.5,
          mainAxisSpacing: 1.5,
          childAspectRatio: 9 / 16,
        ),
        itemCount: 12,
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor:     const Color(0xFF2A2A2A),
          highlightColor: const Color(0xFF3A3A3A),
          child: Container(color: const Color(0xFF2A2A2A)),
        ),
      );
    }

    if (_videos.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No videos available',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 200) {
          _loadVideos(loadMore: true);
        }
        return false;
      },
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 1.5,
          mainAxisSpacing: 1.5,
          childAspectRatio: 9 / 16,
        ),
        itemCount: _videos.length + (_isLoadingMore ? 3 : 0),
        itemBuilder: (context, index) {
          if (index >= _videos.length) {
            return Shimmer.fromColors(
              baseColor:     const Color(0xFF2A2A2A),
              highlightColor: const Color(0xFF3A3A3A),
              child: Container(color: const Color(0xFF2A2A2A)),
            );
          }

          final video     = _videos[index];
          final thumbnail = video['thumbnail_url'] as String;

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                thumbnail,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Shimmer.fromColors(
                    baseColor:     const Color(0xFF2A2A2A),
                    highlightColor: const Color(0xFF3A3A3A),
                    child: Container(color: const Color(0xFF2A2A2A)),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF2A2A2A),
                  child: const Icon(Icons.broken_image,
                      color: Colors.white24, size: 32),
                ),
              ),
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
// Helper class for social icons
class _SocialIconData {
  final IconData icon;
  final Color color;
  final String label;

  const _SocialIconData({
    required this.icon,
    required this.color,
    required this.label,
  });
}
// ── Tiny immutable holder used by _buildSocialIconRow ──
class _SocialIcon {
  final IconData icon;
  final Color color;
  final String label;
  const _SocialIcon({required this.icon, required this.color, required this.label});
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

// ══════════════════════════════════════════════════════════════
// PEXELS OFFICIAL PROFILE GRID WIDGET
// Official account uid: 'vibeflick_official'
// ══════════════════════════════════════════════════════════════
class PexelsOfficialProfileGrid extends StatefulWidget {
  const PexelsOfficialProfileGrid({super.key});

  @override
  State<PexelsOfficialProfileGrid> createState() =>
      _PexelsOfficialProfileGridState();
}

class _PexelsOfficialProfileGridState
    extends State<PexelsOfficialProfileGrid> {
  static const String _pexelsApiKey =
      'IlqjoaL1ckMPQJqN9EutMDfdoVw1oQMF4hyL4TSzrOPgMp4HKgDNdwoX';

  List<Map<String, dynamic>> _videos = [];
  bool _isLoading = true;
  int _currentPage = 1;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos({bool loadMore = false}) async {
    if (loadMore && _isLoadingMore) return;

    setState(() {
      if (loadMore) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
      }
    });

    try {
      final page = loadMore ? _currentPage + 1 : 1;
      final uri = Uri.parse(
        'https://api.pexels.com/videos/popular?page=$page&per_page=20',
      );

      final response = await http.get(uri, headers: {
        'Authorization': _pexelsApiKey,
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final videos = (data['videos'] as List?) ?? [];

        final parsed = videos.map<Map<String, dynamic>>((video) {
          return {
            'id': 'pexels_${video['id']}',
            'thumbnail_url': video['image'] as String? ?? '',
            'media_url': _selectSD(video['video_files'] as List? ?? []),
            'type': 'video',
            'isPexels': true,
          };
        }).where((p) => (p['thumbnail_url'] as String).isNotEmpty).toList();

        setState(() {
          if (loadMore) {
            _videos.addAll(parsed);
            _currentPage = page;
            _isLoadingMore = false;
          } else {
            _videos = parsed;
            _currentPage = 1;
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Pexels grid load error: $e');
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  String _selectSD(List<dynamic> files) {
    final sd = files.where((f) {
      final w = (f['width'] as num?)?.toInt() ?? 0;
      return w > 0 && w < 1280;
    }).toList()
      ..sort((a, b) =>
          ((b['width'] as num?)?.toInt() ?? 0)
              .compareTo((a['width'] as num?)?.toInt() ?? 0));

    if (sd.isNotEmpty) return sd.first['link'] as String? ?? '';
    if (files.isNotEmpty) return files.first['link'] as String? ?? '';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 1.5,
          mainAxisSpacing: 1.5,
          childAspectRatio: 9 / 16,
        ),
        itemCount: 12,
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: const Color(0xFF2A2A2A),
          highlightColor: const Color(0xFF3A3A3A),
          child: Container(color: const Color(0xFF2A2A2A)),
        ),
      );
    }

    if (_videos.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No videos available',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 200) {
          _loadVideos(loadMore: true);
        }
        return false;
      },
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 1.5,
          mainAxisSpacing: 1.5,
          childAspectRatio: 9 / 16,
        ),
        itemCount: _videos.length + (_isLoadingMore ? 3 : 0),
        itemBuilder: (context, index) {
          if (index >= _videos.length) {
            return Shimmer.fromColors(
              baseColor: const Color(0xFF2A2A2A),
              highlightColor: const Color(0xFF3A3A3A),
              child: Container(color: const Color(0xFF2A2A2A)),
            );
          }

          final video = _videos[index];
          final thumbnail = video['thumbnail_url'] as String;

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                thumbnail,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Shimmer.fromColors(
                    baseColor: const Color(0xFF2A2A2A),
                    highlightColor: const Color(0xFF3A3A3A),
                    child: Container(color: const Color(0xFF2A2A2A)),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF2A2A2A),
                  child: const Icon(Icons.broken_image,
                      color: Colors.white24, size: 32),
                ),
              ),
              // Video play icon
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}