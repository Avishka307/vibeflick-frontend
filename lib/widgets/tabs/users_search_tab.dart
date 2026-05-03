import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../components/user_list_tile.dart';
import '../components/skeleton_loaders.dart';

/// File: lib/search/tabs/users_search_tab.dart
/// ✅ Algolia backend API → /search/users?q=
/// ❌ Firestore direct query ඉවත් කළා

class UsersSearchTab extends StatefulWidget {
  final String query;
  final String? currentUserId;

  const UsersSearchTab({
    super.key,
    required this.query,
    this.currentUserId,
  });

  @override
  State<UsersSearchTab> createState() => _UsersSearchTabState();
}

class _UsersSearchTabState extends State<UsersSearchTab>
    with AutomaticKeepAliveClientMixin {
  static const String _baseUrl = 'https://avishka-tiktok-api.zeabur.app';

  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  int _currentPage = 0;
  static const int _hitsPerPage = 15;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    try {
      debugPrint('👥 [Algolia] Searching users: "${widget.query}"');

      final uri = Uri.parse(
        '$_baseUrl/search/users?q=${Uri.encodeComponent(widget.query)}'
            '&limit=$_hitsPerPage&page=$_currentPage',
      );

      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        if (data['success'] == true && data['data'] != null) {
          final hits = (data['data'] as List).cast<Map<String, dynamic>>();

          _users = hits.map((u) => _mapUser(u)).toList();
          _hasMore = hits.length == _hitsPerPage;

          debugPrint('   ✅ Found ${_users.length} users');
        } else {
          _users = [];
          _hasMore = false;
        }
      }
    } catch (e) {
      debugPrint('   ❌ Error: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadMoreUsers() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      _currentPage++;
      final uri = Uri.parse(
        '$_baseUrl/search/users?q=${Uri.encodeComponent(widget.query)}'
            '&limit=$_hitsPerPage&page=$_currentPage',
      );

      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          final hits = (data['data'] as List).cast<Map<String, dynamic>>();
          final newUsers = hits.map((u) => _mapUser(u)).toList();
          _hasMore = hits.length == _hitsPerPage;
          setState(() => _users.addAll(newUsers));
        }
      }
    } catch (e) {
      debugPrint('❌ Load more error: $e');
      _currentPage--;
    }

    setState(() => _isLoadingMore = false);
  }

  /// Algolia response → UserListTile compatible map
  Map<String, dynamic> _mapUser(Map<String, dynamic> u) => {
    'uid': u['objectID'] ?? u['uid'] ?? '',
    'name': u['displayName'] ?? u['name'] ?? 'Unknown',
    'username': u['username'] ?? '',
    'email': '',
    'followers': u['followerCount'] ?? 0,
    'profileUrl': u['profilePicUrl'] ??        // ✅ Try this first
        u['profile_picture_url'] ??  // ✅ Then this
        u['profileUrl'],             // ✅ Finally this
    'bio': u['bio'] ?? '',
    'isVerified': u['isVerified'] ?? false,
  };

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SkeletonLoaders.user(),
        ),
      );
    }

    if (_users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off_outlined,
                  size: 60, color: Colors.white.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text(
                'No users found for "${widget.query}"',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16, color: Colors.white.withOpacity(0.7)),
              ),
            ],
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
          _loadMoreUsers();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _users.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _users.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: SkeletonLoaders.user(),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: UserListTile(
              user: _users[index],
              currentUserId: widget.currentUserId,
            ),
          );
        },
      ),
    );
  }
}