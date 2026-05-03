import 'package:flutter/material.dart';

class TaggedFriendsDetailScreen extends StatefulWidget {
  final List<Map<String, dynamic>> taggedFriends;
  final String postId;
  final String creatorUsername;

  const TaggedFriendsDetailScreen({
    Key? key,
    required this.taggedFriends,
    required this.postId,
    required this.creatorUsername,
  }) : super(key: key);

  @override
  State<TaggedFriendsDetailScreen> createState() =>
      _TaggedFriendsDetailScreenState();
}

class _TaggedFriendsDetailScreenState extends State<TaggedFriendsDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Tagged in This Post',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: widget.taggedFriends.isEmpty
          ? _buildEmptyState()
          : _buildTaggedFriendsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_offer_outlined,
            size: 80,
            color: Colors.grey[700],
          ),
          const SizedBox(height: 16),
          Text(
            'No one tagged',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to tag someone in this post',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaggedFriendsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: widget.taggedFriends.length,
      itemBuilder: (context, index) {
        final friend = widget.taggedFriends[index];
        final name = friend['username'] ?? 'Unknown';
        final avatarUrl = friend['avatarUrl'] ?? '';

        return _buildTaggedFriendItem(name, avatarUrl);
      },
    );
  }

  Widget _buildTaggedFriendItem(String name, String avatarUrl) {
    return InkWell(
      onTap: () {
        debugPrint('🔗 Navigate to profile: $name');
        // ඔයා ගිහින් ProfilePage එකට ගිය ගිහින් ඒකට uid එක ඉස්සරින් pass කරගන්න
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.grey[800]!,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: avatarUrl.isNotEmpty
                  ? Image.network(
                avatarUrl,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildDefaultAvatar(name);
                },
              )
                  : _buildDefaultAvatar(name),
            ),
            const SizedBox(width: 16),

            // Name and Tag Badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B5C).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '🏷️ Tagged',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFFF3B5C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Chevron
            const Icon(
              Icons.chevron_right,
              color: Colors.grey,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(String name) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B5C),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}