import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_vibe_flick/screens/report_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';



class ShareBottomSheet extends StatefulWidget {
  final String postId;
  final String username;
  final String description;
  final String? thumbnailUrl;
  final bool isOwnPost;
  final String postOwnerId;
  final String postOwnerUsername;
  final String mediaUrl;
  final VoidCallback? onReported;
  final VoidCallback? onUndo;          // 🆕 ADD
  final List<String> hashtags;   // 🆕 post hashtags
  final String category;         // 🆕 post category

  const ShareBottomSheet({
    Key? key,
    required this.postId,
    required this.username,
    this.description = '',
    this.thumbnailUrl,
    this.isOwnPost = false,
    this.postOwnerId = '',
    this.postOwnerUsername = '',
    this.mediaUrl = '',
    this.onReported,
    this.onUndo,                        // 🆕 ADD
    this.hashtags = const [],   // 🆕
    this.category = '',         // 🆕

  }) : super(key: key);

  @override
  State<ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends State<ShareBottomSheet> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _friends = [];
  bool _isLoadingFriends = true;
  String? _currentUserId;
  bool _linkCopied = false;

  String get _postLink =>
      'https://vibeflick-5fe5c.web.app/post/${widget.postId}';

  String get _shareText =>
      widget.description.isNotEmpty
          ? '🎬 ${widget.username}: ${widget.description}\n\n$_postLink'
          : '🎬 Check out this post by ${widget.username}!\n\n$_postLink';

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid;
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    if (_currentUserId == null) {
      setState(() => _isLoadingFriends = false);
      return;
    }

    try {
      final followsSnap = await _db
          .collection('follows')
          .where('followerId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'active')
          .limit(15)
          .get();

      final friends = <Map<String, dynamic>>[];

      for (var doc in followsSnap.docs) {
        final data = doc.data();
        friends.add({
          'userId': data['followingId'] ?? '',
          'username': data['followingName'] ?? 'Unknown',
          'avatarUrl': '',
        });
      }

      if (mounted) {
        setState(() {
          _friends = friends;
          _isLoadingFriends = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading friends: $e');
      if (mounted) setState(() => _isLoadingFriends = false);
    }
  }

  Future<void> _sendToFriend(Map<String, dynamic> friend) async {
    if (_currentUserId == null) return;

    try {
      final friendUserId = friend['userId'] ?? '';
      final friendUsername = friend['username'] ?? 'Unknown';

      await _db.collection('direct_messages').add({
        'fromUserId': _currentUserId,
        'toUserId': friendUserId,
        'postId': widget.postId,
        'postLink': _postLink,
        'type': 'post_share',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isRead': false,
        'postCard': {
          'postId': widget.postId,
          'thumbnailUrl': widget.thumbnailUrl ?? '',
          'description': widget.description,
          'username': widget.username,
          'postLink': _postLink,
        },
      });

      final rtdb = FirebaseDatabase.instance.ref();
      final ids = [_currentUserId!, friendUserId]..sort();
      final chatRoomId = '${ids[0]}_${ids[1]}';
      final msgId = rtdb
          .child('chatRooms')
          .child(chatRoomId)
          .child('messages')
          .push()
          .key!;
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      await rtdb
          .child('chatRooms')
          .child(chatRoomId)
          .child('messages')
          .child(msgId)
          .set({
        'senderId': _currentUserId,
        'receiverId': friendUserId,
        'text': '',
        'type': 'post_share',
        'timestamp': timestamp,
        'isSeen': false,
        'postCard': {
          'postId': widget.postId,
          'thumbnailUrl': widget.thumbnailUrl ?? '',
          'description': widget.description,
          'username': widget.username,
          'postLink': _postLink,
        },
      });

      await rtdb
          .child('chatRooms')
          .child(chatRoomId)
          .child('info')
          .update({
        'lastMessage': '🎬 Shared a post',
        'lastTimestamp': timestamp,
        'participants': [_currentUserId, friendUserId],
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sent to @$friendUsername!'),
            backgroundColor: const Color(0xFF1E1E1E),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      debugPrint('✅ Post shared to: $friendUsername');
    } catch (e) {
      debugPrint('❌ Error sending to friend: $e');
    }
  }

  Future<void> _shareToExternal(String platform) async {
    try {
      await Share.share(_shareText);
      debugPrint('✅ Shared to: $platform');
    } catch (e) {
      debugPrint('❌ External share error: $e');
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _postLink));
    setState(() => _linkCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _linkCopied = false);
    });
    debugPrint('✅ Link copied: $_postLink');
  }

  Future<void> _incrementShareCount() async {
    try {
      await _db.collection('media_posts').doc(widget.postId).update({
        'shares_count': FieldValue.increment(1),
      });

      if (_currentUserId != null) {
        await _db.collection('activity_logs').add({
          'type': 'share',
          'userId': _currentUserId,
          'postId': widget.postId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
    } catch (e) {
      debugPrint('❌ Share count error: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // REPORT — UI (Bottom Sheet)
  // ════════════════════════════════════════════════════════════════════
  void _showReportBottomSheet() {
    if (_currentUserId == null) return;

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
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
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
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: reasons.length,
                  itemBuilder: (context, index) {
                    final reason = reasons[index];
                    return InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _submitReport(reason['title'] as String);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
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

  // ════════════════════════════════════════════════════════════════════
  // REPORT — Submit
  // ════════════════════════════════════════════════════════════════════
  Future<void> _submitReport(String reason) async {
    debugPrint('🔥 _submitReport called: $reason');
    final result = await ReportService.submitReport(
      postId            : widget.postId,
      postOwnerId       : widget.postOwnerId,
      postOwnerUsername : widget.postOwnerUsername,
      reason            : reason,
      mediaUrl          : widget.mediaUrl,
    );

    if (result.isDuplicate) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ඔබ මෙම පෝස්ට් එක දැනටමත් වාර්තා කර ඇත.'),
            backgroundColor: Color(0xFFFFA500),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    if (result.isError) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('වාර්තාව යැවීම අසාර්ථක විය. නැවත උත්සාහ කරන්න.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // ✅ SUCCESS: Post hide + Dialog පෙන්වනවා
    if (mounted) {
      // 1️⃣ Feed එකෙන් ඒ වෙලාවෙම hide කරනවා
      widget.onReported?.call();

      // 2️⃣ Success Dialog පෙන්වනවා
      _showReportSuccessDialog();
    }
  }

  // ✅ ADD: Report Success Dialog
  void _showReportSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          child: Container(
            padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Green Checkmark ──────────────────────────
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF22C55E).withOpacity(0.15),
                    border: Border.all(
                      color: const Color(0xFF22C55E),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF22C55E),
                    size: 44,
                  ),
                ),

                const SizedBox(height: 24),

                // ── Title ────────────────────────────────────
                const Text(
                  'ස්තූතියි!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 14),

                // ── Message ──────────────────────────────────
                const Text(
                  'ඔබේ වාර්තාව අප වෙත ලැබුණා. '
                      'VibeFlick ප්‍රජාව ආරක්ෂිතව තබා ගැනීමට '
                      'ඔබ දක්වන සහය අපි අගය කරමු. '
                      'අපගේ කණ්ඩායම මෙය ඉක්මනින් '
                      'සමාලෝචනය කරනු ඇත.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFFAAAAAA),
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 28),

                // ── Okay Button ──────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'හරි',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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


  // ════════════════════════════════════════════════════════════════════
  // BLOCK USER
  // ════════════════════════════════════════════════════════════════════
  void _showBlockConfirmation() {
    if (_currentUserId == null) return;

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
            'You won\'t see posts from @${widget.postOwnerUsername} anymore.',
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
                _blockUser();
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

  Future<void> _blockUser() async {
    if (_currentUserId == null) return;
    try {
      await _db
          .collection('blocked_users')
          .doc('${_currentUserId}_${widget.postOwnerId}')
          .set({
        'blockerId': _currentUserId,
        'blockedId': widget.postOwnerId,
        'blockedUsername': widget.postOwnerUsername,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      debugPrint('✅ User blocked: ${widget.postOwnerId}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Blocked @${widget.postOwnerUsername}'),
            backgroundColor: const Color(0xFF22C55E),
          ),
        );
      }

      widget.onReported?.call();
    } catch (e) {
      debugPrint('❌ Error blocking user: $e');
    }
  }

// ════════════════════════════════════════════════════════════════════
  // NOT INTERESTED
  // ════════════════════════════════════════════════════════════════════
  Future<void> _markNotInterested() async {
    if (_currentUserId == null) return;

    // 1️⃣ Sheet close + post hide — single pop
    if (mounted) Navigator.pop(context);
    widget.onReported?.call();

    // 2️⃣ ScaffoldMessenger — pop කරලාත් valid
    final messenger = ScaffoldMessenger.of(context);
    bool _undone = false;

    // 3️⃣ Snackbar show — DB write නෑ තවම
    final controller = messenger.showSnackBar(
      SnackBar(
        content: const Text(
          'Post hidden. We\'ll show you less of this.',
          style: TextStyle(color: Colors.white, fontSize: 13.5),
        ),
        backgroundColor: const Color(0xFF2C2C2C),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'Undo',
          textColor: const Color(0xFFFF3B5C),
          onPressed: () {
            _undone = true;
            widget.onUndo?.call(); // 🆕 UI restore only — DB write නෑ
          },
        ),
      ),
    );

    // 4️⃣ Snackbar close වෙනකොට — Undo නොකළොත් DB write
    controller.closed.then((_) async {
      if (!_undone) {
        await _writeNotInterestedToDb();
      }
    });
  }

  // ════════════════════════════════════════════════════════════════════
  // DB WRITE — Snackbar timeout/dismiss after no Undo
  // ════════════════════════════════════════════════════════════════════
  Future<void> _writeNotInterestedToDb() async {
    if (_currentUserId == null) return;
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;

      await _db
          .collection('not_interested')
          .doc('${_currentUserId}_${widget.postId}')
          .set({
        'userId'     : _currentUserId,
        'postId'     : widget.postId,
        'postOwnerId': widget.postOwnerId,
        'timestamp'  : ts,
      });

      if (widget.hashtags.isNotEmpty || widget.category.isNotEmpty) {
        await _db
            .collection('user_interests')
            .doc('${_currentUserId}_${widget.postId}')
            .set({
          'userId'    : _currentUserId,
          'postId'    : widget.postId,
          'type'      : 'not_interested',
          'hashtags'  : widget.hashtags,
          'category'  : widget.category,
          'creatorId' : widget.postOwnerId,
          'timestamp' : ts,
        });

        await _db.collection('users').doc(_currentUserId).update({
          'disliked_categories': FieldValue.arrayUnion([
            ...widget.hashtags,
            if (widget.category.isNotEmpty) widget.category,
          ]),
        });
      }

      debugPrint('✅ Not interested written to DB: ${widget.postId}');
    } catch (e) {
      debugPrint('❌ Error writing not interested: $e');
    }
  }

  // 🆕 UNDO — DB write නෑ, UI restore විතරක් (onUndo callback via widget)
  Future<void> _undoNotInterested() async {
    // DB write කරලා නෑ නිසා delete කරන්නත් දෙයක් නෑ
    // widget.onUndo?.call() — _markNotInterested() ඇතුළෙ handle වෙනවා
    debugPrint('↩️ Not interested undone (no DB operation needed)');
  }
  // ════════════════════════════════════════════════════════════════════
  // SAVE POST
  // ════════════════════════════════════════════════════════════════════
  Future<void> _savePost() async {
    if (_currentUserId == null) return;
    try {
      final savedRef = _db
          .collection('saved_posts')
          .doc('${_currentUserId}_${widget.postId}');
      final savedDoc = await savedRef.get();

      if (savedDoc.exists) {
        await savedRef.delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Removed from saved')),
          );
        }
      } else {
        await savedRef.set({
          'userId': _currentUserId,
          'postId': widget.postId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved successfully')),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error saving post: $e');
    }
  }

  Future<void> _handleRepost() async {
    if (_currentUserId == null) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      final repostRef = _db
          .collection('reposts')
          .doc('${_currentUserId}_${widget.postId}');

      final existing = await repostRef.get();

      if (existing.exists) {
        // ── UNDO REPOST ──────────────────────────────────────────
        await repostRef.delete();

        await _db.collection('media_posts').doc(widget.postId).update({
          'repost_count': FieldValue.increment(-1),
        });

        debugPrint('↩️ Repost removed');
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Repost removed'),
            backgroundColor: Color(0xFF1E1E1E),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        // ── NEW REPOST ───────────────────────────────────────────
        final currentUserDoc = await _db
            .collection('users')
            .doc(_currentUserId)
            .get();
        final currentUsername = currentUserDoc.data()?['name'] ?? 'User';

        // 1️⃣ Save repost doc
        await repostRef.set({
          'userId'           : _currentUserId,
          'username'         : currentUsername,
          'postId'           : widget.postId,
          'postOwnerId'      : widget.postOwnerId,
          'postOwnerUsername': widget.postOwnerUsername,
          'timestamp'        : DateTime.now().millisecondsSinceEpoch,
        });

        // 2️⃣ Increment repost count on original post
        await _db.collection('media_posts').doc(widget.postId).update({
          'repost_count': FieldValue.increment(1),
        });

        // 3️⃣ Notification to original creator
        if (widget.postOwnerId.isNotEmpty &&
            widget.postOwnerId != _currentUserId) {
          await _db
              .collection('users')
              .doc(widget.postOwnerId)
              .collection('notifications')
              .add({
            'type'        : 'repost',
            'fromUserId'  : _currentUserId,
            'fromUserName': currentUsername,
            'toUserId'    : widget.postOwnerId,
            'postId'      : widget.postId,
            'timestamp'   : DateTime.now().millisecondsSinceEpoch,
            'isRead'      : false,
          });
          debugPrint('🔔 Repost notification sent to: ${widget.postOwnerId}');
        }

        debugPrint('🔁 Reposted by: $currentUsername');
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Reposted to your followers!'),
            backgroundColor: Color(0xFF22C55E),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Repost error: $e');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // FAVORITES
  // ════════════════════════════════════════════════════════════════════
  Future<void> _handleAddToFavorites() async {
    if (_currentUserId == null) return;
    try {
      final favRef = _db
          .collection('favorites')
          .doc('${_currentUserId}_${widget.postId}');

      final existing = await favRef.get();

      if (existing.exists) {
        await favRef.delete();
        debugPrint('💔 Removed from favorites');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Removed from favorites'),
              backgroundColor: Color(0xFF1E1E1E),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        await favRef.set({
          'userId': _currentUserId,
          'postId': widget.postId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        debugPrint('⭐ Added to favorites');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Added to favorites!'),
              backgroundColor: Color(0xFF1E1E1E),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Favorites error: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          _buildFriendsRow(),
          const SizedBox(height: 20),
          Divider(color: Colors.grey[800], height: 1),
          const SizedBox(height: 20),
          _buildExternalAppsRow(),
          const SizedBox(height: 20),
          Divider(color: Colors.grey[800], height: 1),
          const SizedBox(height: 16),
          _buildActionButtons(),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildFriendsRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Send to',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 90,
          child: _isLoadingFriends
              ? const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFFF3B5C),
              strokeWidth: 2,
            ),
          )
              : _friends.isEmpty
              ? Center(
            child: Text(
              'Follow people to send posts!',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          )
              : ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _friends.length,
            itemBuilder: (context, index) =>
                _buildFriendItem(_friends[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildFriendItem(Map<String, dynamic> friend) {
    final username = friend['username'] ?? 'Unknown';
    final isSent = friend['sent'] == true;

    return GestureDetector(
      onTap: isSent
          ? null
          : () async {
        setState(() => friend['sent'] = true);
        await _sendToFriend(friend);
        await _incrementShareCount();
      },
      child: Container(
        width: 65,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSent
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFFF3B5C),
                border: Border.all(color: Colors.grey[800]!, width: 2),
              ),
              child: Center(
                child: isSent
                    ? const Icon(Icons.check, color: Colors.white, size: 24)
                    : Text(
                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isSent ? 'Sent' : username,
              style: TextStyle(
                color: isSent ? const Color(0xFF22C55E) : Colors.white,
                fontSize: 11,
                fontWeight: isSent ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExternalAppsRow() {
    final apps = [
      {'label': 'WhatsApp', 'icon': Icons.chat, 'color': const Color(0xFF25D366)},
      {'label': 'Facebook', 'icon': Icons.facebook, 'color': const Color(0xFF1877F2)},
      {'label': 'Instagram', 'icon': Icons.camera_alt, 'color': const Color(0xFFE1306C)},
      {'label': 'Copy Link', 'icon': Icons.link, 'color': const Color(0xFF555555)},
      {'label': 'More', 'icon': Icons.more_horiz, 'color': const Color(0xFF333333)},
    ];

    return SizedBox(
      height: 85,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: apps.length,
        itemBuilder: (context, index) {
          final app = apps[index];
          final isCopyLink = app['label'] == 'Copy Link';
          final isMore = app['label'] == 'More';

          return GestureDetector(
            onTap: () {
              if (isCopyLink) {
                _copyLink();
              } else if (isMore) {
                _shareToExternal('system');
              } else {
                _shareToExternal(app['label'] as String);
              }
            },
            child: Container(
              width: 65,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isCopyLink && _linkCopied
                          ? const Color(0xFF4CAF50)
                          : (app['color'] as Color),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isCopyLink && _linkCopied
                          ? Icons.check
                          : (app['icon'] as IconData),
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isCopyLink && _linkCopied ? 'Copied!' : app['label'] as String,
                    style: TextStyle(
                      color: isCopyLink && _linkCopied
                          ? const Color(0xFF4CAF50)
                          : Colors.white,
                      fontSize: 11,
                      fontWeight: isCopyLink && _linkCopied
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (!widget.isOwnPost)
            _buildActionTile(
              icon: Icons.repeat_rounded,
              label: 'Repost',
              onTap: () async {
                Navigator.pop(context);
                await _handleRepost();
              },
            ),
          _buildActionTile(
            icon: Icons.bookmark_outline,
            label: 'Save Video',
            onTap: () {
              Navigator.pop(context);
              _savePost();
            },
          ),
          if (!widget.isOwnPost)
            _buildActionTile(
              icon: Icons.favorite_border_rounded,
              label: 'Add to Favorites',
              onTap: () async {
                Navigator.pop(context);
                await _handleAddToFavorites();
              },
            ),
          if (!widget.isOwnPost)
            _buildActionTile(
              icon: Icons.visibility_off_outlined,
              label: 'Not Interested',
              onTap: () => _markNotInterested(),
            ),
          if (!widget.isOwnPost)
            _buildActionTile(
              icon: Icons.block_outlined,
              label: 'Block @${widget.postOwnerUsername}',
              isDestructive: true,
              onTap: () {
                Navigator.pop(context);
                _showBlockConfirmation();
              },
            ),
          if (!widget.isOwnPost)
            _buildActionTile(
              icon: Icons.flag_outlined,
              label: 'Report',
              isDestructive: true,
              onTap: () {
                Navigator.pop(context);
                _showReportBottomSheet();
              },
            ),
          if (widget.isOwnPost)
            _buildActionTile(
              icon: Icons.delete_outline,
              label: 'Delete Post',
              isDestructive: true,
              onTap: () {
                Navigator.pop(context);
                debugPrint('Delete tapped');
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[850]!, width: 1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? const Color(0xFFFF3B5C) : Colors.white,
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isDestructive ? const Color(0xFFFF3B5C) : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}