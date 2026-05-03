import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class VideoOptionsBottomSheet extends StatefulWidget {
  final String postId;
  final String postOwnerId;
  final String postOwnerUsername;
  final String videoUrl;

  /// Post delete වුනාම parent screen close/refresh කරන්න
  final VoidCallback? onDeleted;

  /// Privacy change වුනාම parent screen refresh කරන්න
  final VoidCallback? onPrivacyChanged;

  const VideoOptionsBottomSheet({
    Key? key,
    required this.postId,
    required this.postOwnerId,
    required this.postOwnerUsername,
    required this.videoUrl,
    this.onDeleted,
    this.onPrivacyChanged,
  }) : super(key: key);

  @override
  State<VideoOptionsBottomSheet> createState() =>
      _VideoOptionsBottomSheetState();
}

class _VideoOptionsBottomSheetState extends State<VideoOptionsBottomSheet>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _currentUserId;
  bool _isOwner = false;

  // Current privacy state
  String _currentPrivacy = 'public'; // 'public' | 'onlyme'
  bool _isLoadingPrivacy = true;
  bool _isDeleting = false;
  bool _isChangingPrivacy = false;

  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid;
    _isOwner = _currentUserId == widget.postOwnerId;

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scaleAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack);
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();

    if (_isOwner) {
      _loadCurrentPrivacy();
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  // Load current privacy state
  // ─────────────────────────────────────────────────────────
  Future<void> _loadCurrentPrivacy() async {
    try {
      final doc =
      await _db.collection('media_posts').doc(widget.postId).get();
      if (doc.exists) {
        final whoCanView =
        (doc.data()?['who_can_view'] ?? 'public') as String;
        setState(() {
          _currentPrivacy = whoCanView;
          _isLoadingPrivacy = false;
        });
      } else {
        setState(() => _isLoadingPrivacy = false);
      }
    } catch (e) {
      debugPrint('❌ Error loading privacy: $e');
      setState(() => _isLoadingPrivacy = false);
    }
  }

  // ─────────────────────────────────────────────────────────
  // Toggle Privacy: public ↔ onlyme
  // ─────────────────────────────────────────────────────────
  Future<void> _handlePrivacyToggle() async {
    if (!_isOwner || _isChangingPrivacy) return;
    HapticFeedback.mediumImpact();

    final newPrivacy = _currentPrivacy == 'public' ? 'onlyme' : 'public';

    setState(() => _isChangingPrivacy = true);

    try {
      await _db.collection('media_posts').doc(widget.postId).update({
        'who_can_view': newPrivacy,
      });

      setState(() {
        _currentPrivacy = newPrivacy;
        _isChangingPrivacy = false;
      });

      debugPrint('✅ Privacy changed to: $newPrivacy');

      _showSnackBar(
        newPrivacy == 'onlyme'
            ? 'Post set to Private'
            : 'Post set to Public',
        icon: newPrivacy == 'onlyme' ? Icons.lock : Icons.public,
      );

      // Parent ට notify කරනවා (tab_private_page refresh වෙනවා)
      widget.onPrivacyChanged?.call();

      Navigator.pop(context);
    } catch (e) {
      debugPrint('❌ Error changing privacy: $e');
      setState(() => _isChangingPrivacy = false);
      _showSnackBar('Failed to change privacy. Please try again.');
    }
  }

  // ─────────────────────────────────────────────────────────
  // Delete Post
  // ─────────────────────────────────────────────────────────
  Future<void> _handleDelete() async {
    if (!_isOwner || _isDeleting) return;

    // Confirm dialog
    final confirmed = await _showDeleteConfirmDialog();
    if (!confirmed) return;

    HapticFeedback.heavyImpact();
    setState(() => _isDeleting = true);

    try {
      debugPrint('🗑️ Deleting post: ${widget.postId}');

      // 1. Firestore — media_posts document soft delete (is_active = false)
      //    Hard delete කරනවා නම් .delete() use කරන්න
      await _db.collection('media_posts').doc(widget.postId).update({
        'is_active': false,
        'deleted_at': DateTime.now().millisecondsSinceEpoch,
        'deleted_by': _currentUserId,
      });

      // 2. Sub-collections cleanup (likes, comments, views)
      //    Background task — non-blocking
      _cleanupSubcollections(widget.postId);

      // 3. saved_posts collection cleanup
      final savedSnap = await _db
          .collection('saved_posts')
          .where('postId', isEqualTo: widget.postId)
          .get();
      for (final doc in savedSnap.docs) {
        await doc.reference.delete();
      }

      // 4. Cloudinary delete (backend API හරහා)
      _deleteFromCloudinary(widget.postId);

      debugPrint('✅ Post deleted: ${widget.postId}');

      if (mounted) {
        setState(() => _isDeleting = false);
        // ✅ FIX: onDeleted call කරලා bottom sheet close — order වැදගත්
        widget.onDeleted?.call(); // Parent (PostDetailPage) notify — ඒකෙ Navigator.pop call වෙනවා
        if (mounted) Navigator.pop(context); // Bottom sheet close
      }
    } catch (e) {
      debugPrint('❌ Error deleting post: $e');
      if (mounted) {
        setState(() => _isDeleting = false);
        _showSnackBar('Failed to delete post. Please try again.');
      }
    }
  }

  // Sub-collections background cleanup
  void _cleanupSubcollections(String postId) {
    Future(() async {
      try {
        // Likes
        final likesSnap = await _db
            .collection('media_posts')
            .doc(postId)
            .collection('likes')
            .get();
        for (final d in likesSnap.docs) {
          await d.reference.delete();
        }

        // Views
        final viewsSnap = await _db
            .collection('media_posts')
            .doc(postId)
            .collection('views')
            .get();
        for (final d in viewsSnap.docs) {
          await d.reference.delete();
        }

        debugPrint('✅ Sub-collections cleaned for: $postId');
      } catch (e) {
        debugPrint('⚠️ Sub-collection cleanup error (non-critical): $e');
      }
    });
  }

  // Cloudinary delete (backend API)
  void _deleteFromCloudinary(String postId) {
    Future(() async {
      try {
        await http.post(
          Uri.parse(
              'https://avishka-tiktok-api.zeabur.app/api/media/delete'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'postId': postId,
            'userId': _currentUserId,
          }),
        );
        debugPrint('✅ Cloudinary delete requested for: $postId');
      } catch (e) {
        debugPrint('⚠️ Cloudinary delete failed (non-critical): $e');
      }
    });
  }

  // ─────────────────────────────────────────────────────────
  // Confirm Delete Dialog
  // ─────────────────────────────────────────────────────────
  Future<bool> _showDeleteConfirmDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_forever,
                    color: Colors.red, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'Delete Post?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'This post will be permanently deleted. This action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.6),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Delete',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF2C2C2C),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }

  // ─────────────────────────────────────────────────────────
  // SnackBar helper
  // ─────────────────────────────────────────────────────────
  void _showSnackBar(String message, {IconData? icon}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(message,
                  style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Owner නොවෙනම් sheet show නොකරනවා
    if (!_isOwner) {
      return const SizedBox.shrink();
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Colors.black.withOpacity(0.5),
          child: GestureDetector(
            onTap: () {}, // Inside tap block
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHandleBar(),
                      const SizedBox(height: 8),
                      _buildTitle(),
                      const SizedBox(height: 8),
                      _buildPrivacyTile(),
                      _buildDivider(),
                      _buildDeleteTile(),
                      SizedBox(
                          height:
                          MediaQuery.of(context).padding.bottom + 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandleBar() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[700],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          Text(
            'Post Options',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  // ── Privacy Toggle Tile ──────────────────────────────────
  Widget _buildPrivacyTile() {
    if (_isLoadingPrivacy) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white54,
            ),
          ),
        ),
      );
    }

    final isPrivate = _currentPrivacy == 'onlyme';

    return InkWell(
      onTap: _isChangingPrivacy ? null : _handlePrivacyToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isPrivate
                    ? Colors.purple.withOpacity(0.15)
                    : Colors.blue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: _isChangingPrivacy
                    ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isPrivate ? Colors.purple : Colors.blue,
                  ),
                )
                    : Icon(
                  isPrivate ? Icons.lock : Icons.public,
                  color: isPrivate ? Colors.purple : Colors.blue,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPrivate ? 'Set to Public' : 'Set to Private',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isPrivate
                        ? 'Currently Private — only you can see this'
                        : 'Currently Public — anyone can see this',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),

            // Current state badge
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isPrivate
                    ? Colors.purple.withOpacity(0.2)
                    : Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isPrivate
                      ? Colors.purple.withOpacity(0.4)
                      : Colors.blue.withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: Text(
                isPrivate ? '🔒 Private' : '🌍 Public',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isPrivate ? Colors.purple[200] : Colors.blue[200],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: Colors.grey[800],
      indent: 16,
      endIndent: 16,
    );
  }

  // ── Delete Tile ──────────────────────────────────────────
  Widget _buildDeleteTile() {
    return InkWell(
      onTap: _isDeleting ? null : _handleDelete,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: _isDeleting
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.red,
                  ),
                )
                    : const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Delete Post',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Permanently remove this post',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),

            Icon(
              Icons.chevron_right,
              color: Colors.red.withOpacity(0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}