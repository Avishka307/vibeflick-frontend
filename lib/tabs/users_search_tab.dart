import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../screens/search_shared_widgets.dart';


class UsersSearchTab extends StatefulWidget {
  final String query;
  final String? currentUserId;

  const UsersSearchTab({super.key, required this.query, this.currentUserId});

  @override
  State<UsersSearchTab> createState() => _UsersSearchTabState();
}

class _UsersSearchTabState extends State<UsersSearchTab>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    setState(() => _isLoading = true);
    try {
      final res = await http
          .get(Uri.parse(
        'https://avishka-tiktok-api.zeabur.app/search/users?q=${Uri.encodeComponent(widget.query)}&limit=20',
      ))
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() => _users = List<Map<String, dynamic>>.from(data['data']));
          debugPrint('✅ [Users Tab] ${_users.length} results');
          return;
        }
      }
    } catch (e) {
      debugPrint('❌ [Users Tab] $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) return SearchShimmer.list();
    if (_users.isEmpty) {
      return const SearchEmpty(
        icon: Icons.person_search,
        label: 'No users found',
        sub: 'Try a different name or username',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _users.length,
      itemBuilder: (_, i) =>
          _UserTile(user: _users[i], currentUserId: widget.currentUserId),
    );
  }
}

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final String? currentUserId;
  const _UserTile({required this.user, this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final name = user['displayName'] ?? user['username'] ?? 'Unknown';
    final username = user['username'] ?? '';
    final pic = user['profilePicUrl'];
    final followers = user['followerCount'] ?? 0;
    final verified = user['isVerified'] ?? false;
    final uid = user['objectID'] ?? user['uid'] ?? '';

    return InkWell(
      onTap: () => debugPrint('Navigate to profile: $username'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            SearchAvatar(url: pic, name: name, size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(name,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (verified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded,
                            size: 15, color: Color(0xFF1DA1F2)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text('@$username  ·  ${_fmt(followers)} followers',
                      style: TextStyle(
                          fontSize: 13, color: Colors.white.withOpacity(0.4)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (uid != currentUserId) _FollowButton(userId: uid),
          ],
        ),
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _FollowButton extends StatefulWidget {
  final String userId;
  const _FollowButton({required this.userId});

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  bool _following = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _following = !_following),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          color: _following ? Colors.transparent : const Color(0xFFFF0050),
          border: Border.all(
            color: _following
                ? Colors.white.withOpacity(0.35)
                : Colors.transparent,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _following ? 'Following' : 'Follow',
          style: TextStyle(
            color: _following ? Colors.white.withOpacity(0.65) : Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}