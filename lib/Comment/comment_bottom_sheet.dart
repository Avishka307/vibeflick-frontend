import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/svg.dart';
import 'dart:ui';
import '../screens/stickers_screen.dart';
import 'package:http/http.dart' as http;
import '../screens/emoji_picker_screen.dart';
import 'comment_report_service.dart'; // ← මේකත් add කරන්න

// ============================================================
// Backend Configuration
// ============================================================
class BackendConfig {
  static const String BACKEND_URL = "https://avishka-tiktok-api.zeabur.app";
}

// ============================================================
// FIX 1: EDIT_TIME_LIMIT_MINUTES - empty class වෙනුවට top-level constant
// ============================================================
const int EDIT_TIME_LIMIT_MINUTES = 5;

// ============================================================
// FIX 2: CommentSortType enum - class inside නොව top-level declaration
// ============================================================
enum CommentSortType {
  newest,
  oldest,
  topLiked,
}

// ============================================================
// FIX 3: Comment class - comment field non-final (edit සඳහා)
// ============================================================
class Comment {
  final String id;
  final String username;
  final String avatarUrl;
  String comment; // FIX: final ඉවත් කළා - edit mode සඳහා mutable විය යුතුයි
  final DateTime timestamp;
  int likes;
  bool isLiked;
  bool isEdited;
  List<Comment> replies;
  final String userId;

  Comment({
    required this.id,
    required this.username,
    required this.avatarUrl,
    required this.comment,
    required this.timestamp,
    this.likes = 0,
    this.isLiked = false,
    this.isEdited = false,
    List<Comment>? replies,
    required this.userId,
  }) : replies = replies ?? [];

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? 'Unknown',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      comment: json['comment'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      isLiked: false,
      isEdited: json['isEdited'] as bool? ?? false,
      replies: [],
      userId: json['userId'] as String? ?? '',
    );
  }
}


// ============================================================
// CommentBottomSheet Widget
// ============================================================
class CommentBottomSheet extends StatefulWidget {
  final String postId;
  final String postOwnerId;
  final int initialCommentCount;
  final String collectionName; // 🆕 ADD
  const CommentBottomSheet({
    Key? key,
    required this.postId,
    required this.postOwnerId,
    this.initialCommentCount = 0,
    this.collectionName = 'media_posts', // 🆕 ADD (default = media_posts)

  }) : super(key: key);

  @override
  State<CommentBottomSheet> createState() => _CommentBottomSheetState();
}

class _CommentBottomSheetState extends State<CommentBottomSheet>
    with TickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final DraggableScrollableController _sheetController =
  DraggableScrollableController();

  List<Comment> comments = [];
  bool isLoading = true;
  bool isReplying = false;
  bool isSending = false;
  Comment? replyingTo;
  int characterCount = 0;

  Map<String, bool> expandedReplies = {};
  Map<String, bool> expandedComments = {};
  String? _currentUserId;
  DateTime? _lastCommentTime;
  String? _lastCommentText;

  // Dislike tracking
  Map<String, bool> _dislikedComments = {};

  // Feature 2-10 සඳහා variables
  bool _isEditMode = false;
  Comment? _editingComment;
  Map<String, String> _commentReactions = {};
  List<String> _mentionedUsers = [];
  bool _showMentionSuggestions = false;
  List<Map<String, String>> _mentionSuggestions = [];

  TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;
  String _searchQuery = '';
  Set<String> _pinnedCommentIds = {};
  List<Map<String, dynamic>> _offlineQueue = [];
  bool _isOnline = true;
  bool _showOfflineBanner = false;

  // FIX 4: Missing declarations
  CommentSortType _currentSortType = CommentSortType.newest;
  StreamSubscription? _connectivitySubscription;

// Pagination සඳහා
  static const int _pageSize = 5;
  DocumentSnapshot? _lastDocument;
  bool _hasMoreComments = true;
  bool _isLoadingMore = false;
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;


  // Reply pagination
  Map<String, int> _replyLoadedCount = {};
  Map<String, bool> _replyLoadingMore = {};
  static const int _replyPageSize = 3;

// GIF/Sticker

  String _gifSearchQuery = '';
  List<Map<String, dynamic>> _gifResults = [];
  bool _isSearchingGifs = false;
  static const String _giphyApiKey = 'YOUR_GIPHY_API_KEY'; // Giphy API key දාන්න
  bool _showEmojiPicker = false;
  TextEditingController _emojiSearchController = TextEditingController();
  // Reaction types for comment reactions
  final List<Map<String, dynamic>> reactionTypes = [
    {'emoji': '❤️', 'label': 'Love', 'key': 'love'},
    {'emoji': '😂', 'label': 'Haha', 'key': 'haha'},
    {'emoji': '😮', 'label': 'Wow', 'key': 'wow'},
    {'emoji': '😢', 'label': 'Sad', 'key': 'sad'},
    {'emoji': '😡', 'label': 'Angry', 'key': 'angry'},
  ];

  // FIX 5: Missing quickReactions list
  final List<Map<String, dynamic>> quickReactions = [
    {'emoji': '❤️', 'label': 'Love'},
    {'emoji': '🔥', 'label': 'Fire'},
    {'emoji': '😂', 'label': 'Haha'},
    {'emoji': '😮', 'label': 'Wow'},
    {'emoji': '👏', 'label': 'Clap'},
    {'emoji': '💯', 'label': '100'},
  ];

  // ============================================================
  // Check if comment can be edited (within 5 minutes)
  // ============================================================
  bool _canEditComment(Comment comment) {
    if (comment.userId != _currentUserId) return false;
    final timeSincePost = DateTime.now().difference(comment.timestamp);
    return timeSincePost.inMinutes < EDIT_TIME_LIMIT_MINUTES;
  }

  // ============================================================
  // FIX 6: Single initState() - updated version with @mention listener + connectivity
  // ============================================================
  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid;

    _debugCurrentUserInfo();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    // @MENTIONS listener
    _commentController.addListener(() {
      _onCommentTextChanged(_commentController.text);
    });

    // Check connectivity on start
    _checkConnectivity();

    _loadComments();
  }

  // ============================================================
  // FIX 7: Single dispose() - updated version with _searchController + _connectivitySubscription
  // ============================================================
  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    _scrollController.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    _sheetController.dispose();

    _searchController.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  // ============================================================
  // Debug Current User Info
  // ============================================================
  void _debugCurrentUserInfo() {
    debugPrint('\n🔍 ========== DEBUG USER INFO ==========');

    final user = _auth.currentUser;

    debugPrint('📱 Firebase Auth User:');
    debugPrint('   UID: ${user?.uid ?? "NULL"}');
    debugPrint('   Email: ${user?.email ?? "NULL"}');
    debugPrint('   Display Name: ${user?.displayName ?? "NULL"}');
    debugPrint('   Photo URL: ${user?.photoURL ?? "NULL"}');
    debugPrint('   Email Verified: ${user?.emailVerified ?? false}');

    debugPrint('\n📊 Local State:');
    debugPrint('   _currentUserId: $_currentUserId');
    debugPrint('   Post ID: ${widget.postId}');
    debugPrint('   Post Owner ID: ${widget.postOwnerId}');
    debugPrint('   Initial Comment Count: ${widget.initialCommentCount}');

    debugPrint('\n🌐 Backend Config:');
    debugPrint('   Backend URL: ${BackendConfig.BACKEND_URL}');
    debugPrint(
        '   Comment Endpoint: ${BackendConfig.BACKEND_URL}/api/posts/${widget
            .postId}/comments');

    debugPrint('==========================================\n');
  }

  // ============================================================
  // Post Comment to Backend
  // ============================================================
  Future<void> _postCommentToBackend(String commentText) async {
    if (_currentUserId == null) {
      debugPrint('❌ Cannot post comment - user not logged in');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to comment'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      final user = _auth.currentUser;

      // අලුත් (replace කරන්න):
      String username = await _getUsernameFromFirestore();

      final trimmedComment = commentText.trim();
      if (trimmedComment.isEmpty) {
        debugPrint('❌ Comment is empty after trimming');
        return;
      }

      if (trimmedComment.length > 500) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comment is too long (max 500 characters)'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final avatarUrl = user?.photoURL ?? '';

      final tempId = 'temp_${DateTime
          .now()
          .millisecondsSinceEpoch}';
      final optimisticComment = Comment(
        id: tempId,
        username: username,
        avatarUrl: avatarUrl,
        comment: trimmedComment,
        timestamp: DateTime.now(),
        likes: 0,
        isLiked: false,
        replies: [],
        userId: _currentUserId!,
      );

      setState(() {
        comments.insert(0, optimisticComment);
      });

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }

      debugPrint('\n💬 ========== POST COMMENT REQUEST ==========');
      debugPrint('🌐 Posting comment to backend...');
      debugPrint(
          '   URL: ${BackendConfig.BACKEND_URL}/api/posts/${widget
              .postId}/comments');
      debugPrint('   User ID: $_currentUserId');
      debugPrint('   Username: $username');
      debugPrint(
          '   Comment preview: "${trimmedComment.substring(0,
              trimmedComment.length > 50 ? 50 : trimmedComment.length)}..."');

      final requestBody = {
        'userId': _currentUserId!,
        'username': username,
        'comment': trimmedComment,
        'avatarUrl': avatarUrl,
      };

      final response = await http.post(
        Uri.parse(
            '${BackendConfig.BACKEND_URL}/api/posts/${widget.postId}/comments'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      );

      debugPrint('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final realCommentId = data['data']['commentId'];

        debugPrint('✅ Comment posted successfully');
        debugPrint('   Comment ID: $realCommentId');

        setState(() {
          final index = comments.indexWhere((c) => c.id == tempId);
          if (index != -1) {
            comments[index] = Comment(
              id: realCommentId,
              username: username,
              avatarUrl: avatarUrl,
              comment: trimmedComment,
              timestamp: DateTime.now(),
              likes: 0,
              isLiked: false,
              replies: [],
              userId: _currentUserId!,
            );
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comment posted! 💬'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        }
      } else {
        debugPrint('❌ Failed to post comment - Status: ${response.statusCode}');

        setState(() {
          comments.removeWhere((c) => c.id == tempId);
        });

        if (mounted) {
          String errorMessage = 'Failed to post comment';

          if (response.statusCode == 400) {
            try {
              final errorData = json.decode(response.body);
              errorMessage = errorData['message'] ?? errorMessage;
            } catch (e) {
              // ignore
            }
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('\n❌ ========== EXCEPTION OCCURRED ==========');
      debugPrint('Error: $e');
      debugPrint('Stack Trace: $stackTrace');

      setState(() {
        comments.removeWhere((c) => c.id.startsWith('temp_'));
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to post comment. Check your connection.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _loadReplies(Comment parentComment) async {
    try {
      final response = await http.get(
        Uri.parse(
            '${BackendConfig.BACKEND_URL}/api/posts/${widget
                .postId}/comments/${parentComment.id}/replies'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List repliesJson = data['data'] ?? [];
          final replies = repliesJson
              .map((r) =>
              Comment.fromJson({
                ...Map<String, dynamic>.from(r),
                'id': r['id'] ?? r['replyId'] ?? '',
              }))
              .toList();

          setState(() {
            final idx = comments.indexWhere((c) => c.id == parentComment.id);
            if (idx != -1) {
              comments[idx].replies = replies;
            }
          });

          debugPrint(
              '✅ Loaded ${replies.length} replies for comment ${parentComment
                  .id}');
        }
      } else {
        debugPrint('❌ Load replies failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Load replies error: $e');
    }
  }

  Future<void> _postReplyToBackend(String replyText,
      Comment parentComment) async {
    if (_currentUserId == null) return;

    try {
      final username = await _getUsernameFromFirestore();
      final avatarUrl = _auth.currentUser?.photoURL ?? '';
      final tempId = 'temp_reply_${DateTime
          .now()
          .millisecondsSinceEpoch}';

      final optimisticReply = Comment(
        id: tempId,
        username: username,
        avatarUrl: avatarUrl,
        comment: replyText.trim(),
        timestamp: DateTime.now(),
        likes: 0,
        isLiked: false,
        replies: [],
        userId: _currentUserId!,
      );

      // Optimistic UI — locally add reply under parent comment
      setState(() {
        final idx = comments.indexWhere((c) => c.id == parentComment.id);
        if (idx != -1) {
          comments[idx].replies.insert(0, optimisticReply);
        }
      });

      final response = await http.post(
        Uri.parse(
            '${BackendConfig.BACKEND_URL}/api/posts/${widget
                .postId}/comments/${parentComment.id}/reply'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: json.encode({
          'userId': _currentUserId!,
          'username': username,
          'comment': replyText.trim(),
          'avatarUrl': avatarUrl,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final realReplyId = data['data']['replyId'] ??
            data['data']['commentId'];

        // temp reply remove කරන්න
        setState(() {
          final idx = comments.indexWhere((c) => c.id == parentComment.id);
          if (idx != -1) {
            comments[idx].replies.removeWhere((r) => r.id == tempId);
          }
        });

        // Backend එකෙන් fresh replies load කරන්න
        await _loadReplies(parentComment);
        debugPrint('✅ Reply posted: $realReplyId');
      } else {
        // Revert optimistic reply on failure
        setState(() {
          final idx = comments.indexWhere((c) => c.id == parentComment.id);
          if (idx != -1) {
            comments[idx].replies.removeWhere((r) => r.id == tempId);
          }
        });
        debugPrint('❌ Reply failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Reply error: $e');
      setState(() {
        final idx = comments.indexWhere((c) => c.id == parentComment.id);
        if (idx != -1) {
          comments[idx].replies.removeWhere((r) =>
              r.id.startsWith('temp_reply_'));
        }
      });
    }
  }

  Future<void> _openGifPicker() async {
    final selectedGif = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          SizedBox(
            height: MediaQuery
                .of(context)
                .size
                .height * 0.75,
            child: const StickersScreen(),
          ),
    );

    if (selectedGif != null && selectedGif.isNotEmpty) {
      setState(() => isSending = true);
      await _postCommentToBackend('[GIF]$selectedGif');
      setState(() => isSending = false);
    }
  }

  Future<String> _getUsernameFromFirestore() async {
    if (_currentUserId == null) return 'User';
    try {
      final doc = await _db.collection('users').doc(_currentUserId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final username = data['username'] as String? ??
            data['displayName'] as String? ??
            data['name'] as String?;
        if (username != null && username
            .trim()
            .isNotEmpty) {
          return username.trim();
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to get username from Firestore: $e');
    }
    // Firestore එකෙ නැත්නම් Auth fallback
    final user = _auth.currentUser;
    final authName = user?.displayName?.trim();
    if (authName != null && authName.isNotEmpty) return authName;
    return 'User';
  }

  // ============================================================
  // FEATURE 2: EDIT COMMENT METHODS
  // ============================================================

  /// Cancel edit mode
  void _cancelEdit() {
    setState(() {
      _isEditMode = false;
      _editingComment = null;
      _commentController.clear();
    });
    debugPrint('❌ Cancelled edit mode');
  }

  // FIX 8: Missing _startEditComment method
  void _startEditComment(Comment comment) {
    setState(() {
      _isEditMode = true;
      _editingComment = comment;
      _commentController.text = comment.comment;
      _commentController.selection = TextSelection.fromPosition(
        TextPosition(offset: comment.comment.length),
      );
    });
    _commentFocusNode.requestFocus();
    debugPrint('✏️ Started editing comment: ${comment.id}');
  }

  /// Save edited comment
  Future<void> _saveEditedComment() async {
    if (_editingComment == null || _currentUserId == null) return;

    final editedText = _commentController.text.trim();

    if (editedText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comment cannot be empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (editedText == _editingComment!.comment) {
      _cancelEdit();
      return;
    }

    try {
      debugPrint('\n✏️ ========== EDITING COMMENT ==========');
      debugPrint('   Comment ID: ${_editingComment!.id}');
      debugPrint('   New text: $editedText');

      // Update in Firestore
      await _db
          .collection('media_posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(_editingComment!.id)
          .update({
        'comment': editedText,
        'isEdited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });

      // Update locally
      setState(() {
        final index = comments.indexWhere((c) => c.id == _editingComment!.id);
        if (index != -1) {
          comments[index].comment = editedText;
          comments[index].isEdited = true;
        }
      });

      _cancelEdit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment updated ✏️'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }

      debugPrint('✅ Comment edited successfully');
      debugPrint('==========================================\n');
    } catch (e, stackTrace) {
      debugPrint('\n❌ ========== EDIT ERROR ==========');
      debugPrint('Error: $e');
      debugPrint('Stack Trace: $stackTrace');
      debugPrint('==========================================\n');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to edit comment'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============================================================
  // FEATURE 3: COMMENT REACTIONS METHODS
  // ============================================================

  /// Show reaction picker for a comment
  void _showReactionPicker(Comment comment) {
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          Container(
            decoration: BoxDecoration(
              color: Color(0xFF2A2A2A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: EdgeInsets.only(top: 10, bottom: 15),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Text(
                      'React to comment',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: reactionTypes.map((reaction) {
                        final isSelected =
                            _commentReactions[comment.id] == reaction['key'];
                        return InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _toggleReaction(comment, reaction['key']);
                          },
                          borderRadius: BorderRadius.circular(50),
                          child: Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.blue.withOpacity(0.2)
                                  : Colors.grey[800],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                isSelected ? Colors.blue : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              reaction['emoji'],
                              style: TextStyle(fontSize: 28),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  SizedBox(height: 10),
                ],
              ),
            ),
          ),
    );
  }

  /// Toggle reaction on a comment
  Future<void> _toggleReaction(Comment comment, String reactionKey) async {
    if (_currentUserId == null) return;

    HapticFeedback.lightImpact();

    final previousReaction = _commentReactions[comment.id];

    setState(() {
      if (previousReaction == reactionKey) {
        _commentReactions.remove(comment.id);
      } else {
        _commentReactions[comment.id] = reactionKey;
      }
    });

    try {
      // Update in Firestore
      await _db
          .collection('media_posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(comment.id)
          .collection('reactions')
          .doc(_currentUserId)
          .set({
        'reactionType':
        previousReaction == reactionKey ? null : reactionKey,
        'userId': _currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint(
          '${previousReaction == reactionKey
              ? "❌"
              : "✅"} Reaction toggled: $reactionKey');
    } catch (e) {
      debugPrint('❌ Failed to save reaction: $e');
    }
  }

  // ============================================================
  // FEATURE 4: @MENTION SUPPORT METHODS
  // ============================================================

  /// Detect @mentions in text
  void _onCommentTextChanged(String text) {
    setState(() {
      characterCount = text.length;
    });

    // Check for @ symbol
    final lastAtIndex = text.lastIndexOf('@');
    if (lastAtIndex != -1 && lastAtIndex == text.length - 1) {
      _loadMentionSuggestions();
    } else if (lastAtIndex != -1) {
      final searchTerm = text.substring(lastAtIndex + 1);
      if (searchTerm.contains(' ')) {
        setState(() => _showMentionSuggestions = false);
      } else {
        _filterMentionSuggestions(searchTerm);
      }
    } else {
      setState(() => _showMentionSuggestions = false);
    }
  }

  /// Load users for mention suggestions
  Future<void> _loadMentionSuggestions() async {
    try {
      final usersSnapshot =
      await _db.collection('users').limit(10).get();

      final suggestions = usersSnapshot.docs
          .map((doc) =>
      {
        'username': doc.data()['username'] as String? ?? 'User',
        'userId': doc.id,
      })
          .toList();

      setState(() {
        _mentionSuggestions = suggestions;
        _showMentionSuggestions = true;
      });
    } catch (e) {
      debugPrint('❌ Failed to load mention suggestions: $e');
    }
  }

  /// Filter mention suggestions based on search term
  void _filterMentionSuggestions(String searchTerm) {
    if (searchTerm.isEmpty) {
      setState(() => _showMentionSuggestions = true);
      return;
    }

    final filtered = _mentionSuggestions
        .where((user) =>
        user['username']!
            .toLowerCase()
            .contains(searchTerm.toLowerCase()))
        .toList();

    setState(() {
      _mentionSuggestions = filtered;
      _showMentionSuggestions = filtered.isNotEmpty;
    });
  }

  /// Insert mention into comment
  void _insertMention(String username, String userId) {
    final text = _commentController.text;
    final lastAtIndex = text.lastIndexOf('@');

    if (lastAtIndex != -1) {
      final newText = text.substring(0, lastAtIndex) + '@$username ';
      _commentController.text = newText;
      _commentController.selection = TextSelection.fromPosition(
        TextPosition(offset: newText.length),
      );

      if (!_mentionedUsers.contains(userId)) {
        _mentionedUsers.add(userId);
      }
    }

    setState(() => _showMentionSuggestions = false);
    HapticFeedback.selectionClick();
  }

  /// Send notification to mentioned users
  Future<void> _sendMentionNotifications(String commentId) async {
    for (final userId in _mentionedUsers) {
      try {
        await _db.collection('notifications').add({
          'type': 'mention',
          'recipientId': userId,
          'senderId': _currentUserId,
          'postId': widget.postId,
          'commentId': commentId,
          'message': 'mentioned you in a comment',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      } catch (e) {
        debugPrint('❌ Failed to send mention notification to $userId: $e');
      }
    }
    _mentionedUsers.clear();
  }

  // ============================================================
  // FEATURE 5: COMMENT SORTING METHODS
  // ============================================================

  /// Sort comments based on selected type
  void _sortComments() {
    setState(() {
      switch (_currentSortType) {
        case CommentSortType.newest:
          comments.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          break;
        case CommentSortType.oldest:
          comments.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          break;
        case CommentSortType.topLiked:
          comments.sort((a, b) => b.likes.compareTo(a.likes));
          break;
      }
    });

    debugPrint('🔀 Comments sorted by: $_currentSortType');
  }

  /// Show sort options dialog
  void _showSortOptions() {
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          Container(
            decoration: BoxDecoration(
              color: Color(0xFF2A2A2A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: EdgeInsets.only(top: 10, bottom: 15),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 10, 20, 20),
                    child: Row(
                      children: [
                        Icon(Icons.sort, color: Colors.blue, size: 24),
                        SizedBox(width: 10),
                        Text(
                          'Sort Comments',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildSortOption(
                    icon: Icons.new_releases_outlined,
                    title: 'Newest First',
                    isSelected: _currentSortType == CommentSortType.newest,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentSortType = CommentSortType.newest);
                      _sortComments();
                    },
                  ),
                  Divider(height: 1, color: Colors.grey[800]),
                  _buildSortOption(
                    icon: Icons.history,
                    title: 'Oldest First',
                    isSelected: _currentSortType == CommentSortType.oldest,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentSortType = CommentSortType.oldest);
                      _sortComments();
                    },
                  ),
                  Divider(height: 1, color: Colors.grey[800]),
                  _buildSortOption(
                    icon: Icons.favorite,
                    title: 'Top Liked',
                    isSelected: _currentSortType == CommentSortType.topLiked,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() =>
                      _currentSortType = CommentSortType.topLiked);
                      _sortComments();
                    },
                  ),
                  SizedBox(height: 15),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildSortOption({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected ? Colors.blue : Colors.grey[400], size: 22),
            SizedBox(width: 15),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? Colors.blue : Colors.white,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: Colors.blue, size: 20),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FEATURE 7: SEARCH & FILTER METHODS
  // ============================================================

  /// Toggle search bar visibility
  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
  }

  /// Filter comments based on search query
  void _filterComments(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  /// Get filtered comments list
  List<Comment> get _getFilteredComments {
    if (_searchQuery.isEmpty) {
      return comments;
    }

    return comments.where((comment) {
      return comment.comment.toLowerCase().contains(_searchQuery) ||
          comment.username.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  // ============================================================
  // FEATURE 8: PIN COMMENTS METHODS
  // ============================================================

  /// Toggle pin status of a comment
  Future<void> _togglePinComment(Comment comment) async {
    if (_currentUserId != widget.postOwnerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only post owner can pin comments'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final isPinned = _pinnedCommentIds.contains(comment.id);

      // Update in Firestore
      await _db
          .collection('media_posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(comment.id)
          .update({
        'isPinned': !isPinned,
        'pinnedAt': !isPinned ? FieldValue.serverTimestamp() : null,
      });

      setState(() {
        if (isPinned) {
          _pinnedCommentIds.remove(comment.id);
        } else {
          _pinnedCommentIds.add(comment.id);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isPinned ? 'Comment unpinned' : 'Comment pinned 📌'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }

      debugPrint(
          '${isPinned ? "📍" : "📌"} Comment ${isPinned
              ? "un"
              : ""}pinned: ${comment.id}');
    } catch (e) {
      debugPrint('❌ Failed to pin comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to pin comment'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============================================================
  // FEATURE 9: OFFLINE QUEUE METHODS
  // ============================================================

  /// Add comment to offline queue
  void _addToOfflineQueue(String commentText) {
    final queueItem = {
      'commentText': commentText,
      'timestamp': DateTime.now().toIso8601String(),
      'userId': _currentUserId,
      'username': _auth.currentUser?.displayName ?? 'User',
      'avatarUrl': _auth.currentUser?.photoURL ?? '',
    };

    setState(() {
      _offlineQueue.add(queueItem);
    });

    debugPrint('📴 Added to offline queue: ${queueItem['commentText']}');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.cloud_off, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                    'No connection. Comment will be sent when online.'),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  /// Process offline queue when connection restored
  Future<void> _processOfflineQueue() async {
    if (_offlineQueue.isEmpty) return;

    debugPrint(
        '📤 Processing offline queue: ${_offlineQueue.length} items');

    for (final item in List.from(_offlineQueue)) {
      try {
        final text = item['commentText'] as String;
        if (isReplying && replyingTo != null) {
          final parent = replyingTo!;
          _cancelReply();
          await _postReplyToBackend(text, parent);
        } else {
          await _postCommentToBackend(text);
        }
        setState(() {
          _offlineQueue.remove(item);
        });
        debugPrint('✅ Sent queued comment: ${item['commentText']}');
      } catch (e) {
        debugPrint('❌ Failed to send queued comment: $e');
        break; // Stop processing if one fails
      }
    }

    if (_offlineQueue.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All offline comments sent successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Check internet connectivity
  Future<void> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      final wasOffline = !_isOnline;

      setState(() {
        _isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
        _showOfflineBanner = !_isOnline;
      });

      if (_isOnline && wasOffline) {
        debugPrint('🌐 Connection restored');
        await _processOfflineQueue();
      }
    } catch (e) {
      setState(() {
        _isOnline = false;
        _showOfflineBanner = true;
      });
      debugPrint('📴 No internet connection');
    }
  }

  Widget _buildOfflineBanner() {
    if (!_showOfflineBanner) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.red[900],
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.red[300], size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No internet connection. Messaging is disabled.',
              style: TextStyle(color: Colors.red[200], fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: _checkConnectivity,
            child: Icon(Icons.refresh, color: Colors.red[300], size: 18),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FEATURE 10: COMMENT ANALYTICS METHODS (POST OWNER ONLY)
  // ============================================================

  /// Show analytics for post owner
  Future<void> _showCommentAnalytics() async {
    if (_currentUserId != widget.postOwnerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only post owner can view analytics'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Calculate analytics
    final totalComments = comments.fold<int>(
      0,
          (sum, comment) => sum + 1 + comment.replies.length,
    );

    final Map<String, int> userCommentCount = {};
    for (final comment in comments) {
      userCommentCount[comment.username] =
          (userCommentCount[comment.username] ?? 0) + 1;
      for (final reply in comment.replies) {
        userCommentCount[reply.username] =
            (userCommentCount[reply.username] ?? 0) + 1;
      }
    }

    final topCommenters = userCommentCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final avgResponseTime = _calculateAverageResponseTime();
    final sentiment = _analyzeSentiment();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          Container(
            height: MediaQuery
                .of(context)
                .size
                .height * 0.7,
            decoration: BoxDecoration(
              color: Color(0xFF2A2A2A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Container(
                    margin: EdgeInsets.only(top: 10, bottom: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(Icons.analytics_outlined,
                            color: Colors.blue, size: 24),
                        SizedBox(width: 10),
                        Text(
                          'Comment Analytics',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        _buildAnalyticCard(
                          icon: Icons.comment,
                          title: 'Total Comments',
                          value: totalComments.toString(),
                          color: Colors.blue,
                        ),
                        SizedBox(height: 15),
                        _buildAnalyticCard(
                          icon: Icons.people,
                          title: 'Most Active Commenter',
                          value: topCommenters.isNotEmpty
                              ? '${topCommenters.first.key} (${topCommenters
                              .first.value})'
                              : 'N/A',
                          color: Colors.green,
                        ),
                        SizedBox(height: 15),
                        _buildAnalyticCard(
                          icon: Icons.timer,
                          title: 'Avg Response Time',
                          value: avgResponseTime,
                          color: Colors.orange,
                        ),
                        SizedBox(height: 15),
                        _buildAnalyticCard(
                          icon: Icons.sentiment_satisfied,
                          title: 'Sentiment',
                          value: sentiment,
                          color: Colors.purple,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildAnalyticCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[400],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _calculateAverageResponseTime() {
    if (comments.length < 2) return 'N/A';

    int totalMinutes = 0;
    int count = 0;

    for (int i = 1; i < comments.length; i++) {
      final diff =
      comments[i - 1].timestamp.difference(comments[i].timestamp);
      totalMinutes += diff.inMinutes.abs();
      count++;
    }

    if (count == 0) return 'N/A';

    final avgMinutes = totalMinutes ~/ count;
    if (avgMinutes < 60) {
      return '$avgMinutes min';
    } else {
      final hours = avgMinutes ~/ 60;
      return '$hours hr';
    }
  }

  String _analyzeSentiment() {
    if (comments.isEmpty) return 'N/A';

    // Simple sentiment analysis based on keywords
    int positive = 0;
    int negative = 0;

    final positiveWords = [
      'good', 'great', 'awesome', 'love', 'nice', 'amazing', '❤️', '😍', '🔥'
    ];
    final negativeWords = [
      'bad', 'hate', 'terrible', 'awful', 'poor', '😡', '😢'
    ];

    for (final comment in comments) {
      final text = comment.comment.toLowerCase();

      for (final word in positiveWords) {
        if (text.contains(word)) positive++;
      }

      for (final word in negativeWords) {
        if (text.contains(word)) negative++;
      }
    }

    if (positive > negative) {
      return 'Mostly Positive 😊';
    } else if (negative > positive) {
      return 'Mostly Negative 😔';
    } else {
      return 'Neutral 😐';
    }
  }
// ✅ Comment visibility check — shadow hide + global hide
  bool _isCommentVisible(Map<String, dynamic> commentData) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isHidden   = commentData['is_hidden'] == true;
    final shadowList = List<String>.from(
      commentData['shadow_reported_by'] ?? [],
    );
    // globally hidden → hide for all
    if (isHidden) return false;
    // shadow flagged by current user → hide only for them
    if (currentUid != null && shadowList.contains(currentUid)) return false;
    return true;
  }
  // ============================================================
  // SPAM DETECTION
  // ============================================================
  bool _isSpamComment(String text) {
    // Empty check
    if (text
        .trim()
        .isEmpty) return true;

    // Check for repeated characters (e.g., "aaaaaaa")
    final repeatedCharPattern = RegExp(r'(.)\1{5,}');
    if (repeatedCharPattern.hasMatch(text)) {
      debugPrint('🚫 Spam: Repeated characters detected');
      return true;
    }

    // Check for repeated emojis (e.g., "🔥🔥🔥🔥🔥🔥")
    final runes = text.runes.toList();
    if (runes.length >= 5) {
      int consecutiveCount = 1;
      for (int i = 1; i < runes.length; i++) {
        if (runes[i] == runes[i - 1]) {
          consecutiveCount++;
          if (consecutiveCount >= 5) {
            debugPrint('🚫 Spam: Repeated emojis detected');
            return true;
          }
        } else {
          consecutiveCount = 1;
        }
      }
    }

    // Count emojis by checking Unicode ranges properly
    int emojiCount = 0;
    for (final rune in text.runes) {
      if ((rune >= 0x1F600 && rune <= 0x1F64F) ||
          (rune >= 0x1F300 && rune <= 0x1F5FF) ||
          (rune >= 0x1F680 && rune <= 0x1F6FF) ||
          (rune >= 0x1F1E0 && rune <= 0x1F1FF) ||
          (rune >= 0x2600 && rune <= 0x26FF) ||
          (rune >= 0x2700 && rune <= 0x27BF) ||
          (rune >= 0x1F900 && rune <= 0x1F9FF) ||
          (rune >= 0x1FA70 && rune <= 0x1FAFF)) {
        emojiCount++;
      }
    }

    // Get text without emojis
    final textWithoutEmojis =
    text.replaceAll(RegExp(r'[^\w\s]'), '').trim();

    // If more than 10 emojis and no meaningful text
    if (emojiCount > 10 && textWithoutEmojis.length < 3) {
      debugPrint(
          '🚫 Spam: Too many emojis ($emojiCount) without text');
      return true;
    }

    return false;
  }

  // ============================================================
  // FIX 9: Single _handleSend() - updated version with edit mode + all features
  // ============================================================
  Future<void> _handleSend() async {
    final commentText = _commentController.text.trim();

    if (commentText.isEmpty) {
      return;
    }

    if (_isEditMode && _editingComment != null) {
      await _saveEditedComment();
      return;
    }

    if (isSending) {
      debugPrint('⚠️ Already sending, ignoring click');
      return;
    }

    if (commentText.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comment is too long (max 500 characters)'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_lastCommentTime != null) {
      final timeSinceLastComment = DateTime.now().difference(_lastCommentTime!);
      if (timeSinceLastComment.inSeconds < 5) {
        final remainingSeconds = 5 - timeSinceLastComment.inSeconds;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Please wait $remainingSeconds seconds before commenting again'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
    }

    if (_lastCommentText != null && _lastCommentText == commentText) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'You already posted this comment. Try saying something different!'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_isSpamComment(commentText)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Spamming is not allowed. Please write a meaningful comment.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    _commentController.clear();
    _lastCommentTime = DateTime.now();
    _lastCommentText = commentText;

    setState(() => isSending = true);
    HapticFeedback.mediumImpact();

    await _checkConnectivity();

    if (!_isOnline) {
      if (isReplying) _cancelReply();
      _addToOfflineQueue(commentText);
      setState(() => isSending = false);
      return;
    }

    // Reply or new comment
    if (isReplying && replyingTo != null) {
      final parent = replyingTo!;

      // temp id check — comment තාම post වෙමින් පවතිනවා
      if (parent.id.startsWith('temp_')) {
        _cancelReply();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please wait, comment is being posted...'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        setState(() => isSending = false);
        return;
      }

      _cancelReply();
      await _postReplyToBackend(commentText, parent);
    } else {
      await _postCommentToBackend(commentText);
    }

    setState(() => isSending = false);
  }

  // ============================================================
  // Other send/interaction methods
  // ============================================================
  Future<void> _handleSendComment(String commentText) async {
    debugPrint('\n🚀 ========== HANDLE SEND COMMENT ==========');

    if (_currentUserId == null) {
      debugPrint('❌ User not logged in');
      debugPrint('==========================================\n');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to comment'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final trimmedComment = commentText.trim();

    debugPrint('📝 Comment validation:');
    debugPrint('   Original length: ${commentText.length}');
    debugPrint('   Trimmed length: ${trimmedComment.length}');

    if (trimmedComment.isEmpty) {
      debugPrint('❌ Comment is empty after trimming');
      debugPrint('==========================================\n');
      return;
    }

    if (trimmedComment.length > 500) {
      debugPrint(
          '❌ Comment too long: ${trimmedComment.length} characters (max 500)');
      debugPrint('==========================================\n');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment is too long (max 500 characters)'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    debugPrint('✅ Comment validation passed');
    debugPrint(
        '   Will post: "${trimmedComment.substring(
            0, trimmedComment.length > 30 ? 30 : trimmedComment.length)}..."');
    debugPrint('==========================================\n');

    HapticFeedback.mediumImpact();

    await _postCommentToBackend(trimmedComment);
  }

  void _handleQuickReaction(String emoji) {
    debugPrint('😊 Quick reaction: $emoji');

    // Rate limit check for quick reactions too
    if (_lastCommentTime != null) {
      final timeSinceLastComment =
      DateTime.now().difference(_lastCommentTime!);
      if (timeSinceLastComment.inSeconds < 5) {
        final remainingSeconds = 5 - timeSinceLastComment.inSeconds;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Please wait $remainingSeconds seconds before reacting again'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        debugPrint('⏱️ Rate limit: Quick reaction blocked');
        return;
      }
    }

    HapticFeedback.mediumImpact();

    // Update tracking
    _lastCommentTime = DateTime.now();
    _lastCommentText = emoji;

    setState(() => isSending = true);
    _postCommentToBackend(emoji).then((_) {
      setState(() => isSending = false);
    });
  }

  void _handleReply(Comment comment) {
    // temp id (optimistic) comment වලට reply block කරන්න
    if (comment.id.startsWith('temp_')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait, comment is being posted...'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    debugPrint('💭 Reply to: ${comment.username}');
    HapticFeedback.mediumImpact();
    setState(() {
      isReplying = true;
      replyingTo = comment;
    });
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    debugPrint('❌ Reply cancelled');
    setState(() {
      isReplying = false;
      replyingTo = null;
    });
  }

  void _toggleLike(Comment comment) {
    HapticFeedback.lightImpact();

    final newIsLiked = !comment.isLiked;

    // Like කළාම dislike ඉවත් කරන්න
    if (newIsLiked && (_dislikedComments[comment.id] ?? false)) {
      setState(() {
        _dislikedComments[comment.id] = false;
      });
      _db
          .collection('media_posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(comment.id)
          .update({
        'dislikes': FieldValue.increment(-1),
        'dislikedBy': FieldValue.arrayRemove([_currentUserId]),
      }).catchError((e) => debugPrint('❌ Failed to remove dislike on like: $e'));
    }

    setState(() {
      comment.isLiked = newIsLiked;
      comment.likes += newIsLiked ? 1 : -1;
    });

    debugPrint(
        '${newIsLiked ? "❤️" : "💔"} Like toggled for comment: ${comment.id}');

    // Firestore save
    if (_currentUserId == null) return;

    final commentRef = _db
        .collection('media_posts')
        .doc(widget.postId)
        .collection('comments')
        .doc(comment.id);

    if (newIsLiked) {
      commentRef.update({
        'likes': FieldValue.increment(1),
        'likedBy': FieldValue.arrayUnion([_currentUserId]),
      }).catchError((e) {
        debugPrint('❌ Failed to save like: $e');
        // Revert on error
        setState(() {
          comment.isLiked = !newIsLiked;
          comment.likes += newIsLiked ? -1 : 1;
        });
      });
    } else {
      commentRef.update({
        'likes': FieldValue.increment(-1),
        'likedBy': FieldValue.arrayRemove([_currentUserId]),
      }).catchError((e) {
        debugPrint('❌ Failed to remove like: $e');
        // Revert on error
        setState(() {
          comment.isLiked = !newIsLiked;
          comment.likes += newIsLiked ? -1 : 1;
        });
      });
    }
  }

  void _toggleDislike(Comment comment) {
    HapticFeedback.lightImpact();

    if (_currentUserId == null) return;

    final isCurrentlyDisliked = _dislikedComments[comment.id] ?? false;
    final newIsDisliked = !isCurrentlyDisliked;


    // Like ද ඇත්නම් remove කරන්න (infinite loop නැතිව)
    if (newIsDisliked && comment.isLiked) {
      setState(() {
        comment.isLiked = false;
        comment.likes -= 1;
      });
      _db
          .collection('media_posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(comment.id)
          .update({
        'likes': FieldValue.increment(-1),
        'likedBy': FieldValue.arrayRemove([_currentUserId]),
      }).catchError((e) => debugPrint('❌ Failed to remove like on dislike: $e'));
    }

    setState(() {
      _dislikedComments[comment.id] = newIsDisliked;
    });

    debugPrint(
        '${newIsDisliked ? "👎" : "↩️"} Dislike toggled for comment: ${comment
            .id}');

    final commentRef = _db
        .collection('media_posts')
        .doc(widget.postId)
        .collection('comments')
        .doc(comment.id);

    if (newIsDisliked) {
      commentRef.update({
        'dislikes': FieldValue.increment(1),
        'dislikedBy': FieldValue.arrayUnion([_currentUserId]),
      }).catchError((e) {
        debugPrint('❌ Failed to save dislike: $e');
        setState(() {
          _dislikedComments[comment.id] = false;
        });
      });
    } else {
      commentRef.update({
        'dislikes': FieldValue.increment(-1),
        'dislikedBy': FieldValue.arrayRemove([_currentUserId]),
      }).catchError((e) {
        debugPrint('❌ Failed to remove dislike: $e');
        setState(() {
          _dislikedComments[comment.id] = true;
        });
      });
    }
  }

  void _handleDoubleTap(Comment comment) {
    if (!comment.isLiked) {
      _toggleLike(comment);
      HapticFeedback.mediumImpact();
      debugPrint('💕 Double tap like: ${comment.id}');
    }
  }


  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return '${difference.inDays ~/ 7}w';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  // ============================================================
  // FIX 10: Single _showMoreOptions() - updated version with edit/pin/reaction
  // ============================================================
  void _showMoreOptions(Comment comment) {
    HapticFeedback.mediumImpact();

    final bool isPostOwner = _currentUserId == widget.postOwnerId;
    final bool isCommentAuthor = _currentUserId == comment.userId;
    final bool canEdit = _canEditComment(comment);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          Container(
            decoration: BoxDecoration(
              color: Color(0xFF2A2A2A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: EdgeInsets.only(top: 10, bottom: 15),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  if (isCommentAuthor) ...[
                    // EDIT OPTION
                    if (canEdit)
                      _buildOptionTile(
                        icon: Icons.edit_outlined,
                        title: 'Edit Comment',
                        subtitle: 'Edit within 5 minutes',
                        color: Colors.blue,
                        onTap: () {
                          Navigator.pop(context);
                          _startEditComment(comment);
                        },
                      ),
                    _buildOptionTile(
                      icon: Icons.delete_outline_rounded,
                      title: 'Delete Comment',
                      color: Colors.red[600]!,
                      onTap: () async {
                        Navigator.pop(context);
                        await _showDeleteConfirmation(comment, isOwner: false);
                      },
                    ),
                  ] else
                    if (isPostOwner) ...[
                      // PIN OPTION FOR POST OWNER
                      _buildOptionTile(
                        icon: _pinnedCommentIds.contains(comment.id)
                            ? Icons.push_pin
                            : Icons.push_pin_outlined,
                        title: _pinnedCommentIds.contains(comment.id)
                            ? 'Unpin Comment'
                            : 'Pin Comment',
                        subtitle: 'Pin to top',
                        color: Colors.blue,
                        onTap: () {
                          Navigator.pop(context);
                          _togglePinComment(comment);
                        },
                      ),
                      _buildOptionTile(
                        icon: Icons.delete_outline_rounded,
                        title: 'Delete Comment',
                        subtitle: 'Remove from your post',
                        color: Colors.red[600]!,
                        onTap: () async {
                          Navigator.pop(context);
                          await _showDeleteConfirmation(comment, isOwner: true);
                        },
                      ),
                      _buildOptionTile(
                        icon: Icons.visibility_off_outlined,
                        title: 'Hide Comment',
                        subtitle: 'Hide from other users',
                        color: Colors.orange[700]!,
                        onTap: () {
                          Navigator.pop(context);
                          _handleHideComment(comment);
                        },
                      ),
                      _buildOptionTile(
                        icon: Icons.report_outlined,
                        title: 'Report Comment',
                        subtitle: 'Report inappropriate content',
                        color: Colors.red[400]!,
                        onTap: () {
                          Navigator.pop(context);
                          _showReportOptions(comment);
                        },
                      ),
                    ] else
                      ...[
                        _buildOptionTile(
                          icon: Icons.report_outlined,
                          title: 'Report',
                          subtitle: 'Report this content',
                          color: Colors.red[400]!,
                          onTap: () {
                            Navigator.pop(context);
                            _showReportOptions(comment);
                          },
                        ),
                      ],

                  // REACTION OPTION FOR EVERYONE
                  _buildOptionTile(
                    icon: Icons.emoji_emotions_outlined,
                    title: 'React',
                    subtitle: 'Add a reaction',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(context);
                      _showReactionPicker(comment);
                    },
                  ),

                  _buildOptionTile(
                    icon: Icons.copy_outlined,
                    title: 'Copy Comment',
                    color: Colors.grey[400]!,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: comment.comment));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Comment copied'),
                          backgroundColor: Color(0xFF2A2A2A),
                        ),
                      );
                    },
                  ),

                  SizedBox(height: 10),
                ],
              ),
            ),
          ),
    );
  }

  // ============================================================
  // Load Comments
  // ============================================================
  Future<void> _loadComments() async {
    setState(() {
      isLoading = true;
      _lastDocument = null;
      _hasMoreComments = true;
    });

    try {
      debugPrint('\n📥 ========== LOADING COMMENTS (page 1) ==========');

      var query = _db
          .collection(widget.collectionName) // 🆕 dynamic collection
          .doc(widget.postId)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .limit(_pageSize);

      final commentsSnapshot = await query.get();

      debugPrint('   Found ${commentsSnapshot.docs.length} comments');

      if (commentsSnapshot.docs.isNotEmpty) {
        _lastDocument = commentsSnapshot.docs.last;
      }

      _hasMoreComments = commentsSnapshot.docs.length == _pageSize;

      List<Comment> loadedComments = await _buildCommentObjects(
          commentsSnapshot.docs);

      // Load pinned comment IDs
      for (final doc in commentsSnapshot.docs) {
        if (doc.data()['isPinned'] == true) {
          _pinnedCommentIds.add(doc.id);
        }
      }

      setState(() {
        comments = loadedComments;
        isLoading = false;
      });

      debugPrint(
          '✅ Loaded ${comments.length} comments (hasMore: $_hasMoreComments)');

      _slideController.forward();
      _fadeController.forward();
    } catch (e, stackTrace) {
      debugPrint('\n❌ Load error: $e\n$stackTrace');
      setState(() => isLoading = false);
    }
  }

  Future<List<Comment>> _buildCommentObjects(
      List<QueryDocumentSnapshot> docs) async {
    final results = await Future.wait(docs.map((doc) => _buildSingleComment(doc)));
    return results.whereType<Comment>().toList();
  }

  Future<Comment?> _buildSingleComment(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    // ✅ Shadow hide + global hide filter
    if (!_isCommentVisible(data)) return null;
    final repliesSnapshot = await _db
        .collection('media_posts')
        .doc(widget.postId)
        .collection('comments')
        .doc(doc.id)
        .collection('replies')
        .orderBy('timestamp', descending: false)
        .get();


    List<Comment> replies = repliesSnapshot.docs.map((replyDoc) {
      final replyData = replyDoc.data() as Map<String, dynamic>;
      final replyLikedBy = List<String>.from(replyData['likedBy'] ?? []);
      return Comment(
        id: replyDoc.id,
        username: replyData['username'] ?? 'Unknown',
        avatarUrl: replyData['avatarUrl'] ?? '',
        comment: replyData['comment'] ?? '',
        timestamp: (replyData['timestamp'] as Timestamp?)?.toDate() ??
            DateTime.now(),
        likes: replyData['likes'] ?? 0,
        isLiked: _currentUserId != null &&
            replyLikedBy.contains(_currentUserId),
        replies: [],
        userId: replyData['userId'] ?? '',
      );
    }).toList();

    final likedBy = List<String>.from(data['likedBy'] ?? []);

    return Comment(
      id: doc.id,
      username: data['username'] ?? 'Unknown',
      avatarUrl: data['avatarUrl'] ?? '',
      comment: data['comment'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: data['likes'] ?? 0,
      isLiked: _currentUserId != null && likedBy.contains(_currentUserId),
      replies: replies,
      userId: data['userId'] ?? '',
    );
  }

  Future<void> _loadMoreComments() async {
    if (_isLoadingMore || !_hasMoreComments || _lastDocument == null) return;

    setState(() => _isLoadingMore = true);
    debugPrint('📥 Loading more comments...');

    try {
      final commentsSnapshot = await _db
          .collection('media_posts')
          .doc(widget.postId)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize)
          .get();

      if (commentsSnapshot.docs.isNotEmpty) {
        _lastDocument = commentsSnapshot.docs.last;
      }

      _hasMoreComments = commentsSnapshot.docs.length == _pageSize;

      // Load pinned IDs for new batch
      for (final doc in commentsSnapshot.docs) {
        if ((doc.data() as Map<String, dynamic>)['isPinned'] == true) {
          _pinnedCommentIds.add(doc.id);
        }
      }

      final newComments = await _buildCommentObjects(commentsSnapshot.docs);

      setState(() {
        comments.addAll(newComments);
        _isLoadingMore = false;
      });

      debugPrint(
          '✅ Loaded ${newComments.length} more (hasMore: $_hasMoreComments)');
    } catch (e) {
      debugPrint('❌ Load more error: $e');
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadMoreReplies(Comment comment) async {
    if (_replyLoadingMore[comment.id] == true) return;

    setState(() => _replyLoadingMore[comment.id] = true);

    try {
      final currentCount = _replyLoadedCount[comment.id] ?? 2;
      final newLimit = currentCount + _replyPageSize;

      final repliesSnapshot = await _db
          .collection('media_posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(comment.id)
          .collection('replies')
          .orderBy('timestamp', descending: false)
          .limit(newLimit)
          .get();

      final newReplies = repliesSnapshot.docs.map((replyDoc) {
        final replyData = replyDoc.data();
        final replyLikedBy = List<String>.from(replyData['likedBy'] ?? []);
        return Comment(
          id: replyDoc.id,
          username: replyData['username'] ?? 'Unknown',
          avatarUrl: replyData['avatarUrl'] ?? '',
          comment: replyData['comment'] ?? '',
          timestamp: (replyData['timestamp'] as Timestamp?)?.toDate() ??
              DateTime.now(),
          likes: replyData['likes'] ?? 0,
          isLiked: _currentUserId != null &&
              replyLikedBy.contains(_currentUserId),
          replies: [],
          userId: replyData['userId'] ?? '',
        );
      }).toList();

      setState(() {
        final idx = comments.indexWhere((c) => c.id == comment.id);
        if (idx != -1) {
          comments[idx].replies = newReplies;
          _replyLoadedCount[comment.id] = newLimit;
        }
        _replyLoadingMore[comment.id] = false;
      });

      debugPrint('✅ Loaded ${newReplies.length} replies for ${comment.id}');
    } catch (e) {
      debugPrint('❌ Load more replies error: $e');
      setState(() => _replyLoadingMore[comment.id] = false);
    }
  }

  // ============================================================
  // Delete Comment via Backend
  // ============================================================
  Future<void> _deleteCommentViaBackend(String commentId) async {
    if (_currentUserId == null) return;

    try {
      debugPrint('\n🗑️ ========== DELETE COMMENT ==========');

      // Step 1: Try backend first
      final response = await http.delete(
        Uri.parse(
            '${BackendConfig.BACKEND_URL}/api/posts/${widget.postId}/comments/$commentId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': _currentUserId}),
      ).timeout(const Duration(seconds: 8));

      debugPrint('📡 Backend response: ${response.statusCode}');

      if (response.statusCode == 200) {
        debugPrint('✅ Deleted via backend');
        await _loadComments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comment deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }

      // Step 2: Backend failed (404 / other) — fallback to Firestore direct delete
      debugPrint('⚠️ Backend failed (${response.statusCode}), trying Firestore direct delete...');

      final commentRef = _db
          .collection('media_posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(commentId);

      final commentDoc = await commentRef.get();

      if (!commentDoc.exists) {
        debugPrint('❌ Comment not found in Firestore either');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comment not found'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final data = commentDoc.data() as Map<String, dynamic>;
      final commentUserId = data['userId'] as String? ?? '';
      final isPostOwner = _currentUserId == widget.postOwnerId;
      final isCommentOwner = _currentUserId == commentUserId;

      if (!isCommentOwner && !isPostOwner) {
        debugPrint('❌ Permission denied — not comment owner or post owner');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You don\'t have permission to delete this comment'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Delete replies subcollection first
      final repliesSnapshot = await commentRef.collection('replies').get();
      final batch = _db.batch();
      for (final replyDoc in repliesSnapshot.docs) {
        batch.delete(replyDoc.reference);
      }
      batch.delete(commentRef);
      await batch.commit();

      debugPrint('✅ Comment deleted via Firestore fallback');

      // Update local state
      setState(() {
        comments.removeWhere((c) => c.id == commentId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('\n❌ Delete error: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete comment'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatExactTimestamp(DateTime timestamp) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final hour = timestamp.hour > 12 ? timestamp.hour - 12 : (timestamp.hour ==
        0 ? 12 : timestamp.hour);
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = timestamp.hour >= 12 ? 'PM' : 'AM';
    return '${months[timestamp.month - 1]} ${timestamp.day}, ${timestamp
        .year} at $hour:$minute $period';
  }

  Widget _buildTimestampWidget(DateTime timestamp) {
    return GestureDetector(
      onLongPress: () {
        HapticFeedback.selectionClick();
        showDialog(
          context: context,
          builder: (ctx) =>
              AlertDialog(
                backgroundColor: const Color(0xFF2A2A2A),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                content: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time, color: Colors.grey[400], size: 18),
                    const SizedBox(width: 10),
                    Text(
                      _formatExactTimestamp(timestamp),
                      style: TextStyle(color: Colors.grey[300], fontSize: 14),
                    ),
                  ],
                ),
              ),
        );
      },
      child: Text(
        _formatTimestamp(timestamp),
        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
      ),
    );
  }

  // ============================================================
  // Delete Confirmation Dialog
  // ============================================================
  Future<void> _showDeleteConfirmation(Comment comment,
      {required bool isOwner}) async {
    debugPrint('\n🗑️ Delete confirmation for: ${comment.id}');
    debugPrint(
        '   Deleting as: ${isOwner ? "Post Owner" : "Comment Author"}');

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            backgroundColor: Color(0xFF2A2A2A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.delete_outline_rounded,
                    color: Colors.red[400], size: 24),
                SizedBox(width: 10),
                Text(
                  'Delete Comment?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Text(
              isOwner
                  ? 'As the post owner, you can delete this comment. This action cannot be undone.'
                  : 'Are you sure you want to delete your comment? This action cannot be undone.',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 14,
                height: 1.4,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );

    if (shouldDelete == true) {
      debugPrint('✅ User confirmed deletion');
      await _deleteCommentViaBackend(comment.id);
    } else {
      debugPrint('❌ User cancelled deletion');
    }
  }
  void _onReportCommentTap({
    required BuildContext context,
    required String commentId,
    required String commentText,
    required String commentOwnerId,
    required String commentOwnerUsername,
  }) {
    _showCommentReportSheet(
      context              : context,
      commentId            : commentId,
      commentText          : commentText,
      commentOwnerId       : commentOwnerId,
      commentOwnerUsername : commentOwnerUsername,
    );
  }

// ════════════════════════════════════════════════════════════════════
// METHOD 2 — Report Reason Bottom Sheet
// ════════════════════════════════════════════════════════════════════

// AFTER: _onReportCommentTap()

  void _showCommentReportSheet({
    required BuildContext context,
    required String commentId,
    required String commentText,
    required String commentOwnerId,
    required String commentOwnerUsername,
  }) {
    const List<String> reasons = [
      'Hate Speech or Harassment',
      'Spam or Misleading',
      'Violence or Dangerous Content',
      'Nudity or Sexual Content',
      'False Information',
      'Something Else',
    ];
    showModalBottomSheet(
      context       : context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color        : Theme.of(context).scaffoldBackgroundColor,
          borderRadius : const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width : 40,
              height: 4,
              decoration: BoxDecoration(
                color        : Colors.grey[400],
                borderRadius : BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Report Comment',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Why are you reporting this comment?',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ...reasons.map(
                  (reason) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(reason, style: const TextStyle(fontSize: 14)),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () {
                  Navigator.pop(ctx);
                  _submitCommentReport(
                    context              : context,
                    commentId            : commentId,
                    commentText          : commentText,
                    commentOwnerId       : commentOwnerId,
                    commentOwnerUsername : commentOwnerUsername,
                    reason               : reason,
                  );
                },
              ),
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 8),
          ],
        ),
      ),
    );
  }
  Future<void> _submitCommentReport({
    required BuildContext context,
    required String commentId,
    required String commentText,
    required String commentOwnerId,
    required String commentOwnerUsername,
    required String reason,
  }) async {
    // ✅ Reporter ට immediate UI shadow hide
    setState(() {
      comments.removeWhere((c) => c.id == commentId);
    });

    final result = await CommentReportService.submitCommentReport(
      postId               : widget.postId,
      commentId            : commentId,
      commentText          : commentText,
      commentOwnerId       : commentOwnerId,
      commentOwnerUsername : commentOwnerUsername,
      reason               : reason,
    );

    if (!context.mounted) return;

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content         : Text('Comment reported. Thank you for keeping VibeFlick safe.'),
          backgroundColor : Colors.green,
          duration        : Duration(seconds: 3),
        ),
      );
    } else if (result.isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content : Text('You have already reported this comment.'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      // Duplicate නොවෙයි, error — UI revert කරනවා
      await _loadComments();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content         : Text('Something went wrong. Please try again.'),
          backgroundColor : Colors.red,
          duration        : Duration(seconds: 2),
        ),
      );
    }
  }
  // ============================================================
  // Report Options
  // ============================================================
  void _showReportOptions(Comment comment) {
    HapticFeedback.mediumImpact();

    debugPrint('\n🚨 Report options for comment: ${comment.id}');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          Container(
            decoration: BoxDecoration(
              color: Color(0xFF2A2A2A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: EdgeInsets.only(top: 10, bottom: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 10, 20, 20),
                    child: Row(
                      children: [
                        Icon(Icons.report_outlined,
                            color: Colors.red[400], size: 24),
                        SizedBox(width: 10),
                        Text(
                          'Report',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  _buildReportOptionTile(
                    icon: Icons.comment_outlined,
                    title: 'Report Comment',
                    subtitle: 'This comment has inappropriate content',
                    onTap: () {
                      Navigator.pop(context);
                      _onReportCommentTap(
                        context              : context,
                        commentId            : comment.id,
                        commentText          : comment.comment,
                        commentOwnerId       : comment.userId,
                        commentOwnerUsername : comment.username,
                      );
                    },
                  ),

                  Divider(height: 1, color: Colors.grey[800]),

                  _buildReportOptionTile(
                    icon: Icons.person_outline,
                    title: 'Report User',
                    subtitle: 'This user is bothering me',
                    onTap: () {
                      Navigator.pop(context);
                      _showReportReasons(comment, reportType: 'user');
                    },
                  ),

                  SizedBox(height: 15),
                ],
              ),
            ),
          ),
    );
  }

  void _showReportReasons(Comment comment, {required String reportType}) {
    HapticFeedback.mediumImpact();

    final String targetName =
    reportType == 'comment' ? 'comment' : 'user ${comment.username}';
    debugPrint('\n🚨 Showing report reasons for $targetName');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          Container(
            decoration: BoxDecoration(
              color: Color(0xFF2A2A2A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: EdgeInsets.only(top: 10, bottom: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 10, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.report_outlined,
                                color: Colors.red[400], size: 24),
                            SizedBox(width: 10),
                            Text(
                              'Why are you reporting?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Your report is anonymous',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),

                  _buildReportReasonTile(
                    icon: Icons.report_gmailerrorred_outlined,
                    title: 'Spam',
                    subtitle: 'Misleading or repetitive content',
                    onTap: () {
                      Navigator.pop(context);
                      _submitReport(comment,
                          reportType: reportType, reason: 'Spam');
                    },
                  ),

                  Divider(height: 1, color: Colors.grey[800]),

                  _buildReportReasonTile(
                    icon: Icons.dangerous_outlined,
                    title: 'Hate Speech',
                    subtitle: 'Offensive or discriminatory language',
                    onTap: () {
                      Navigator.pop(context);
                      _submitReport(comment,
                          reportType: reportType, reason: 'Hate Speech');
                    },
                  ),

                  Divider(height: 1, color: Colors.grey[800]),

                  _buildReportReasonTile(
                    icon: Icons.block_outlined,
                    title: 'Harassment',
                    subtitle: 'Bullying or threatening behavior',
                    onTap: () {
                      Navigator.pop(context);
                      _submitReport(comment,
                          reportType: reportType, reason: 'Harassment');
                    },
                  ),

                  Divider(height: 1, color: Colors.grey[800]),

                  _buildReportReasonTile(
                    icon: Icons.more_horiz_outlined,
                    title: 'Something Else',
                    subtitle: 'Other violations or concerns',
                    onTap: () {
                      Navigator.pop(context);
                      _submitReport(comment,
                          reportType: reportType, reason: 'Something Else');
                    },
                  ),

                  SizedBox(height: 15),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _submitReport(Comment comment, {
    required String reportType,
    required String reason,
  }) async {
    try {
      if (_currentUserId == null) {
        debugPrint('⚠️ Cannot submit report - user not logged in');
        return;
      }

      debugPrint('\n📤 ========== SUBMITTING REPORT ==========');
      debugPrint('📋 Report Details:');
      debugPrint('   Report Type: $reportType');
      debugPrint('   Reason: $reason');
      debugPrint('   Comment ID: ${comment.id}');
      debugPrint(
          '   Reported User: ${comment.username} (${comment.userId})');
      debugPrint('   Reporter: $_currentUserId');
      debugPrint('   Post ID: ${widget.postId}');

      final url = Uri.parse(
          '${BackendConfig.BACKEND_URL}/api/posts/${widget
              .postId}/comments/${comment.id}/report');

      debugPrint('\n🌐 Request URL: $url');
      debugPrint('📍 Full URL: ${url.toString()}');

      final requestBody = {
        'reportType': reportType,
        'reason': reason,
        'reporterId': _currentUserId!,
        'reportedUserId': comment.userId,
        'reportedUsername': comment.username,
      };

      debugPrint('\n📦 Request Body:');
      debugPrint(json.encode(requestBody));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 15),
                Text('Submitting report...'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }

      debugPrint('\n📡 Sending HTTP POST request...');

      final response = await http
          .post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('❌ Request timeout after 10 seconds');
          throw TimeoutException('Request timed out');
        },
      );

      debugPrint('\n📡 Response received:');
      debugPrint('   Status Code: ${response.statusCode}');
      debugPrint('   Response Body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        debugPrint('✅ Report submitted successfully');

        final responseData = json.decode(response.body);
        debugPrint('📊 Server response:');
        debugPrint('   Success: ${responseData['success']}');
        debugPrint('   Message: ${responseData['message']}');
        if (responseData['data'] != null) {
          debugPrint('   Report ID: ${responseData['data']['reportId']}');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      responseData['message'] ??
                          'Thank you for reporting. We will review this soon.',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green[700],
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } else {
        debugPrint('❌ Report submission failed');
        debugPrint('   Status: ${response.statusCode}');
        debugPrint('   Body: ${response.body}');

        String errorMessage = 'Failed to submit report';

        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
          debugPrint('   Error type: ${errorData['error_type']}');
        } catch (e) {
          debugPrint('   Could not parse error response');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }

      debugPrint('==========================================\n');
    } on TimeoutException catch (e) {
      debugPrint('\n❌ ========== TIMEOUT ERROR ==========');
      debugPrint('Error: Request timed out after 10 seconds');
      debugPrint('Possible causes:');
      debugPrint('   1. Backend server not running');
      debugPrint('   2. Wrong IP address in BackendConfig');
      debugPrint('   3. Network connectivity issue');
      debugPrint('   4. Firewall blocking connection');
      debugPrint('==========================================\n');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Request timed out. Please check your connection.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } on SocketException catch (e) {
      debugPrint('\n❌ ========== NETWORK ERROR ==========');
      debugPrint('Error: ${e.message}');
      debugPrint('Possible causes:');
      debugPrint('   1. Backend server not running');
      debugPrint(
          '   2. Wrong IP address: ${BackendConfig.BACKEND_URL}');
      debugPrint(
          '   3. Device not connected to same network as backend');
      debugPrint('==========================================\n');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Cannot reach server. Check if backend is running.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('\n❌ ========== UNEXPECTED ERROR ==========');
      debugPrint('Error: $error');
      debugPrint('Stack Trace: $stackTrace');
      debugPrint('==========================================\n');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${error.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _handleHideComment(Comment comment) async {
    debugPrint('\n👁️ Hiding comment: ${comment.id}');

    HapticFeedback.mediumImpact();

    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.visibility_off, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Comment hidden from other users',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange[700],
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () {
              debugPrint('⏮️ Unhide comment: ${comment.id}');
            },
          ),
        ),
      );
    }

    debugPrint('✅ Comment hidden successfully');
  }

  // ============================================================
  // Tile Builder Helpers
  // ============================================================
  Widget _buildReportOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.red[400], size: 22),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[600], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildReportReasonTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: Colors.red[400], size: 22),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[600], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      controller: _sheetController,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildDragHandle(),
              _buildHeader(),
              _buildOfflineBanner(), // ← මෙතෙන් add කරන්න
              _buildQuickReactions(),
              Expanded(
                child: isLoading
                    ? _buildSkeletonLoading()
                    : comments.isEmpty
                    ? _buildEmptyState()
                    : _buildCommentsList(scrollController),
              ),
              _buildInputArea(),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // Drag Handle
  // ============================================================
  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[700],
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  // ============================================================
  // FIX 11: Single _buildHeader() - updated version with sort/search/analytics
  // ============================================================
  Widget _buildHeader() {
    final totalComments = comments.fold<int>(
      0,
          (sum, comment) => sum + 1 + comment.replies.length,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 5, 20, 15),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Comments',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _formatCount(totalComments),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Spacer(),

              // ANALYTICS BUTTON (POST OWNER ONLY)
              if (_currentUserId == widget.postOwnerId)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _showCommentAnalytics,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.analytics_outlined,
                        color: Colors.blue,
                        size: 22,
                      ),
                    ),
                  ),
                ),

              // SEARCH BUTTON
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _toggleSearch,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.search,
                      color: _showSearch ? Colors.blue : Colors.grey[400],
                      size: 22,
                    ),
                  ),
                ),
              ),

              // SORT BUTTON
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showSortOptions,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.sort,
                      color: Colors.grey[400],
                      size: 22,
                    ),
                  ),
                ),
              ),

              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.close,
                      color: Colors.grey[400],
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // SEARCH BAR
          if (_showSearch)
            Container(
              margin: EdgeInsets.only(top: 10),
              padding: EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterComments,
                decoration: InputDecoration(
                  hintText: 'Search comments...',
                  hintStyle:
                  TextStyle(color: Colors.grey[600], fontSize: 14),
                  border: InputBorder.none,
                  icon: Icon(Icons.search,
                      color: Colors.grey[600], size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear,
                        color: Colors.grey[600], size: 20),
                    onPressed: () {
                      _searchController.clear();
                      _filterComments('');
                    },
                  )
                      : null,
                ),
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),

          // OFFLINE QUEUE INDICATOR
          if (_offlineQueue.isNotEmpty)
            Container(
              margin: EdgeInsets.only(top: 10),
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border:
                Border.all(color: Colors.orange.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud_off, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_offlineQueue.length} comment${_offlineQueue.length > 1
                          ? "s"
                          : ""} waiting to send...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // Quick Reactions Row
  // ============================================================
  Widget _buildQuickReactions() {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 15),
        itemCount: quickReactions.length,
        itemBuilder: (context, index) {
          final reaction = quickReactions[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildQuickReactionPill(
              emoji: reaction['emoji'],
              label: reaction['label'],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickReactionPill({
    required String emoji,
    required String label,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleQuickReaction(emoji),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: TextStyle(fontSize: 18)),
              SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[300],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Skeleton Loading
  // ============================================================
  Widget _buildSkeletonLoading() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: 5,
      itemBuilder: (context, index) {
        return _buildSkeletonItem();
      },
    );
  }

  Widget _buildSkeletonItem() {
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildShimmer(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                shape: BoxShape.circle,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildShimmer(
                  child: Container(
                    width: 120,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                SizedBox(height: 8),
                _buildShimmer(
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer({required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: Duration(milliseconds: 1000),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: child,
        );
      },
      onEnd: () {
        if (mounted) setState(() {});
      },
      child: child,
    );
  }

  // ============================================================
  // Empty State
  // ============================================================
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 70,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 25),
              Text(
                'No comments yet',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Be the first to share your thoughts!\nStart the conversation 💬',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[400],
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FIX 12: Single _buildCommentsList() - updated version with filter/pin support
  // ============================================================
  Widget _buildCommentsList(ScrollController scrollController) {
    final displayComments = _getFilteredComments;

    // Separate pinned and regular comments
    final pinnedComments = displayComments
        .where((c) => _pinnedCommentIds.contains(c.id))
        .toList();
    final regularComments = displayComments
        .where((c) => !_pinnedCommentIds.contains(c.id))
        .toList();

    final allComments = [...pinnedComments, ...regularComments];

    if (allComments.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 60, color: Colors.grey[600]),
              SizedBox(height: 15),
              Text(
                'No comments found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Try a different search term',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: NotificationListener<ScrollNotification>(
          onNotification: (scrollInfo) {
            // Bottom 200px ලඟ ආවම load more trigger
            if (!_isLoadingMore &&
                _hasMoreComments &&
                scrollInfo.metrics.pixels >=
                    scrollInfo.metrics.maxScrollExtent - 200) {
              _loadMoreComments();
            }
            return false;
          },
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            itemCount: allComments.length + (_hasMoreComments ? 1 : 0),
            itemBuilder: (context, index) {
              // Progress bar (last item)
              if (index == allComments.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: _isLoadingMore
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    )
                        : const SizedBox.shrink(),
                  ),
                );
              }

              final comment = allComments[index];
              final isPinned = _pinnedCommentIds.contains(comment.id);

              return Column(
                children: [
                  if (isPinned)
                    Container(
                      margin: EdgeInsets.only(bottom: 5),
                      padding: EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.push_pin, size: 14, color: Colors.blue),
                          SizedBox(width: 5),
                          Text(
                            'Pinned by creator',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  _buildCommentItem(comment, index),
                  if (index < allComments.length - 1)
                    Divider(height: 20, thickness: 1, color: Colors.grey[800]),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Comment Item
  // ============================================================
  Widget _buildCommentItem(Comment comment, int index,
      {bool isReply = false}) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Dismissible(
        key: Key(comment.id),
        direction: DismissDirection.startToEnd,
        confirmDismiss: (direction) async {
          _handleReply(comment);
          return false;
        },
        background: Container(
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.only(left: 20),
          child: Icon(
            Icons.reply_rounded,
            color: Colors.blue,
            size: 24,
          ),
        ),
        child: Container(
          margin: EdgeInsets.only(
            left: isReply ? 50 : 0,
            bottom: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onDoubleTap: () => _handleDoubleTap(comment),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StreamBuilder<DocumentSnapshot>(
                      stream: _db
                          .collection('users')
                          .doc(comment.userId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        String? profileUrl;
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final data = snapshot.data!.data()
                          as Map<String, dynamic>? ??
                              {};
                          profileUrl = data['profile_picture_url'] ??
                              data['profile_url'] ??
                              data['profileUrl'];
                        }
                        final displayUrl =
                        (profileUrl != null && profileUrl.isNotEmpty)
                            ? profileUrl
                            : comment.avatarUrl;
                        return CircleAvatar(
                          radius: isReply ? 16 : 20,
                          backgroundColor: Colors.grey[800],
                          child: displayUrl.isNotEmpty
                              ? ClipOval(
                            child: Image.network(
                              displayUrl,
                              width: isReply ? 32 : 40,
                              height: isReply ? 32 : 40,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Icon(
                                      Icons.person,
                                      color: Colors.grey[400],
                                      size: isReply ? 16 : 20),
                            ),
                          )
                              : Icon(Icons.person,
                              color: Colors.grey[400],
                              size: isReply ? 16 : 20),
                        );
                      },
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                comment.username,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 8),
                              _buildTimestampWidget(comment.timestamp),
                              // Edited indicator
                              if (comment.isEdited) ...[
                                SizedBox(width: 5),
                                Text(
                                  '(edited)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          comment.comment.startsWith('[GIF]')
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              comment.comment.replaceFirst('[GIF]', ''),
                              height: 150,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Text(
                                    '[GIF]',
                                    style: TextStyle(color: Colors.grey[400]),
                                  ),
                            ),
                          )
                              : _buildExpandableText(comment),
                          SizedBox(height: 10),
                          Row(
                            children: [
                              _buildActionButton(
                                icon: comment.isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                label: comment.likes > 0
                                    ? comment.likes.toString()
                                    : 'Like',
                                color: comment.isLiked
                                    ? Colors.red[400]!
                                    : Colors.grey[400]!,
                                onTap: () => _toggleLike(comment),
                              ),
                              SizedBox(width: 4),
                              _buildDislikeButton(comment),
                              if (!isReply) ...[
                                SizedBox(width: 12),
                                _buildActionButton(
                                  icon: Icons.reply_rounded,
                                  label: 'Reply',
                                  color: Colors.grey[400]!,
                                  onTap: () => _handleReply(comment),
                                ),
                              ],
                              Spacer(),
                              InkWell(
                                onTap: () => _showMoreOptions(comment),
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(
                                    Icons.more_horiz,
                                    size: 18,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (comment.replies.isNotEmpty && !isReply) ...[
                const SizedBox(height: 12),
                // Initial 2 replies show කරන්න
                ...comment.replies
                    .take(_replyLoadedCount[comment.id] ?? 2)
                    .map((reply) => _buildCommentItem(reply, 0, isReply: true)),

                // Load More button — තව replies තිබේ නම්
                if (comment.replies.length >
                    (_replyLoadedCount[comment.id] ?? 2))
                  Padding(
                    padding: const EdgeInsets.only(left: 50, top: 8),
                    child: _replyLoadingMore[comment.id] == true
                        ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.blue),
                    )
                        : InkWell(
                      onTap: () => _loadMoreReplies(comment),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.keyboard_arrow_down, size: 16,
                              color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            'View ${comment.replies.length -
                                (_replyLoadedCount[comment.id] ??
                                    2)} more ${comment.replies.length -
                                (_replyLoadedCount[comment.id] ?? 2) == 1
                                ? "reply"
                                : "replies"}',
                            style: const TextStyle(fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue),
                          ),

                        ],
                      ),
                    ),
                  ),
                if (expandedReplies[comment.id] ?? false)
                  ...comment.replies.skip(2).map(
                        (reply) =>
                        _buildCommentItem(reply, 0, isReply: true),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDislikeButton(Comment comment) {
    final isDisliked = _dislikedComments[comment.id] ?? false;
    return InkWell(
      onTap: () => _toggleDislike(comment),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: SvgPicture.asset(
          'assets/images/dislike-svgrepo-com (1).svg',
          width: 16,
          height: 16,
          colorFilter: ColorFilter.mode(
            isDisliked ? Colors.blue[400]! : Colors.grey[400]!,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableText(Comment comment) {
    final isExpanded = expandedComments[comment.id] ?? false;
    final commentText = comment.comment;

    final textPainter = TextPainter(
      text: TextSpan(
        text: commentText,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[300],
          height: 1.4,
        ),
      ),
      maxLines: isExpanded ? null : 3,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(
        maxWidth: MediaQuery
            .of(context)
            .size
            .width - 130);
    final didExceedMaxLines = textPainter.didExceedMaxLines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          commentText,
          maxLines: isExpanded ? null : 3,
          overflow:
          isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[300],
            height: 1.4,
          ),
        ),
        if (didExceedMaxLines || (isExpanded && commentText.length > 100))
          GestureDetector(
            onTap: () {
              setState(() {
                expandedComments[comment.id] = !isExpanded;
              });
              HapticFeedback.selectionClick();
            },
            child: Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                isExpanded ? 'See Less' : 'See More',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _searchGifs(String query) async {
    setState(() => _isSearchingGifs = true);
    try {
      final url = query
          .trim()
          .isEmpty
          ? 'https://api.giphy.com/v1/gifs/trending?api_key=$_giphyApiKey&limit=20&rating=g'
          : 'https://api.giphy.com/v1/gifs/search?api_key=$_giphyApiKey&q=${Uri
          .encodeComponent(query)}&limit=20&rating=g';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List gifs = data['data'];
        setState(() {
          _gifResults = gifs.map<Map<String, dynamic>>((g) =>
          {
            'id': g['id'] as String,
            'url': g['images']['fixed_height_small']['url'] as String,
            'original': g['images']['original']['url'] as String,
            'title': (g['title'] ?? '') as String,
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('❌ GIF search error: $e');
    }
    setState(() => _isSearchingGifs = false);
  }

  void _showGifPicker() {
    _searchGifs('');
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) =>
          StatefulBuilder(
            builder: (ctx, setModalState) =>
                Container(
                  height: MediaQuery
                      .of(context)
                      .size
                      .height * 0.6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 10),
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[700],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Row(
                          children: [
                            const Icon(
                                Icons.gif_box_outlined, color: Colors.blue,
                                size: 24),
                            const SizedBox(width: 10),
                            const Text(
                              'GIF & Stickers',
                              style: TextStyle(fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => Navigator.pop(ctx),
                              child: Icon(Icons.close, color: Colors.grey[400],
                                  size: 22),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            onSubmitted: (q) async {
                              await _searchGifs(q);
                              setModalState(() {});
                            },
                            decoration: InputDecoration(
                              hintText: 'Search GIFs...',
                              hintStyle: TextStyle(color: Colors.grey[600],
                                  fontSize: 14),
                              border: InputBorder.none,
                              icon: Icon(Icons.search, color: Colors.grey[600],
                                  size: 20),
                            ),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _isSearchingGifs
                            ? const Center(
                          child: CircularProgressIndicator(color: Colors.blue),
                        )
                            : _gifResults.isEmpty
                            ? Center(
                          child: Text(
                            'No GIFs found',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        )
                            : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                            childAspectRatio: 1.2,
                          ),
                          itemCount: _gifResults.length,
                          itemBuilder: (_, index) {
                            final gif = _gifResults[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.pop(ctx);
                                _postCommentToBackend(
                                    '[GIF]${gif['original']}');
                                HapticFeedback.mediumImpact();
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  gif['url'] as String,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (_, child, progress) =>
                                  progress == null
                                      ? child
                                      : Container(color: Colors.grey[800]),
                                  errorBuilder: (_, __, ___) =>
                                      Container(
                                        color: Colors.grey[800],
                                        child: Icon(Icons.broken_image,
                                            color: Colors.grey[600]),
                                      ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

// ============================================================
  // EMOJI PICKER METHOD
  // ============================================================

  /// Open emoji picker screen
  Future<void> _openEmojiPicker() async {
    final selectedEmoji = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const EmojiPickerScreen(),
    );

    if (selectedEmoji != null && selectedEmoji.isNotEmpty) {
      final text = _commentController.text;
      final selection = _commentController.selection;

      if (selection.isValid) {
        final newText = text.replaceRange(
          selection.start,
          selection.end,
          selectedEmoji,
        );
        _commentController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(
            offset: selection.start + selectedEmoji.length,
          ),
        );
      } else {
        _commentController.text = text + selectedEmoji;
        _commentController.selection = TextSelection.collapsed(
          offset: _commentController.text.length,
        );
      }

      HapticFeedback.selectionClick();
      debugPrint('😊 Emoji selected: $selectedEmoji');
    }
  }
  // ============================================================
  // FIX 13: Single _buildInputArea() - updated version with edit mode + mentions
  // ============================================================
  Widget _buildInputArea() {
    final keyboardHeight = MediaQuery
        .of(context)
        .viewInsets
        .bottom;

    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      curve: Curves.easeOut,
      margin: EdgeInsets.only(
        left: 15,
        right: 15,
        top: 15,
        bottom: keyboardHeight > 0 ? keyboardHeight : 15,
      ),
      decoration: BoxDecoration(
        color: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // EDIT MODE INDICATOR
            if (_isEditMode && _editingComment != null)
              Container(
                margin: EdgeInsets.fromLTRB(15, 12, 15, 0),
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Editing comment',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _cancelEdit,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close,
                            size: 16, color: Colors.grey[400]),
                      ),
                    ),
                  ],
                ),
              ),

            // REPLY INDICATOR
            if (isReplying && replyingTo != null && !_isEditMode)
              Container(
                margin: EdgeInsets.fromLTRB(15, 12, 15, 0),
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.reply_rounded,
                        size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Replying to ${replyingTo!.username}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _cancelReply,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close,
                            size: 16, color: Colors.grey[400]),
                      ),
                    ),
                  ],
                ),
              ),

            // MENTION SUGGESTIONS
            if (_showMentionSuggestions &&
                _mentionSuggestions.isNotEmpty)
              Container(
                margin: EdgeInsets.fromLTRB(15, 12, 15, 0),
                constraints: BoxConstraints(maxHeight: 150),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _mentionSuggestions.length,
                  itemBuilder: (context, index) {
                    final user = _mentionSuggestions[index];
                    return InkWell(
                      onTap: () =>
                          _insertMention(
                            user['username']!,
                            user['userId']!,
                          ),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 15, vertical: 10),
                        child: Row(
                          children: [
                            Icon(Icons.person,
                                color: Colors.blue, size: 18),
                            SizedBox(width: 10),
                            Text(
                              '@${user['username']}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StreamBuilder<DocumentSnapshot>(
                    stream: _db
                        .collection('users')
                        .doc(_currentUserId ?? '')
                        .snapshots(),
                    builder: (context, snapshot) {
                      String? profileUrl;
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data = snapshot.data!.data()
                        as Map<String, dynamic>? ??
                            {};
                        profileUrl = data['profile_picture_url'] ??
                            data['profile_url'] ??
                            data['profileUrl'];
                      }
                      profileUrl ??= _auth.currentUser?.photoURL;
                      return CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.grey[800],
                        child: (profileUrl != null &&
                            profileUrl.isNotEmpty)
                            ? ClipOval(
                          child: Image.network(
                            profileUrl,
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Icon(
                                    Icons.person,
                                    color: Colors.grey[400]),
                          ),
                        )
                            : Icon(Icons.person,
                            color: Colors.grey[400]),
                      );
                    },
                  ),
                  SizedBox(width: 8),
                  InkWell(
                    onTap: _openGifPicker,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.gif_box_outlined,
                        color: Colors.grey[400],
                        size: 24,
                      ),
                    ),
                  ),
                  SizedBox(width: 4),
                  // Emoji button
                  InkWell(
                    onTap: _openEmojiPicker,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.emoji_emotions_outlined,
                        color: Colors.grey[400],
                        size: 24,
                      ),
                    ),
                  ),
                  SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      constraints: BoxConstraints(
                        minHeight: 40,
                        maxHeight: 120,
                      ),
                      padding: EdgeInsets.symmetric(
                          horizontal: 15, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _commentFocusNode.hasFocus
                              ? Colors.blue.withOpacity(0.5)
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: TextField(
                        controller: _commentController,
                        focusNode: _commentFocusNode,
                        readOnly: !_isOnline,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: 500,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: _isEditMode
                              ? "Edit your comment..."
                              : "Add a comment...",
                          hintStyle: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          counterText: '',
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    child: characterCount > 0 || isSending
                        ? InkWell(
                      onTap: isSending ? null : _handleSend,
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: isSending
                              ? LinearGradient(
                            colors: [
                              Colors.grey[700]!,
                              Colors.grey[600]!
                            ],
                          )
                              : LinearGradient(
                            colors: [
                              Colors.blue,
                              Colors.blue[700]!
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isSending
                                  ? Colors.grey
                                  : Colors.blue)
                                  .withOpacity(0.3),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: isSending
                            ? Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                            AlwaysStoppedAnimation<Color>(
                                Colors.white),
                          ),
                        )
                            : Icon(
                          _isEditMode
                              ? Icons.check
                              : Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    )
                        : Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.send_rounded,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (characterCount > 0)
              Padding(
                padding: EdgeInsets.fromLTRB(15, 0, 15, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '$characterCount/500',
                      style: TextStyle(
                        fontSize: 11,
                        color: characterCount > 450
                            ? Colors.red[400]
                            : Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }


}