import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TagFriendsScreen extends StatefulWidget {
  const TagFriendsScreen({Key? key}) : super(key: key);

  @override
  State<TagFriendsScreen> createState() => _TagFriendsScreenState();
}

class _TagFriendsScreenState extends State<TagFriendsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _currentUserId;

  // Following list (from Firebase)
  List<Friend> _followingList = [];
  final List<Friend> _selectedFriends = [];
  final TextEditingController _searchController = TextEditingController();
  List<Friend> _filteredFriends = [];
  bool _isLoading = true;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid;
    _loadFollowingList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

// ✅ FIXED: Load Following List from Firebase
  Future<void> _loadFollowingList() async {
    if (_currentUserId == null) {
      debugPrint('❌ No current user');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      debugPrint('🔄 Loading following list...');

      setState(() {
        _isLoading = true;
      });

      // ✅ CORRECT: Get from 'follows' collection where current user is the follower
      final followingSnapshot = await _db
          .collection('follows')
          .where('followerId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'active')  // ✅ Only accepted follows
          .get();

      if (followingSnapshot.docs.isEmpty) {
        debugPrint('⚠️ No following list found');
        setState(() {
          _isLoading = false;
          _followingList = [];
          _filteredFriends = [];
        });
        return;
      }

      List<Friend> followingUsers = [];

      // Get each following user's details
      for (var doc in followingSnapshot.docs) {
        final followData = doc.data();
        final followingUserId = followData['followingId'] ?? '';
        final followingUserName = followData['followingName'] ?? 'Unknown';

        try {
          final userDoc = await _db
              .collection('users')
              .doc(followingUserId)
              .get();

          if (userDoc.exists) {
            final userData = userDoc.data();

            // ✅ Only add PUBLIC accounts
            final isPrivate = userData?['private_account'] ?? false;

            if (!isPrivate) {
              followingUsers.add(Friend(
                id: followingUserId,
                name: userData?['name'] ?? followingUserName,
                username: '@${userData?['username'] ?? followingUserId}',
                avatarUrl: userData?['profile_picture_url'] ??
                    userData?['profileImageUrl'] ??
                    userData?['profile_url'] ??
                    'https://i.pravatar.cc/150?img=1',
              ));
            } else {
              debugPrint('🔒 Skipping private account: $followingUserName');
            }
          }
        } catch (e) {
          debugPrint('❌ Error loading user $followingUserId: $e');
        }
      }

      debugPrint('✅ Loaded ${followingUsers.length} public following users');

      setState(() {
        _followingList = followingUsers;
        _filteredFriends = followingUsers;
        _isLoading = false;
      });

    } catch (e) {
      debugPrint('❌ Error loading following list: $e');
      setState(() {
        _isLoading = false;
        _followingList = [];
        _filteredFriends = [];
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load following list'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  // Search function with debouncing
  void _filterFriends(String query) {
    // Cancel previous timer
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    // Start new timer (500ms debounce)
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        if (query.isEmpty) {
          _filteredFriends = _followingList;
        } else {
          _filteredFriends = _followingList
              .where((friend) =>
          friend.name.toLowerCase().contains(query.toLowerCase()) ||
              friend.username.toLowerCase().contains(query.toLowerCase()))
              .toList();
        }
      });
    });
  }

  // Toggle selection
  void _toggleSelection(Friend friend) {
    setState(() {
      if (_selectedFriends.contains(friend)) {
        _selectedFriends.remove(friend);
      } else {
        _selectedFriends.add(friend);
      }
    });
  }

  // Remove from selected
  void _removeFromSelected(Friend friend) {
    setState(() {
      _selectedFriends.remove(friend);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E1E1E),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Tag Friends',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // ✅ Return selected friends list
                Navigator.pop(context, _selectedFriends);
              },
              child: const Text(
                'Done',
                style: TextStyle(
                  color: Color(0xFFFF3B5C),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // 1. Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                onChanged: _filterFriends,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search following...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),

            // 2. Selected Friends Chips (Horizontal scroll)
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _selectedFriends.isEmpty
                  ? const SizedBox.shrink()
                  : Container(
                height: 70,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedFriends.length,
                  itemBuilder: (context, index) {
                    final friend = _selectedFriends[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: 1.0,
                        child: InputChip(
                          backgroundColor: const Color(0xFF2A2A2A),
                          avatar: CircleAvatar(
                            backgroundImage:
                            NetworkImage(friend.avatarUrl),
                          ),
                          label: Text(
                            friend.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          deleteIcon: const Icon(
                            Icons.close,
                            color: Color(0xFFFF3B5C),
                            size: 18,
                          ),
                          onDeleted: () => _removeFromSelected(friend),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 8),

            // 3. Friends List
            Expanded(
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFFF3B5C),
                ),
              )
                  : _filteredFriends.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 80,
                      color: Colors.grey[700],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _searchController.text.isEmpty
                          ? 'No following users found'
                          : 'No results found',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 16,
                      ),
                    ),
                    if (_searchController.text.isEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Follow people to tag them',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              )
                  : NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  // Dismiss keyboard when scrolling
                  if (notification is ScrollStartNotification) {
                    FocusScope.of(context).unfocus();
                  }
                  return false;
                },
                child: ListView.builder(
                  itemCount: _filteredFriends.length,
                  itemBuilder: (context, index) {
                    final friend = _filteredFriends[index];
                    final isSelected =
                    _selectedFriends.contains(friend);

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      color: isSelected
                          ? const Color(0xFF2A2A2A)
                          : Colors.transparent,
                      child: ListTile(
                        onTap: () => _toggleSelection(friend),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundImage:
                          NetworkImage(friend.avatarUrl),
                        ),
                        title: Text(
                          friend.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          friend.username,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                        trailing: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, animation) {
                            return ScaleTransition(
                              scale: animation,
                              child: child,
                            );
                          },
                          child: isSelected
                              ? const Icon(
                            Icons.check_circle,
                            color: Color(0xFFFF3B5C),
                            size: 28,
                            key: ValueKey('selected'),
                          )
                              : Icon(
                            Icons.circle_outlined,
                            color: Colors.grey[600],
                            size: 28,
                            key: ValueKey('unselected'),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Friend Model
class Friend {
  final String id;
  final String name;
  final String username;
  final String avatarUrl;

  Friend({
    required this.id,
    required this.name,
    required this.username,
    required this.avatarUrl,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Friend && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}