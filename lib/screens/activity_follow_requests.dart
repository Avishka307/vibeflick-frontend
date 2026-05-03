import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ActivityFollowRequests extends StatefulWidget {
  const ActivityFollowRequests({Key? key}) : super(key: key);

  @override
  State<ActivityFollowRequests> createState() => _ActivityFollowRequestsState();
}

class _ActivityFollowRequestsState extends State<ActivityFollowRequests> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _currentUserId;
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  void _initializeUser() {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      _currentUserId = currentUser.uid;
      _loadFollowRequests();
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _loadFollowRequests() async {
    if (_currentUserId == null) return;

    setState(() => _isLoading = true);

    try {
      // Get all pending follow requests where current user is the target
      final snapshot = await _db
          .collection('follows')
          .where('followingId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'pending')
          .orderBy('timestamp', descending: true)
          .get();

      List<Map<String, dynamic>> requests = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final followerId = data['followerId'];

        // Get requester's profile data
        final userDoc = await _db.collection('users').doc(followerId).get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          requests.add({
            'requestId': doc.id,
            'followerId': followerId,
            'followerName': data['followerName'] ?? userData['name'] ?? 'Unknown',
            'username': userData['username'] ?? followerId,
            'profileUrl': userData['profile_picture_url'] ?? userData['profile_url'],
            'timestamp': data['timestamp'],
          });
        }
      }

      setState(() {
        _requests = requests;
        _isLoading = false;
      });

      debugPrint('✅ Loaded ${_requests.length} follow requests');
    } catch (e) {
      debugPrint('❌ Error loading requests: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptRequest(String requestId, String followerId, int index) async {
    if (_currentUserId == null) return;

    try {
      HapticFeedback.mediumImpact();

      // 🔥 Use Firebase Transaction for atomicity
      await _db.runTransaction((transaction) async {
        // 1️⃣ Update follow document status
        final followRef = _db.collection('follows').doc(requestId);
        transaction.update(followRef, {'status': 'accepted'});

        // 2️⃣ Update follower count
        final targetUserRef = _db.collection('users').doc(_currentUserId);
        transaction.update(targetUserRef, {
          'followerCount': FieldValue.increment(1),
        });

        // 3️⃣ Update following count
        final followerRef = _db.collection('users').doc(followerId);
        transaction.update(followerRef, {
          'followingCount': FieldValue.increment(1),
        });
      });

      // Remove from UI
      setState(() {
        _requests.removeAt(index);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Follow request accepted'),
            ]),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF4CAF50),
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }

      debugPrint('✅ Follow request accepted');
    } catch (e) {
      debugPrint('❌ Error accepting request: $e');
      _showError('Failed to accept request');
    }
  }

  Future<void> _deleteRequest(String requestId, int index) async {
    try {
      HapticFeedback.lightImpact();

      await _db.collection('follows').doc(requestId).delete();

      setState(() {
        _requests.removeAt(index);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.delete_outline, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Request deleted'),
            ]),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF666666),
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }

      debugPrint('❌ Follow request deleted');
    } catch (e) {
      debugPrint('❌ Error deleting request: $e');
      _showError('Failed to delete request');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Follow Requests',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF3B5C)),
      )
          : _requests.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          return _buildRequestCard(_requests[index], index);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.person_add_disabled, size: 80, color: Color(0xFF666666)),
          SizedBox(height: 16),
          Text(
            'No follow requests',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF888888),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'You don\'t have any pending requests',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request, int index) {
    final name = request['followerName'] as String;
    final username = request['username'] as String;
    final profileUrl = request['profileUrl'] as String?;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Profile Picture
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFF3B5C), width: 2),
            ),
            child: ClipOval(
              child: profileUrl != null && profileUrl.isNotEmpty
                  ? CachedNetworkImage(
                imageUrl: profileUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => _buildAvatarPlaceholder(name),
                errorWidget: (_, __, ___) => _buildAvatarPlaceholder(name),
              )
                  : _buildAvatarPlaceholder(name),
            ),
          ),

          const SizedBox(width: 12),

          // Name & Username
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '@$username',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF888888),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Confirm Button
          GestureDetector(
            onTap: () => _acceptRequest(
              request['requestId'],
              request['followerId'],
              index,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B5C),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Confirm',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Delete Button
          GestureDetector(
            onTap: () => _deleteRequest(request['requestId'], index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPlaceholder(String name) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Container(
      color: const Color(0xFFFF3B5C),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
