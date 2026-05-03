import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_vibe_flick/Thought/thought_vibes_screen.dart';
// ADD with other imports:
import 'message_report_service.dart'; // path adjust කරන්න
import '../Notification/comments_screen.dart';
import '../Notification/followers_screen.dart';
import '../Notification/likes_screen.dart';
import '../Notification/vibe'
    'flick_official_screen.dart';
import '../search_page.dart';
import 'mentions_screen.dart';
import 'messages_screen.dart';
import 'tags_screen.dart';

class NotificationItem {
  final String id;
  final String type;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String time;
  final int badge;

  NotificationItem({
    required this.id,
    required this.type,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.badge,
  });
}

class Message {
  final String id;
  final String name;
  final String message;
  final String time;
  final String avatar;
  final int unread;
  final bool isOnline;

  Message({
    required this.id,
    required this.name,
    required this.message,
    required this.time,
    required this.avatar,
    required this.unread,
    required this.isOnline,
  });
}

class MentionItem {
  final String id;
  final String userName;
  final String userAvatar;
  final String contentType;
  final String contentPreview;
  final String time;
  final bool isRead;

  MentionItem({
    required this.id,
    required this.userName,
    required this.userAvatar,
    required this.contentType,
    required this.contentPreview,
    required this.time,
    required this.isRead,
  });
}

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> with TickerProviderStateMixin {
  bool _isRefreshing = false;
  late FirebaseAuth _auth;
  late FirebaseFirestore _firestore;
  String? _currentUserId;
  // Shimmer animation
  bool _isScreenLoading = true;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  // 🔥 Real-time notification counts
  int _likesCount = 0;
  int _commentsCount = 0;
  int _followersCount = 0;
  int _tagsCount = 0;
  int _mentionsCount = 0;
  int _messagesCount = 0;
  int _thoughtVibesCount = 0;
  int _violationsCount = 0;
  @override
  void initState() {
    super.initState();
    _auth = FirebaseAuth.instance;
    _firestore = FirebaseFirestore.instance;
    _currentUserId = _auth.currentUser?.uid;
// Shimmer controller setup
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _shimmerAnimation = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

// Hide shimmer after 1.5s (real-time listeners kick in)
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _isScreenLoading = false);
    });
    // 🔥 Start listening to real-time counts
    _setupRealtimeListeners();
  }
// 👇 මෙතන add කරන්න
  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  // 🔥 Setup real-time listeners for all notification types
  void _setupRealtimeListeners() {
    if (_currentUserId == null) {
      debugPrint('⚠️ No current user - skipping notification listeners');
      return;
    }

    debugPrint(
        '🔔 Setting up real-time notification listeners for user: $_currentUserId');

    // 1️⃣ Likes Count
    _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('notifications')
        .where('type', isEqualTo: 'like')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _likesCount = snapshot.docs.length;
        });
        debugPrint('❤️ Likes count updated: $_likesCount');
      }
    });

    // 2️⃣ Comments Count
    _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('notifications')
        .where('type', isEqualTo: 'comment')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _commentsCount = snapshot.docs.length;
        });
        debugPrint('💬 Comments count updated: $_commentsCount');
      }
    });

    // 3️⃣ Followers Count
    _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('notifications')
        .where('type', isEqualTo: 'follow')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _followersCount = snapshot.docs.length;
        });
        debugPrint('👥 Followers count updated: $_followersCount');
      }
    });

    // 4️⃣ Tags Count
    _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('notifications')
        .where('type', isEqualTo: 'tag')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _tagsCount = snapshot.docs.length;
        });
        debugPrint('🏷️ Tags count updated: $_tagsCount');
      }
    });

    // 5️⃣ Mentions Count
    _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('notifications')
        .where('type', isEqualTo: 'mention')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _mentionsCount = snapshot.docs.length;
        });
        debugPrint('@ Mentions count updated: $_mentionsCount');
      }
    });

    // 6️⃣ Messages Count
    _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('notifications')
        .where('type', isEqualTo: 'message')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _messagesCount = snapshot.docs.length;
        });
        debugPrint('📩 Messages count updated: $_messagesCount');
      }
    });
    // 7️⃣ Thought Vibes Count (likes + replies + reposts combined)
    _firestore
        .collection('users').doc(_currentUserId)
        .collection('notifications')
        .where(
        'type', whereIn: ['thought_like', 'thought_reply', 'thought_repost'])
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _thoughtVibesCount = snapshot.docs.length;
        });
        debugPrint('💭 Thought Vibes count updated: $_thoughtVibesCount');
      }
    });
    // 8️⃣ Violations Count (post_reported + strike_warning)
    _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('notifications')
        .where('type', whereIn: ['post_reported', 'strike_warning'])
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _violationsCount = snapshot.docs.length;
        });
        debugPrint('🚨 Violations count updated: $_violationsCount');
      }
    });

  }


  final List<MentionItem> _mentions = [
    MentionItem(
      id: '1',
      userName: 'Kasun Perera',
      userAvatar: 'https://i.pravatar.cc/100?img=5',
      contentType: 'comment',
      contentPreview: 'mentioned you in a comment: "Check this out @you"',
      time: '5m',
      isRead: false,
    ),
    MentionItem(
      id: '2',
      userName: 'Nimal Silva',
      userAvatar: 'https://i.pravatar.cc/100?img=6',
      contentType: 'video',
      contentPreview: 'tagged you in a video',
      time: '1h',
      isRead: false,
    ),
    MentionItem(
      id: '3',
      userName: 'Saman Fernando',
      userAvatar: 'https://i.pravatar.cc/100?img=7',
      contentType: 'comment',
      contentPreview: 'mentioned you: "Great work @you!"',
      time: '3h',
      isRead: true,
    ),
  ];

  final List<Message> _messages = [
    Message(
      id: '1',
      name: 'Kasun Perera',
      message: 'Hey! How are you doing?',
      time: '2m',
      avatar: 'https://i.pravatar.cc/100?img=1',
      unread: 3,
      isOnline: true,
    ),
    Message(
      id: '2',
      name: 'Nimal Silva',
      message: 'Thanks for the follow back! 🔥',
      time: '15m',
      avatar: 'https://i.pravatar.cc/100?img=2',
      unread: 1,
      isOnline: false,
    ),
    Message(
      id: '3',
      name: 'Saman Fernando',
      message: 'Your video was amazing!',
      time: '1h',
      avatar: 'https://i.pravatar.cc/100?img=3',
      unread: 0,
      isOnline: true,
    ),
    Message(
      id: '4',
      name: 'Kumari De Silva',
      message: 'Can you check my latest post?',
      time: '2h',
      avatar: 'https://i.pravatar.cc/100?img=4',
      unread: 0,
      isOnline: false,
    ),
  ];

  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _isRefreshing = false);
  }

  void _handleSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SearchPage()),
    );
  }
  void _handleNotificationClick(String type) {
    if (type == 'likes') {
      _markAsRead(['like']);
      Navigator.push(context, MaterialPageRoute(builder: (context) => const LikesScreen()));
    } else if (type == 'followers') {
      _markAsRead(['follow']);
      Navigator.push(context, MaterialPageRoute(builder: (context) => const FollowersScreen()));
    } else if (type == 'comments') {
      _markAsRead(['comment']);
      Navigator.push(context, MaterialPageRoute(builder: (context) => const CommentsScreen()));
    }
  }


  void _handleMentionsClick() {
    _markAsRead(['mention']);
    Navigator.push(context, MaterialPageRoute(builder: (context) => const MentionsScreen()));
  }

  // ✅ Navigate to Messages Screen
  void _handleMessagesClick() {
    _markAsRead(['message']);
    Navigator.push(context, MaterialPageRoute(builder: (context) => const MessagesScreen()));
  }

  void _handleTagsClick() {
    _markAsRead(['tag']);
    Navigator.push(context, MaterialPageRoute(builder: (context) => const TagsScreen()));
  }

// ✅ Navigate to Thought Vibes Screen
  void _handleThoughtVibesClick() {
    _markAsRead(['thought_like', 'thought_reply', 'thought_repost']);
    Navigator.push(context, MaterialPageRoute(builder: (context) => const ThoughtVibesScreen()));
  }

// ✅ Notifications read ලෙස mark කරන්න
  Future<void> _markAsRead(List<String> types) async {
    if (_currentUserId == null) return;
    try {
      final batch = _firestore.batch();
      for (final type in types) {
        final snapshot = await _firestore
            .collection('users')
            .doc(_currentUserId)
            .collection('notifications')
            .where('type', isEqualTo: type)
            .where('read', isEqualTo: false)
            .get();
        for (final doc in snapshot.docs) {
          batch.update(doc.reference, {'read': true});
        }
      }
      await batch.commit();
      debugPrint('✅ Marked as read: $types');
    } catch (e) {
      debugPrint('⚠️ Mark as read error: $e');
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Column(
        children: [
          _buildToolbar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              backgroundColor: const Color(0xFF1E1E1E),
              color: const Color(0xFFFF3B5C),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _isScreenLoading ? _buildShimmerList() : _buildNotificationsSection(),
                    if (!_isScreenLoading) _buildThoughtVibesNavigationButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1E1E), Color(0xFF2D2D2D)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Inbox',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          IconButton(
            onPressed: _handleSearch,
            icon: const Icon(Icons.search, size: 24, color: Colors.white),
            padding: const EdgeInsets.all(8),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsSection() {
    return Container(
      color: const Color(0xFF1E1E1E),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 8, 18, 12),
            child: Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ),
          // 🔥 Dynamic notification items with real-time counts
          _buildNotificationItem(NotificationItem(
            id: '1',
            type: 'followers',
            icon: Icons.people,
            iconColor: const Color(0xFF3B82F6),
            title: _followersCount > 0
                ? '$_followersCount new followers'
                : 'New Followers',
            subtitle: _followersCount > 0
                ? 'Someone followed you'
                : 'No new followers',
            time: 'Just now',
            badge: _followersCount,
          )),
          _buildNotificationItem(NotificationItem(
            id: '2',
            type: 'comments',
            icon: Icons.chat_bubble,
            iconColor: const Color(0xFF10B981),
            title: _commentsCount > 0
                ? '$_commentsCount new comments'
                : 'Comments',
            subtitle: _commentsCount > 0
                ? 'Someone commented on your post'
                : 'No new comments',
            time: 'Just now',
            badge: _commentsCount,
          )),
          _buildNotificationItem(NotificationItem(
            id: '3',
            type: 'likes',
            icon: Icons.favorite,
            iconColor: const Color(0xFF3F51B5),
            title: _likesCount > 0 ? '$_likesCount new likes' : 'Likes',
            subtitle: _likesCount > 0
                ? 'Someone liked your post'
                : 'No new likes',
            time: 'Just now',
            badge: _likesCount,
          )),
          // ✅ Messages & Groups Button (Same style as notifications)
          _buildMessagesNavigationButton(),
          _buildVibeFlickItem(),
          // ✅ Tags Navigation Button
          _buildTagsNavigationButton(),
          // ✅ Mentions Navigation Button
          _buildMentionsNavigationButton(),
          // ✅ Violations Navigation Button
          _buildViolationsNavigationButton(),
        ],
      ),
    );
  }

  // ✅ Messages & Groups Navigation Button (Same style as other notifications)
  Widget _buildMessagesNavigationButton() {
    return InkWell(
      onTap: _handleMessagesClick,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 15),
        child: Row(
          children: [
            const SizedBox(width: 11),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6), // Purple color
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.chat_bubble,
                size: 24,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Messages & Groups',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _messagesCount > 0
                        ? '$_messagesCount unread messages'
                        : 'View all your conversations',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            if (_messagesCount > 0)
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF3B5C), Color(0xFFFF1744)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF3B5C).withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _messagesCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: Color(0xFF6B7280),
            ),
            const SizedBox(width: 11),
          ],
        ),
      ),
    );
  }

  // ✅ Tags Navigation Button
  Widget _buildTagsNavigationButton() {
    return InkWell(
      onTap: _handleTagsClick,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 15),
        child: Row(
          children: [
            const SizedBox(width: 11),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B5C),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  '🏷️',
                  style: TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tags',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _tagsCount > 0
                        ? '$_tagsCount new tags'
                        : 'View posts where you are tagged',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            if (_tagsCount > 0)
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF3B5C), Color(0xFFFF1744)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF3B5C).withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _tagsCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: Color(0xFF6B7280),
            ),
            const SizedBox(width: 11),
          ],
        ),
      ),
    );
  }

  // ✅ NEW: Mentions Navigation Button
  Widget _buildMentionsNavigationButton() {
    return InkWell(
      onTap: _handleMentionsClick,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 15),
        child: Row(
          children: [
            const SizedBox(width: 11),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B), // Orange color
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.alternate_email,
                size: 24,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mentions',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _mentionsCount > 0
                        ? '$_mentionsCount new mentions'
                        : 'View all mentions',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            if (_mentionsCount > 0)
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF3B5C), Color(0xFFFF1744)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF3B5C).withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _mentionsCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: Color(0xFF6B7280),
            ),
            const SizedBox(width: 11),
          ],
        ),
      ),
    );
  }
  // ✅ Violations Navigation Button
  Widget _buildViolationsNavigationButton() {
    return InkWell(
      onTap: () {
        if (_currentUserId == null) return;
        _markViolationsAsRead();
        _showViolationsBottomSheet();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 15),
        child: Row(
          children: [
            const SizedBox(width: 11),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.gavel_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account Notices',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _violationsCount > 0
                        ? '$_violationsCount unread violation notices'
                        : 'Community guideline warnings & strikes',
                    style: const TextStyle(fontSize: 15, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
            if (_violationsCount > 0)
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    _violationsCount.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            const Icon(Icons.chevron_right, size: 20, color: Color(0xFF6B7280)),
            const SizedBox(width: 11),
          ],
        ),
      ),
    );
  }

  Future<void> _markViolationsAsRead() async {
    if (_currentUserId == null) return;
    try {
      final batch = _firestore.batch();
      final snapshot = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('notifications')
          .where('type', whereIn: ['post_reported', 'strike_warning'])
          .where('isRead', isEqualTo: false)
          .get();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('⚠️ Mark violations as read error: $e');
    }
  }
// ════════════════════════════════════════════════════════════════════
// ADD AFTER: Future<void> _markViolationsAsRead() async { ... }
// ════════════════════════════════════════════════════════════════════

  // ── Message User Report Bottom Sheet ─────────────────────────────
  void showMessageUserReportSheet({
    required String userId,
    required String username,
    String messagePreview = '',
    String chatRoomId    = '',
  }) {
    String? selectedReason;

    showModalBottomSheet(
      context          : context,
      isScrollControlled: true,
      backgroundColor  : const Color(0xFF1E1E1E),
      shape            : const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Handle bar ─────────────────────────────────
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // ── Title ──────────────────────────────────────
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Report User',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Divider(color: Color(0xFF2C2C2C), height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Text(
                      'Why are you reporting @$username?',
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  // ── Reason List ────────────────────────────────
                  ...MessageReportService.reportReasons.map((reason) {
                    return RadioListTile<String>(
                      value      : reason,
                      groupValue : selectedReason,
                      onChanged  : (val) =>
                          setModalState(() => selectedReason = val),
                      title: Text(
                        reason,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                      activeColor: const Color(0xFFFF3B5C),
                      tileColor  : Colors.transparent,
                    );
                  }),
                  const SizedBox(height: 12),
                  // ── Submit Button ──────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: selectedReason == null
                            ? null
                            : () async {
                          Navigator.pop(ctx);
                          await _submitMessageReport(
                            userId       : userId,
                            username     : username,
                            reason       : selectedReason!,
                            preview      : messagePreview,
                            chatRoomId   : chatRoomId,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor        : const Color(0xFFFF3B5C),
                          disabledBackgroundColor: const Color(0xFF3A3A3A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Submit Report',
                          style: TextStyle(
                            color     : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize  : 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Submit + SnackBar ─────────────────────────────────────────────
  Future<void> _submitMessageReport({
    required String userId,
    required String username,
    required String reason,
    String preview    = '',
    String chatRoomId = '',
  }) async {
    final result = await MessageReportService.submitMessageReport(
      reportedUserId  : userId,
      reportedUsername: username,
      reason          : reason,
      messagePreview  : preview,
      chatRoomId      : chatRoomId,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content        : Text('Report submitted. We will review within 24 hours.'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
    } else if (result.isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content        : Text('You have already reported this user.'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content        : Text('Failed: ${result.errorMessage ?? "Unknown error"}'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

// ════════════════════════════════════════════════════════════════════
// END ADD — inbox_screen.dart
// ════════════════════════════════════════════════════════════════════
  void _showViolationsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Column(
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
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Account Notices',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const Divider(color: Color(0xFF2C2C2C), height: 1),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('users')
                        .doc(_currentUserId)
                        .collection('notifications')
                        .where('type', whereIn: ['post_reported', 'strike_warning'])
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator(color: Color(0xFFFF3B5C)));
                      }
                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline, size: 64, color: Color(0xFF22C55E)),
                              SizedBox(height: 16),
                              Text('No violations', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              SizedBox(height: 8),
                              Text('Your account is in good standing', style: TextStyle(color: Color(0xFF9CA3AF))),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        controller: scrollController,
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          return _buildViolationItem(data);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildViolationItem(Map<String, dynamic> data) {
    final type = data['type'] ?? '';
    final message = data['message'] ?? '';
    final strikeNumber = data['strikeNumber'] ?? 0;
    final timestamp = data['timestamp'];

    final isStrike = type == 'strike_warning';
    final isRead = data['isRead'] ?? false;

    Color cardColor;
    IconData cardIcon;
    String title;

    if (isStrike) {
      if (strikeNumber >= 3) {
        cardColor = const Color(0xFFDC2626);
        cardIcon = Icons.block;
        title = '💀 Strike 3 — Account Banned';
      } else if (strikeNumber == 2) {
        cardColor = const Color(0xFFEA580C);
        cardIcon = Icons.pause_circle;
        title = '🚫 Strike 2 — Posting Restricted';
      } else {
        cardColor = const Color(0xFFD97706);
        cardIcon = Icons.warning_amber_rounded;
        title = '⚠️ Strike 1 — Account Warning';
      }
    } else {
      cardColor = const Color(0xFF7C3AED);
      cardIcon = Icons.remove_circle_outline;
      title = '📋 Content Removed';
    }

    String timeStr = '';
    if (timestamp != null) {
      final dt = timestamp is int
          ? DateTime.fromMillisecondsSinceEpoch(timestamp)
          : (timestamp as dynamic).toDate();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) timeStr = '${diff.inMinutes}m ago';
      else if (diff.inHours < 24) timeStr = '${diff.inHours}h ago';
      else timeStr = '${diff.inDays}d ago';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isRead ? const Color(0xFF1A1A1A) : const Color(0xFF2A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardColor.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(cardIcon, color: cardColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: TextStyle(color: cardColor, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                Text(timeStr, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            Text(message, style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 14, height: 1.5)),
            const SizedBox(height: 12),
            // Appeal button
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Appeal submitted. We will review within 24 hours.'),
                    backgroundColor: Color(0xFF22C55E),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: cardColor.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Appeal this decision', style: TextStyle(color: cardColor, fontSize: 13, fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildNotificationItem(NotificationItem notification) {
    return InkWell(
      onTap: () => _handleNotificationClick(notification.type),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 15),
        child: Row(
          children: [
            const SizedBox(width: 11),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: notification.iconColor,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                notification.icon,
                size: 24,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.subtitle,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.time,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            if (notification.badge > 0)
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF3B5C), Color(0xFFFF1744)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF3B5C).withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    notification.badge.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: Color(0xFF6B7280),
            ),
            const SizedBox(width: 11),
          ],
        ),
      ),
    );
  }

  Widget _buildVibeFlickItem() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const VibeFlickOfficialScreen(),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 15),
        child: Row(
          children: [
            const SizedBox(width: 11),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF3B5C), Color(0xFFFF1744)],
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF3B5C).withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF1744),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Text(
                      'VF',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'VibeFlick Official',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Hi Dear, Welcome to VibeFlick 🌹 you have ...',
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Just Now',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: Color(0xFF6B7280),
            ),
            const SizedBox(width: 11),
          ],
        ),
      ),
    );
  }

  Widget _buildThoughtVibesNavigationButton() {
    return InkWell(
      onTap: _handleThoughtVibesClick,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 15),
        child: Row(children: [
          const SizedBox(width: 11),
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6b2d5e), Color(0xFF2d1b69)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8, offset: const Offset(0, 2),
              )
              ],
            ),
            child: const Icon(
                Icons.auto_awesome_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Thought Vibes',
                  style: TextStyle(fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 2),
              Text(
                _thoughtVibesCount > 0
                    ? '$_thoughtVibesCount new thought interactions'
                    : 'Likes, replies & reposts on your thoughts',
                style: const TextStyle(fontSize: 15, color: Color(0xFF9CA3AF)),
              ),
            ],
          )),
          if (_thoughtVibesCount > 0)
            Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFFF3B5C), Color(0xFFFF1744)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(
                _thoughtVibesCount.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.bold),
              )),
            ),
          const Icon(Icons.chevron_right, size: 20, color: Color(0xFF6B7280)),
          const SizedBox(width: 11),
        ]),
      ),
    );
  }

  Widget _buildShimmerBlock({double width = double.infinity, double height = 20, double radius = 8}) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: const [0.0, 0.5, 1.0],
              colors: const [
                Color(0xFF2A2A2A),
                Color(0xFF3A3A3A),
                Color(0xFF2A2A2A),
              ],
              transform: GradientRotation(_shimmerAnimation.value),
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmerItem() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          _buildShimmerBlock(width: 44, height: 44, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildShimmerBlock(height: 16, radius: 6),
                const SizedBox(height: 8),
                _buildShimmerBlock(width: 180, height: 13, radius: 6),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildShimmerBlock(width: 24, height: 24, radius: 12),
        ],
      ),
    );
  }

  Widget _buildShimmerList() {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: _buildShimmerBlock(width: 120, height: 14, radius: 6),
          ),
          ...List.generate(7, (_) => _buildShimmerItem()),
        ],
      ),
    );
  }
}