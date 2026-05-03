import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'chat_screen.dart';
import 'group_chat_screen.dart';


// ════════════════════════════════════════════════════════════════════════════
// 🆕 UPDATED MESSAGE MODEL - Added conversationStatus & isRequestSender
// ════════════════════════════════════════════════════════════════════════════

class Message {
  final String id;
  final String name;
  final String message;
  final String time;
  final String avatar;
  final int unread;
  final bool isOnline;
  final String receiverId;
  final int timestamp;

  // 🆕 NEW: Conversation status tracking
  final String conversationStatus;  // 'pending' | 'accepted' | 'declined'
  final bool isRequestSender;        // true if current user sent the message request

  Message({
    required this.id,
    required this.name,
    required this.message,
    required this.time,
    required this.avatar,
    required this.unread,
    required this.isOnline,
    required this.receiverId,
    required this.timestamp,
    this.conversationStatus = 'accepted',  // Default to accepted for backward compatibility
    this.isRequestSender = false,
  });
}

class Group {
  final String id;
  final String name;
  final String lastMessage;
  final String time;
  final String groupImage;
  final int memberCount;
  final int unread;
  final List<String> members;
  final List<String> admins;
  final String createdBy;
  final int lastTimestamp;

  Group({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.groupImage,
    required this.memberCount,
    required this.unread,
    required this.members,
    required this.admins,
    required this.createdBy,
    required this.lastTimestamp,
  });
}

class Story {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final String imageUrl;
  final int timestamp;
  final bool isSeen;
  final List<String> seenBy;

  Story({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.imageUrl,
    required this.timestamp,
    required this.isSeen,
    required this.seenBy,
  });

  bool get isExpired {
    final now = DateTime.now().millisecondsSinceEpoch;
    final difference = now - timestamp;
    return difference > (24 * 60 * 60 * 1000);
  }
}

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool _isOnline = true;

  final DatabaseReference _rtdb = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Message> _messages = [];
  List<Group> _groups = [];
  List<Story> _stories = [];
  List<StreamSubscription> _subscriptions = [];
  bool _isLoadingMessages = true;
  bool _isLoadingGroups = true;
  bool _isLoadingStories = true;

  @override
  void initState() {
    super.initState();

    _loadRealTimeMessages();
    _loadRealTimeGroups();
    _loadRealTimeStories();
    _updateOnlineStatus(_isOnline);
  }

  @override
  void dispose() {
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _updateOnlineStatus(false);
    super.dispose();
  }

  Future<void> _updateOnlineStatus(bool isOnline) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _firestore.collection('users').doc(currentUser.uid).update({
        'isOnline': isOnline,
        'lastSeen': isOnline ? null : DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('❌ Failed to update online status: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 🔧 FIXED: _loadRealTimeMessages() - Added status filtering & conversationStatus
  // ════════════════════════════════════════════════════════════════════════════
  Future<void> _loadRealTimeMessages() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() => _isLoadingMessages = false);
        return;
      }

      final currentUserId = currentUser.uid;

      final subscription = _rtdb
          .child('chatRooms')
          .onValue
          .listen((event) async {
        try {
          if (!mounted) return;

          final snapshot = event.snapshot;
          if (!snapshot.exists) {
            setState(() {
              _messages = [];
              _isLoadingMessages = false;
            });
            return;
          }

          final chatRoomsMap = snapshot.value as Map<dynamic, dynamic>;
          List<Message> loadedMessages = [];

          for (var chatRoomEntry in chatRoomsMap.entries) {
            final chatRoomId = chatRoomEntry.key as String;
            final chatRoomData = chatRoomEntry.value as Map<dynamic, dynamic>;

            if (!chatRoomId.contains(currentUserId)) continue;

            final info = chatRoomData['info'] as Map<dynamic, dynamic>?;
            if (info == null) continue;

            // 🆕 FIX #1: Filter out declined conversations
            final status = info['status'] as String? ?? 'accepted';
            if (status == 'declined') {
              debugPrint('⏭️ Skipping declined chat: $chatRoomId');
              continue;  // Don't show declined conversations in the list
            }

            final participants = info['participants'];
            List<String> participantsList = [];

            if (participants is List) {
              participantsList = List<String>.from(participants);
            }

            if (!participantsList.contains(currentUserId)) continue;

            final otherUserId = participantsList.firstWhere(
                  (id) => id != currentUserId,
              orElse: () => '',
            );

            if (otherUserId.isEmpty) continue;

            try {
              final userDoc = await _firestore
                  .collection('users')
                  .doc(otherUserId)
                  .get();

              if (!userDoc.exists) continue;

              final userData = userDoc.data()!;

              final userName = userData['name'] ??
                  userData['username'] ??
                  'Unknown User';

              final userAvatar = userData['profile_picture_url'] ??
                  userData['profile_url'] ??
                  '';

              final isOnline = userData['isOnline'] ?? false;

              final lastMessage = info['lastMessage'] as String? ?? 'No messages yet';
              final lastTimestamp = info['lastTimestamp'] as int? ?? 0;

              int unreadCount = 0;
              final messages = chatRoomData['messages'] as Map<dynamic, dynamic>?;
              if (messages != null) {
                for (var msgEntry in messages.entries) {
                  final msgData = msgEntry.value as Map<dynamic, dynamic>;
                  final senderId = msgData['senderId'] as String?;
                  final isSeen = msgData['isSeen'] as bool? ?? false;

                  if (senderId == otherUserId && !isSeen) {
                    unreadCount++;
                  }
                }
              }

              // 🆕 FIX #2: Add conversationStatus and isRequestSender to Message
              loadedMessages.add(Message(
                id: chatRoomId,
                name: userName,
                message: lastMessage,
                time: _formatTimestamp(lastTimestamp),
                avatar: userAvatar,
                unread: unreadCount,
                isOnline: isOnline,
                receiverId: otherUserId,
                timestamp: lastTimestamp,
                conversationStatus: status,  // ← NEW
                isRequestSender: info['requestedBy'] == currentUserId,  // ← NEW
              ));
            } catch (e) {
              debugPrint('❌ Error fetching user data: $e');
            }
          }

          loadedMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

          if (mounted) {
            setState(() {
              _messages = loadedMessages;
              _isLoadingMessages = false;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() => _isLoadingMessages = false);
          }
        }
      });

      _subscriptions.add(subscription);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMessages = false);
      }
    }
  }

  String _formatTimestamp(int timestamp) {
    if (timestamp == 0) return 'now';

    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';
    return '${(difference.inDays / 7).floor()}w';
  }

  Future<void> _loadRealTimeGroups() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() => _isLoadingGroups = false);
        return;
      }

      final currentUserId = currentUser.uid;

      final subscription = _rtdb
          .child('groups')
          .onValue
          .listen((event) async {
        if (!mounted) return;

        final snapshot = event.snapshot;
        if (!snapshot.exists) {
          setState(() {
            _groups = [];
            _isLoadingGroups = false;
          });
          return;
        }

        final groupsMap = snapshot.value as Map<dynamic, dynamic>;
        List<Group> loadedGroups = [];

        for (var groupEntry in groupsMap.entries) {
          final groupId = groupEntry.key as String;
          final groupData = groupEntry.value as Map<dynamic, dynamic>;

          final info = groupData['info'] as Map<dynamic, dynamic>?;
          if (info == null) continue;

          final members = List<String>.from(info['members'] ?? []);
          if (!members.contains(currentUserId)) continue;

          final admins = List<String>.from(info['admins'] ?? []);
          final groupName = info['name'] as String? ?? 'Unnamed Group';
          final groupImage = info['groupImage'] as String? ?? '';
          final createdBy = info['createdBy'] as String? ?? '';
          final lastMessage = info['lastMessage'] as String? ?? 'No messages yet';
          final lastTimestamp = info['lastTimestamp'] as int? ?? 0;

          int unreadCount = 0;
          final messages = groupData['messages'] as Map<dynamic, dynamic>?;
          if (messages != null) {
            for (var msgEntry in messages.entries) {
              final msgData = msgEntry.value as Map<dynamic, dynamic>;
              final senderId = msgData['senderId'] as String?;
              final seenBy = List<String>.from(msgData['seenBy'] ?? []);

              if (senderId != currentUserId && !seenBy.contains(currentUserId)) {
                unreadCount++;
              }
            }
          }

          loadedGroups.add(Group(
            id: groupId,
            name: groupName,
            lastMessage: lastMessage,
            time: _formatTimestamp(lastTimestamp),
            groupImage: groupImage,
            memberCount: members.length,
            unread: unreadCount,
            members: members,
            admins: admins,
            createdBy: createdBy,
            lastTimestamp: lastTimestamp,
          ));
        }

        loadedGroups.sort((a, b) => b.lastTimestamp.compareTo(a.lastTimestamp));

        if (mounted) {
          setState(() {
            _groups = loadedGroups;
            _isLoadingGroups = false;
          });
        }
      });

      _subscriptions.add(subscription);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingGroups = false);
      }
    }
  }

  Future<void> _loadRealTimeStories() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() => _isLoadingStories = false);
        return;
      }

      final currentUserId = currentUser.uid;

      final subscription = _rtdb
          .child('stories')
          .onValue
          .listen((event) async {
        if (!mounted) return;

        final snapshot = event.snapshot;
        if (!snapshot.exists) {
          setState(() {
            _stories = [];
            _isLoadingStories = false;
          });
          return;
        }

        final storiesMap = snapshot.value as Map<dynamic, dynamic>;
        List<Story> loadedStories = [];

        final userDoc = await _firestore.collection('users').doc(currentUserId).get();
        final List<String> following = List<String>.from(userDoc.data()?['following'] ?? []);
        final List<String> followers = List<String>.from(userDoc.data()?['followers'] ?? []);

        final friends = {...following, ...followers, currentUserId}.toList();

        for (var storyEntry in storiesMap.entries) {
          final userId = storyEntry.key as String;
          if (!friends.contains(userId)) continue;

          final userStories = storyEntry.value as Map<dynamic, dynamic>;

          for (var individualStory in userStories.entries) {
            final storyId = individualStory.key as String;
            final storyData = individualStory.value as Map<dynamic, dynamic>;

            final imageUrl = storyData['imageUrl'] as String? ?? '';
            final timestamp = storyData['timestamp'] as int? ?? 0;
            final seenBy = List<String>.from(storyData['seenBy'] ?? []);

            final now = DateTime.now().millisecondsSinceEpoch;
            final difference = now - timestamp;
            if (difference > (24 * 60 * 60 * 1000)) continue;

            try {
              final storyUserDoc = await _firestore
                  .collection('users')
                  .doc(userId)
                  .get();

              if (!storyUserDoc.exists) continue;

              final userData = storyUserDoc.data()!;
              final userName = userData['username'] ?? userData['name'] ?? 'Unknown';
              final userAvatar = userData['profileImage'] ?? userData['profile_picture_url'] ?? '';

              final isSeen = seenBy.contains(currentUserId);

              loadedStories.add(Story(
                id: storyId,
                userId: userId,
                userName: userName,
                userAvatar: userAvatar,
                imageUrl: imageUrl,
                timestamp: timestamp,
                isSeen: isSeen,
                seenBy: seenBy,
              ));
            } catch (e) {
              debugPrint('❌ Error fetching story user data: $e');
            }
          }
        }

        loadedStories.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        final myStories = loadedStories.where((s) => s.userId == currentUserId).toList();
        final otherStories = loadedStories.where((s) => s.userId != currentUserId).toList();

        final currentUserDoc = await _firestore.collection('users').doc(currentUserId).get();
        final currentUserData = currentUserDoc.data() ?? {};

        final yourStory = Story(
          id: 'your_story',
          userId: currentUserId,
          userName: 'Your Story',
          userAvatar: currentUserData['profileImage'] ?? currentUserData['profile_picture_url'] ?? '',
          imageUrl: '',
          timestamp: myStories.isNotEmpty ? myStories.first.timestamp : 0,
          isSeen: false,
          seenBy: [],
        );

        final allStories = [yourStory, ...otherStories];

        if (mounted) {
          setState(() {
            _stories = allStories;
            _isLoadingStories = false;
          });
        }
      });

      _subscriptions.add(subscription);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStories = false);
      }
    }
  }

  void _handleCreateGroup() {
    final groupNameController = TextEditingController();
    final groupDescController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Create Group',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: groupNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Group Name',
                    hintStyle: const TextStyle(color: Color(0xFF6B7280)),
                    filled: true,
                    fillColor: const Color(0xFF2D2D2D),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: groupDescController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Description (optional)',
                    hintStyle: const TextStyle(color: Color(0xFF6B7280)),
                    filled: true,
                    fillColor: const Color(0xFF2D2D2D),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        final groupName = groupNameController.text.trim();
                        if (groupName.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a group name'),
                              backgroundColor: Color(0xFF0095F6),
                            ),
                          );
                          return;
                        }

                        Navigator.pop(context);
                        await _createGroup(
                          groupName,
                          groupDescController.text.trim(),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0095F6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Create',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _createGroup(String name, String description) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final groupId = _rtdb.child('groups').push().key!;
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      await _rtdb.child('groups').child(groupId).child('info').set({
        'name': name,
        'description': description,
        'groupImage': '',
        'members': [currentUser.uid],
        'admins': [currentUser.uid],
        'createdBy': currentUser.uid,
        'createdAt': timestamp,
        'lastMessage': 'Group created',
        'lastTimestamp': timestamp,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Group "$name" created successfully!'),
            backgroundColor: const Color(0xFF22C55E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create group'),
            backgroundColor: Color(0xFF0095F6),
          ),
        );
      }
    }
  }

  void _handleAddStory() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uploading story...'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
      }

      final imageUrl = 'https://via.placeholder.com/500';
      await _uploadStory(imageUrl);
    } catch (e) {
      debugPrint('❌ Error adding story: $e');
    }
  }

  Future<void> _uploadStory(String imageUrl) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final storyId = _rtdb.child('stories').push().key!;
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      await _rtdb
          .child('stories')
          .child(currentUser.uid)
          .child(storyId)
          .set({
        'imageUrl': imageUrl,
        'timestamp': timestamp,
        'seenBy': [],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Story uploaded successfully!'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload story'),
            backgroundColor: Color(0xFF0095F6),
          ),
        );
      }
    }
  }

  Future<void> _markStoryAsSeen(Story story) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      if (story.seenBy.contains(currentUser.uid)) return;

      final updatedSeenBy = [...story.seenBy, currentUser.uid];

      await _rtdb
          .child('stories')
          .child(story.userId)
          .child(story.id)
          .update({
        'seenBy': updatedSeenBy,
      });
    } catch (e) {
      debugPrint('❌ Error marking story as seen: $e');
    }
  }

  Future<void> _openChat(Message message) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) return;

      final currentUserData = userDoc.data()!;

      final currentUserName = currentUserData['name'] ??
          currentUserData['username'] ??
          'You';

      final currentUserAvatar = currentUserData['profile_picture_url'] ??
          currentUserData['profileImage'] ??
          '';

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            currentUserId: currentUser.uid,
            currentUserName: currentUserName,
            currentUserAvatar: currentUserAvatar,
            receiverId: message.receiverId,
            receiverName: message.name,
            receiverAvatar: message.avatar,
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error opening chat: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Messages',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isOnline
                        ? const Color(0xFF22C55E)
                        : const Color(0xFF6B7280),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _isOnline
                        ? const Color(0xFF22C55E)
                        : const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(width: 4),
                Transform.scale(
                  scale: 0.7,
                  child: Switch(
                    value: _isOnline,
                    onChanged: (value) {
                      setState(() => _isOnline = value);
                      _updateOnlineStatus(value);
                    },
                    activeThumbColor: Colors.white,
                    activeTrackColor: const Color(0xFF22C55E),
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: const Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _buildMessagesTab(),
    );
  }

  Widget _buildMessagesTab() {
    if (_isLoadingMessages) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF0095F6),
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a conversation!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return _buildMessageItem(_messages[index]);
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 🔧 FIXED: _buildMessageItem() - Added pending status indicator badge
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildMessageItem(Message message) {
    return InkWell(
      onTap: () => _openChat(message),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFF2D2D2D), width: 1),
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: message.avatar.isNotEmpty
                      ? CachedNetworkImage(
                    imageUrl: message.avatar,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 56,
                      height: 56,
                      color: const Color(0xFF2D2D2D),
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 56,
                      height: 56,
                      color: const Color(0xFF2D2D2D),
                      child: const Icon(
                        Icons.person,
                        size: 30,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  )
                      : Container(
                    width: 56,
                    height: 56,
                    color: const Color(0xFF2D2D2D),
                    child: const Icon(
                      Icons.person,
                      size: 30,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
                if (message.isOnline)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: const Color(0xFF121212), width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          message.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        message.time,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.message,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // 🆕 FIX #3: Show unread count OR pending indicator
            if (message.unread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0095F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  message.unread.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ] else if (message.conversationStatus == 'pending') ...[
              // 🆕 NEW: Show "Pending" badge if conversation is awaiting acceptance
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500),  // Orange for pending status
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Pending',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGroupsTab() {
    if (_isLoadingGroups) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF0095F6),
        ),
      );
    }

    if (_groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group,
              size: 80,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No groups yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a group to get started!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _groups.length,
      itemBuilder: (context, index) {
        return _buildGroupItem(_groups[index]);
      },
    );
  }

  Widget _buildGroupItem(Group group) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GroupChatScreen(
              groupId: group.id,
              groupName: group.name,
              groupImage: group.groupImage,
              members: group.members,
              admins: group.admins,
              createdBy: group.createdBy,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFF2D2D2D), width: 1),
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3D3D3D), Color(0xFF2D2D2D)],
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      group.groupImage,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.group,
                          size: 30,
                          color: Color(0xFF6B7280),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF121212), width: 1),
                    ),
                    child: Text(
                      group.memberCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        group.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        group.time,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    group.lastMessage,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (group.unread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0095F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  group.unread.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStoriesTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          color: const Color(0xFF1E1E1E),
          child: SizedBox(
            height: 100,
            child: _isLoadingStories
                ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF0095F6),
              ),
            )
                : _stories.isEmpty
                ? const Center(
              child: Text(
                'No stories available',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 14,
                ),
              ),
            )
                : ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _stories.length,
              itemBuilder: (context, index) {
                return _buildStoryItem(_stories[index], isYourStory: index == 0);
              },
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0095F6),
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0095F6).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Share Your Story',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Let your friends know what you\'re up to',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF9CA3AF),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _handleAddStory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0095F6),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Add Story',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStoryItem(Story story, {bool isYourStory = false}) {
    return GestureDetector(
      onTap: () async {
        if (isYourStory) {
          _handleAddStory();
        } else {
          await _markStoryAsSeen(story);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Viewing ${story.userName}\'s story'),
                backgroundColor: const Color(0xFF22C55E),
                duration: const Duration(seconds: 1),
              ),
            );
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: story.isSeen || isYourStory
                        ? null
                        : const LinearGradient(
                      colors: [Color(0xFF0095F6), Color(0xFF00D4FF)],
                    ),
                    border: story.isSeen && !isYourStory
                        ? Border.all(color: const Color(0xFF4B5563), width: 2)
                        : null,
                    borderRadius: BorderRadius.circular(35),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(33),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(31),
                      child: Image.network(
                        story.userAvatar,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: const Color(0xFF2D2D2D),
                            child: const Icon(
                              Icons.person,
                              size: 35,
                              color: Color(0xFF6B7280),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                if (isYourStory)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0095F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1E1E1E), width: 2),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 70,
              child: Text(
                story.userName,
                style: TextStyle(
                  fontSize: 12,
                  color: isYourStory ? const Color(0xFF0095F6) : Colors.white,
                  fontWeight: isYourStory ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}