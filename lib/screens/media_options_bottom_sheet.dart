import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';

class MediaOptionsBottomSheet extends StatelessWidget {
  final String postId;
  final String postOwnerId;
  final String postOwnerUsername;
  final String mediaUrl;
  final VoidCallback? onReported;

  const MediaOptionsBottomSheet({
    Key? key,
    required this.postId,
    required this.postOwnerId,
    required this.postOwnerUsername,
    required this.mediaUrl,
    this.onReported,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final bool isOwnPost = currentUserId == postOwnerId;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                isOwnPost ? 'Post Options' : '@$postOwnerUsername',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            const Divider(color: Color(0xFF2C2C2C), height: 1),

            // Options List
            if (!isOwnPost) ...[
              _buildOptionTile(
                context: context,
                icon: Icons.flag_outlined,
                label: 'Report',
                iconColor: const Color(0xFFFF3B5C),
                onTap: () {
                  Navigator.pop(context);
                  _showReportBottomSheet(context, currentUserId);
                },
              ),
              _buildOptionTile(
                context: context,
                icon: Icons.block_outlined,
                label: 'Block @$postOwnerUsername',
                iconColor: const Color(0xFFFF3B5C),
                onTap: () {
                  Navigator.pop(context);
                  _showBlockConfirmation(context, currentUserId);
                },
              ),
              _buildOptionTile(
                context: context,
                icon: Icons.visibility_off_outlined,
                label: 'Not Interested',
                onTap: () {
                  Navigator.pop(context);
                  _markNotInterested(context, currentUserId);
                },
              ),
            ],

            _buildOptionTile(
              context: context,
              icon: Icons.repeat_outlined,
              label: 'Repost',
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Repost feature - Coming soon!')),
                );
              },
            ),

            _buildOptionTile(
              context: context,
              icon: Icons.bookmark_outline,
              label: 'Save',
              onTap: () {
                Navigator.pop(context);
                _savePost(context, currentUserId);
              },
            ),

            _buildOptionTile(
              context: context,
              icon: Icons.link_outlined,
              label: 'Copy Link',
              onTap: () {
                Navigator.pop(context);
                _copyLink(context);
              },
            ),

            _buildOptionTile(
              context: context,
              icon: Icons.share_outlined,
              label: 'Share to External',
              onTap: () {
                Navigator.pop(context);
                _shareExternal(context);
              },
            ),

            const SizedBox(height: 8),

            // Cancel button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF2C2C2C),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor ?? Colors.white,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: iconColor ?? Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.grey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // 🚨 REPORT FUNCTIONALITY
  void _showReportBottomSheet(BuildContext context, String? currentUserId) {
    if (currentUserId == null) return;

    final reasons = [
      {'title': 'Spam or Misleading', 'icon': Icons.report_outlined},
      {'title': 'Hate Speech or Harassment', 'icon': Icons.warning_outlined},
      {'title': 'Violence or Dangerous Organizations', 'icon': Icons.security_outlined},
      {'title': 'Nudity or Sexual Content', 'icon': Icons.no_adult_content},
      {'title': 'False Information', 'icon': Icons.info_outline},
      {'title': 'Something Else', 'icon': Icons.more_horiz},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Why are you reporting this post?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),

              const Divider(color: Color(0xFF2C2C2C), height: 1),

              // Reasons list
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: reasons.length,
                  itemBuilder: (context, index) {
                    final reason = reasons[index];
                    return InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _submitReport(context, currentUserId, reason['title'] as String);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Row(
                          children: [
                            Icon(
                              reason['icon'] as IconData,
                              color: const Color(0xFFFF3B5C),
                              size: 24,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                reason['title'] as String,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: Colors.grey,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitReport(BuildContext context, String currentUserId, String reason) async {
    try {
      final db = FirebaseFirestore.instance;

      // Check duplicate report
      final existingReport = await db
          .collection('reports')
          .where('postId', isEqualTo: postId)
          .where('reporterId', isEqualTo: currentUserId)
          .limit(1)
          .get();

      if (existingReport.docs.isNotEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You have already reported this post.'),
              backgroundColor: Color(0xFFFFA500),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Submit report
      await db.collection('reports').add({
        'postId': postId,
        'postOwnerId': postOwnerId,
        'postOwnerUsername': postOwnerUsername,
        'reporterId': currentUserId,
        'reason': reason,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'status': 'pending',
      });

      debugPrint('✅ Report submitted: $reason');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for reporting. We will review this soon.'),
            backgroundColor: Color(0xFF2C2C2C),
            duration: Duration(seconds: 3),
          ),
        );
      }

      onReported?.call();
    } catch (e) {
      debugPrint('❌ Error submitting report: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit report. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 🚫 BLOCK USER
  void _showBlockConfirmation(BuildContext context, String? currentUserId) {
    if (currentUserId == null) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Block this user?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'You won\'t see posts from @$postOwnerUsername anymore.',
            style: const TextStyle(color: Color(0xFFAAAAAA)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _blockUser(context, currentUserId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B5C),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Block', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _blockUser(BuildContext context, String currentUserId) async {
    try {
      final db = FirebaseFirestore.instance;

      await db.collection('blocked_users').doc('${currentUserId}_$postOwnerId').set({
        'blockerId': currentUserId,
        'blockedId': postOwnerId,
        'blockedUsername': postOwnerUsername,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      debugPrint('✅ User blocked: $postOwnerId');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Blocked @$postOwnerUsername'),
            backgroundColor: const Color(0xFF2C2C2C),
          ),
        );
      }

      onReported?.call();
    } catch (e) {
      debugPrint('❌ Error blocking user: $e');
    }
  }

  // 👁️ NOT INTERESTED
  Future<void> _markNotInterested(BuildContext context, String? currentUserId) async {
    if (currentUserId == null) return;

    try {
      final db = FirebaseFirestore.instance;

      await db.collection('not_interested').doc('${currentUserId}_$postId').set({
        'userId': currentUserId,
        'postId': postId,
        'postOwnerId': postOwnerId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      debugPrint('✅ Marked as not interested: $postId');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('We\'ll show you less of this'),
            backgroundColor: Color(0xFF2C2C2C),
          ),
        );
      }

      onReported?.call();
    } catch (e) {
      debugPrint('❌ Error marking not interested: $e');
    }
  }

  // 💾 SAVE POST
  Future<void> _savePost(BuildContext context, String? currentUserId) async {
    if (currentUserId == null) return;

    try {
      final db = FirebaseFirestore.instance;
      final savedRef = db.collection('saved_posts').doc('${currentUserId}_$postId');
      final savedDoc = await savedRef.get();

      if (savedDoc.exists) {
        await savedRef.delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Removed from saved')),
          );
        }
      } else {
        await savedRef.set({
          'userId': currentUserId,
          'postId': postId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved successfully')),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error saving post: $e');
    }
  }

  // 🔗 COPY LINK
  void _copyLink(BuildContext context) {
    final link = 'https://myvibe.app/post/$postId';
    Clipboard.setData(ClipboardData(text: link));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard'),
        backgroundColor: Color(0xFF2C2C2C),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 📤 SHARE EXTERNAL
  void _shareExternal(BuildContext context) {
    final shareText = 'Check out this post on MyVibe!\nhttps://myvibe.app/post/$postId';
    Share.share(shareText);
  }
}