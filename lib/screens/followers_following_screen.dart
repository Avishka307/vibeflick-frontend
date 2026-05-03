// followers_following_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FollowersFollowingScreen extends StatefulWidget {
  final String userId; // Profile owner's user ID
  final int initialIndex; // 0 = Followers, 1 = Following
  final String userName; // For display purposes
  final bool isOwnProfile; // Whether viewing own profile

  const FollowersFollowingScreen({
    Key? key,
    required this.userId,
    required this.initialIndex,
    required this.userName,
    this.isOwnProfile = false,
  }) : super(key: key);

  @override
  State<FollowersFollowingScreen> createState() => _FollowersFollowingScreenState();
}

class _FollowersFollowingScreenState extends State<FollowersFollowingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Privacy check
  bool _isPrivateAccount = false;
  bool _isFollowing = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
    _checkPrivacyAndPermissions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkPrivacyAndPermissions() async {
    // If viewing own profile, no privacy check needed
    if (widget.isOwnProfile) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Check if account is private
      final userDoc = await _db.collection('users').doc(widget.userId).get();
      if (userDoc.exists) {
        _isPrivateAccount = userDoc.data()?['private_account'] ?? false;

        // If private, check if current user is following
        if (_isPrivateAccount) {
          final currentUserId = _auth.currentUser?.uid;
          if (currentUserId != null) {
            final followDoc = await _db
                .collection('follows')
                .where('followerId', isEqualTo: currentUserId)
                .where('followingId', isEqualTo: widget.userId)
                .where('status', isEqualTo: 'active')
                .limit(1)
                .get();

            _isFollowing = followDoc.docs.isNotEmpty;
          }
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('❌ Error checking privacy: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF3B5998),
        ),
      )
          : _isPrivateAccount && !_isFollowing && !widget.isOwnProfile
          ? _buildPrivateAccountView()
          : Column(
        children: [
          _buildSearchBar(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFollowersList(),
                _buildFollowingList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF3B5998),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.pop(context);
        },
      ),
      title: Text(
        widget.isOwnProfile ? 'My Connections' : '${widget.userName}\'s Connections',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Search...',
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF3B5998)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear, color: Colors.grey),
            onPressed: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
          )
              : null,
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFF3B5998),
        indicatorWeight: 3,
        labelColor: const Color(0xFF3B5998),
        unselectedLabelColor: Colors.grey[600],
        labelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
        ),
        tabs: const [
          Tab(text: 'Followers'),
          Tab(text: 'Following'),
        ],
      ),
    );
  }

  Widget _buildPrivateAccountView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline,
                size: 64,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'This Account is Private',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Follow this account to see their followers and following lists.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('follows')
          .where('followingId', isEqualTo: widget.userId)
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF3B5998)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('No Followers Yet', 'Be the first to follow!');
        }

        final followerIds = snapshot.data!.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .map((data) => data['followerId'] as String)
            .toList();

        return _buildUserList(followerIds, isFollowers: true);
      },
    );
  }

  Widget _buildFollowingList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('follows')
          .where('followerId', isEqualTo: widget.userId)
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF3B5998)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('Not Following Anyone', 'Start exploring and follow users!');
        }

        final followingIds = snapshot.data!.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .map((data) => data['followingId'] as String)
            .toList();

        return _buildUserList(followingIds, isFollowers: false);
      },
    );
  }

  Widget _buildUserList(List<String> userIds, {required bool isFollowers}) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchUserDetails(userIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF3B5998)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState('No Users Found', '');
        }

        var users = snapshot.data!;

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          users = users.where((user) {
            final userName = (user['userName'] as String? ?? '').toLowerCase();
            return userName.contains(_searchQuery);
          }).toList();
        }

        if (users.isEmpty) {
          return _buildEmptyState('No Results', 'Try a different search term');
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return _buildUserListItem(
              userId: user['userId'] ?? '',
              userName: user['userName'] ?? 'Unknown',
              userAvatar: user['userAvatar'] ?? '',
              isVerified: user['isVerified'] ?? false,
              isFollowers: isFollowers,
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchUserDetails(List<String> userIds) async {
    final List<Map<String, dynamic>> users = [];

    for (String userId in userIds) {
      try {
        final doc = await _db.collection('users').doc(userId).get();
        if (doc.exists) {
          final data = doc.data()!;
          users.add({
            'userId': userId,
            'userName': data['userName'] ?? 'Unknown',
            'userAvatar': data['userAvatar'] ?? '',
            'isVerified': data['isVerified'] ?? false,
          });
        }
      } catch (e) {
        debugPrint('❌ Error fetching user $userId: $e');
      }
    }

    return users;
  }

  Widget _buildUserListItem({
    required String userId,
    required String userName,
    required String userAvatar,
    required bool isVerified,
    required bool isFollowers,
  }) {
    final currentUserId = _auth.currentUser?.uid;
    final isCurrentUser = userId == currentUserId;

    return InkWell(
      onTap: () {
        // Navigate to user profile
        debugPrint('Navigate to profile: $userId');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundImage: userAvatar.isNotEmpty
                  ? NetworkImage(userAvatar)
                  : null,
              backgroundColor: Colors.grey[300],
              child: userAvatar.isEmpty
                  ? Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              )
                  : null,
            ),
            const SizedBox(width: 12),

            // User name
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isVerified) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified,
                      size: 16,
                      color: Color(0xFF3B5998),
                    ),
                  ],
                ],
              ),
            ),

            // Action button
            if (!isCurrentUser)
              _buildActionButton(userId, isFollowers),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String userId, bool isFollowers) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('follows')
          .where('followerId', isEqualTo: _auth.currentUser?.uid)
          .where('followingId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        bool isFollowing = false;
        bool isPending = false;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final status = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          isFollowing = status['status'] == 'active';
          isPending = status['status'] == 'pending';
        }

        if (isFollowers && widget.isOwnProfile) {
          // Remove button for own followers
          return TextButton(
            onPressed: () => _removeFollower(userId),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              backgroundColor: Colors.grey[200],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text(
              'Remove',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }

        // Follow/Following button
        return TextButton(
          onPressed: () => _toggleFollow(userId, isFollowing || isPending),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            backgroundColor: isFollowing || isPending
                ? Colors.grey[200]
                : const Color(0xFF3B5998),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: Text(
            isPending ? 'Pending' : (isFollowing ? 'Following' : 'Follow'),
            style: TextStyle(
              color: isFollowing || isPending ? Colors.black87 : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleFollow(String targetUserId, bool isCurrentlyFollowing) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    HapticFeedback.mediumImpact();

    try {
      if (isCurrentlyFollowing) {
        // Unfollow
        final followDocs = await _db
            .collection('follows')
            .where('followerId', isEqualTo: currentUserId)
            .where('followingId', isEqualTo: targetUserId)
            .get();

        for (var doc in followDocs.docs) {
          await doc.reference.delete();
        }

        // Update counters
        await _db.collection('users').doc(currentUserId).update({
          'followingCount': FieldValue.increment(-1),
        });
        await _db.collection('users').doc(targetUserId).update({
          'followerCount': FieldValue.increment(-1),
        });
      } else {
        // Follow
        final targetUserDoc = await _db.collection('users').doc(targetUserId).get();
        final isPrivate = targetUserDoc.data()?['private_account'] ?? false;

        await _db.collection('follows').add({
          'followerId': currentUserId,
          'followingId': targetUserId,
          'status': isPrivate ? 'pending' : 'active',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });

        if (!isPrivate) {
          // Update counters immediately
          await _db.collection('users').doc(currentUserId).update({
            'followingCount': FieldValue.increment(1),
          });
          await _db.collection('users').doc(targetUserId).update({
            'followerCount': FieldValue.increment(1),
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error toggling follow: $e');
    }
  }

  Future<void> _removeFollower(String followerId) async {
    HapticFeedback.mediumImpact();

    try {
      final followDocs = await _db
          .collection('follows')
          .where('followerId', isEqualTo: followerId)
          .where('followingId', isEqualTo: widget.userId)
          .get();

      for (var doc in followDocs.docs) {
        await doc.reference.delete();
      }

      // Update counters
      await _db.collection('users').doc(followerId).update({
        'followingCount': FieldValue.increment(-1),
      });
      await _db.collection('users').doc(widget.userId).update({
        'followerCount': FieldValue.increment(-1),
      });
    } catch (e) {
      debugPrint('❌ Error removing follower: $e');
    }
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// භාවිතා කරන විදිය (Usage):
/*
// Followers එකට යන්න:
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => FollowersFollowingScreen(
      userId: 'user123',
      initialIndex: 0, // Followers tab
      userName: 'John Doe',
      isOwnProfile: true, // Or false
    ),
  ),
);

// Following එකට යන්න:
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => FollowersFollowingScreen(
      userId: 'user123',
      initialIndex: 1, // Following tab
      userName: 'John Doe',
      isOwnProfile: false,
    ),
  ),
);
*/