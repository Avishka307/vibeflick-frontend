import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String groupImage;
  final List<String> members;
  final List<String> admins;
  final String createdBy;

  const GroupChatScreen({
    Key? key,
    required this.groupId,
    required this.groupName,
    required this.groupImage,
    required this.members,
    required this.admins,
    required this.createdBy,
  }) : super(key: key);

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final DatabaseReference _rtdb;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _messages = [];
  Map<String, Map<String, dynamic>> _memberDetails = {};
  bool _isLoading = false;
  bool _isSending = false;
  bool _isInCall = false;
  String? _currentCallId;

  StreamSubscription? _messagesSubscription;
  StreamSubscription? _groupInfoSubscription;
  StreamSubscription? _callSubscription;

  late String _currentUserId;
  bool _isOwner = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _rtdb = FirebaseDatabase.instance.ref();
    _currentUserId = FirebaseAuth.instance.currentUser!.uid;

    _isOwner = widget.createdBy == _currentUserId;
    _isAdmin = widget.admins.contains(_currentUserId);

    _loadMemberDetails();
    _listenToMessages();
    _listenToGroupInfo();
    _checkActiveCall();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messagesSubscription?.cancel();
    _groupInfoSubscription?.cancel();
    _callSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadMemberDetails() async {
    for (String memberId in widget.members) {
      try {
        final userDoc = await _firestore.collection('users').doc(memberId).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          setState(() {
            _memberDetails[memberId] = {
              'name': userData['name'] ?? 'Unknown',
              'avatar': userData['profile_picture_url'] ?? '',
              'isOnline': userData['isOnline'] ?? false,
            };
          });
        }
      } catch (e) {
        debugPrint('Error loading member $memberId: $e');
      }
    }
  }

  void _listenToGroupInfo() {
    _groupInfoSubscription = _rtdb
        .child('groups/${widget.groupId}/info')
        .onValue
        .listen((event) {
      if (event.snapshot.exists && mounted) {
        // Group info updated - reload if needed
      }
    });
  }

  void _checkActiveCall() {
    _callSubscription = _rtdb
        .child('calls')
        .orderByChild('groupId')
        .equalTo(widget.groupId)
        .onValue
        .listen((event) {
      if (!mounted) return;

      if (event.snapshot.exists) {
        final callsMap = event.snapshot.value as Map<dynamic, dynamic>;

        for (var entry in callsMap.entries) {
          final callData = entry.value as Map<dynamic, dynamic>;
          if (callData['status'] == 'active') {
            setState(() {
              _isInCall = (callData['participants'] as List).contains(_currentUserId);
              _currentCallId = entry.key as String;
            });
            return;
          }
        }
      }

      setState(() {
        _isInCall = false;
        _currentCallId = null;
      });
    });
  }

  void _listenToMessages() {
    setState(() => _isLoading = true);

    _messagesSubscription = _rtdb
        .child('groups/${widget.groupId}/messages')
        .orderByChild('timestamp')
        .onValue
        .listen((event) {
      if (!mounted) return;

      if (!event.snapshot.exists) {
        if (mounted) {
          setState(() {
            _messages = [];
            _isLoading = false;
          });
        }
        return;
      }

      final messagesMap = event.snapshot.value as Map<dynamic, dynamic>;
      List<Map<String, dynamic>> loadedMessages = [];

      messagesMap.forEach((key, value) {
        final msgData = Map<String, dynamic>.from(value as Map);
        msgData['id'] = key;
        loadedMessages.add(msgData);
      });

      loadedMessages.sort((a, b) =>
          (a['timestamp'] as int).compareTo(b['timestamp'] as int));

      if (mounted) {
        setState(() {
          _messages = loadedMessages;
          _isLoading = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }

      // Mark messages as seen
      for (var msg in loadedMessages) {
        if (msg['senderId'] != _currentUserId) {
          _markMessageAsSeen(msg['id']);
        }
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    final messageId = const Uuid().v4();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final messageData = {
      'senderId': _currentUserId,
      'senderName': _memberDetails[_currentUserId]?['name'] ?? 'Unknown',
      'text': text,
      'timestamp': timestamp,
      'seenBy': [_currentUserId],
    };

    _messageController.clear();

    try {
      await _rtdb
          .child('groups/${widget.groupId}/messages/$messageId')
          .set(messageData);

      await _rtdb.child('groups/${widget.groupId}/info').update({
        'lastMessage': text,
        'lastTimestamp': timestamp,
      });

      if (mounted) {
        setState(() => _isSending = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markMessageAsSeen(String messageId) async {
    try {
      final msgRef = _rtdb.child('groups/${widget.groupId}/messages/$messageId');
      final snapshot = await msgRef.once();

      if (snapshot.snapshot.exists) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        final seenBy = List<String>.from(data['seenBy'] ?? []);

        if (!seenBy.contains(_currentUserId)) {
          seenBy.add(_currentUserId);
          await msgRef.update({'seenBy': seenBy});
        }
      }
    } catch (e) {
      debugPrint('Error marking as seen: $e');
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showGroupInfo() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupInfoScreen(
          groupId: widget.groupId,
          groupName: widget.groupName,
          groupImage: widget.groupImage,
          members: widget.members,
          admins: widget.admins,
          createdBy: widget.createdBy,
          memberDetails: _memberDetails,
        ),
      ),
    );

    // If group was deleted, pop this screen too
    if (result == 'deleted' && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _startVoiceCall() async {
    try {
      final callId = _rtdb.child('calls').push().key!;
      final currentUserName = _memberDetails[_currentUserId]?['name'] ?? 'Unknown';

      await _rtdb.child('calls/$callId').set({
        'groupId': widget.groupId,
        'startedBy': _currentUserId,
        'starterName': currentUserName,
        'startTime': DateTime.now().millisecondsSinceEpoch,
        'participants': [_currentUserId],
        'status': 'active',
      });

      setState(() {
        _isInCall = true;
        _currentCallId = callId;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice call started!'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start call: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _joinVoiceCall() async {
    if (_currentCallId == null) return;

    try {
      final callRef = _rtdb.child('calls/$_currentCallId');
      final snapshot = await callRef.once();

      if (snapshot.snapshot.exists) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        final participants = List<String>.from(data['participants'] ?? []);

        if (!participants.contains(_currentUserId)) {
          participants.add(_currentUserId);
          await callRef.update({'participants': participants});
        }

        setState(() => _isInCall = true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Joined voice call!'),
              backgroundColor: Color(0xFF22C55E),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to join call: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _leaveVoiceCall() async {
    if (_currentCallId == null) return;

    try {
      final callRef = _rtdb.child('calls/$_currentCallId');
      final snapshot = await callRef.once();

      if (snapshot.snapshot.exists) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        final participants = List<String>.from(data['participants'] ?? []);

        participants.remove(_currentUserId);

        if (participants.isEmpty) {
          await callRef.update({
            'status': 'ended',
            'endTime': DateTime.now().millisecondsSinceEpoch,
            'participants': [],
          });
        } else {
          await callRef.update({'participants': participants});
        }

        setState(() {
          _isInCall = false;
          _currentCallId = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Left voice call'),
              backgroundColor: Color(0xFF6B7280),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to leave call: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showMessageOptions(Map<String, dynamic> message) {
    final isMyMessage = message['senderId'] == _currentUserId;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isMyMessage)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete Message', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMessage(message['id']);
                  },
                ),
              if (!isMyMessage)
                ListTile(
                  leading: const Icon(Icons.report, color: Colors.orange),
                  title: const Text('Report Message', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _reportMessage(message);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await _rtdb.child('groups/${widget.groupId}/messages/$messageId').remove();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete message'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _reportMessage(Map<String, dynamic> message) async {
    try {
      await _firestore.collection('message_reports').add({
        'reporterId': _currentUserId,
        'reporterName': _memberDetails[_currentUserId]?['name'] ?? 'Unknown',
        'reportedUserId': message['senderId'],
        'messageId': message['id'],
        'messageText': message['text'],
        'groupId': widget.groupId,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
        'type': 'group_message',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message reported'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to report message'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
        title: GestureDetector(
          onTap: _showGroupInfo,
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF2D2D2D),
                child: widget.groupImage.isNotEmpty
                    ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: widget.groupImage,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const Icon(Icons.group, size: 20),
                  ),
                )
                    : const Icon(Icons.group, size: 20, color: Color(0xFF6B7280)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.groupName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${widget.members.length} members',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (!_isInCall && _currentCallId != null)
            IconButton(
              icon: const Icon(Icons.call, color: Color(0xFF22C55E)),
              onPressed: _joinVoiceCall,
              tooltip: 'Join ongoing call',
            ),
          if (_isInCall)
            IconButton(
              icon: const Icon(Icons.call_end, color: Colors.red),
              onPressed: _leaveVoiceCall,
              tooltip: 'Leave call',
            ),
          if (!_isInCall && _currentCallId == null)
            IconButton(
              icon: const Icon(Icons.call, color: Colors.white),
              onPressed: _startVoiceCall,
              tooltip: 'Start voice call',
            ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: _showGroupInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isInCall)
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF22C55E),
              child: Row(
                children: [
                  const Icon(Icons.call, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Voice call in progress...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: _leaveVoiceCall,
                    child: const Text(
                      'Leave',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF0095F6),
              ),
            )
                : _messages.isEmpty
                ? Center(
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
                    'No messages yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start the conversation!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              border: Border(
                top: BorderSide(color: Color(0xFF2D2D2D), width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !_isSending,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _isSending ? 'Sending...' : 'Type a message...',
                      hintStyle: const TextStyle(color: Color(0xFF6B7280)),
                      filled: true,
                      fillColor: const Color(0xFF2D2D2D),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0095F6),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: IconButton(
                    icon: _isSending
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Icon(Icons.send, color: Colors.white),
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMe = message['senderId'] == _currentUserId;
    final senderName = message['senderName'] ?? 'Unknown';
    final senderAvatar = _memberDetails[message['senderId']]?['avatar'] ?? '';

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isMe) ...[
              CircleAvatar(
                radius: 16,
                backgroundImage: senderAvatar.isNotEmpty
                    ? CachedNetworkImageProvider(senderAvatar)
                    : null,
                child: senderAvatar.isEmpty
                    ? const Icon(Icons.person, size: 16)
                    : null,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xFF0095F6) : const Color(0xFF2D2D2D),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          senderName,
                          style: const TextStyle(
                            color: Color(0xFF0095F6),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Text(
                      message['text'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTimestamp(message['timestamp'] as int),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'now';
    if (difference.inHours < 1) return '${difference.inMinutes}m';
    if (difference.inDays < 1) return '${difference.inHours}h';
    return '${difference.inDays}d';
  }
}

// =================== GROUP INFO SCREEN ===================

class GroupInfoScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String groupImage;
  final List<String> members;
  final List<String> admins;
  final String createdBy;
  final Map<String, Map<String, dynamic>> memberDetails;

  const GroupInfoScreen({
    Key? key,
    required this.groupId,
    required this.groupName,
    required this.groupImage,
    required this.members,
    required this.admins,
    required this.createdBy,
    required this.memberDetails,
  }) : super(key: key);

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  late String _currentUserId;
  late bool _isOwner;
  late bool _isAdmin;

  String _groupDescription = '';
  int _createdAt = 0;
  bool _isLoadingGroupInfo = true;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser!.uid;
    _isOwner = widget.createdBy == _currentUserId;
    _isAdmin = widget.admins.contains(_currentUserId);

    _loadGroupInfo();
  }

  Future<void> _loadGroupInfo() async {
    try {
      final groupRef = FirebaseDatabase.instance.ref('groups/${widget.groupId}/info');
      final snapshot = await groupRef.once();

      if (snapshot.snapshot.exists) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _groupDescription = data['description'] ?? '';
          _createdAt = data['createdAt'] ?? 0;
          _isLoadingGroupInfo = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading group info: $e');
      setState(() => _isLoadingGroupInfo = false);
    }
  }

  Future<void> _updateGroupLogo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) return;

      // In production, upload to Firebase Storage and get URL
      // For now, using placeholder
      final imageUrl = 'https://via.placeholder.com/300';

      final groupRef = FirebaseDatabase.instance.ref('groups/${widget.groupId}/info');
      await groupRef.update({'groupImage': imageUrl});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group logo updated!'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update logo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showAddMemberDialog() async {
    try {
      // Get current user's following and followers
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .get();

      if (!currentUserDoc.exists) return;

      final userData = currentUserDoc.data()!;
      final following = List<String>.from(userData['following'] ?? []);
      final followers = List<String>.from(userData['followers'] ?? []);

      // Get mutual friends (both following each other)
      final mutualFriends = following.where((id) => followers.contains(id)).toList();

      // Filter out current members
      final availableUsers = mutualFriends
          .where((id) => !widget.members.contains(id))
          .toList();

      if (availableUsers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No mutual friends available to add'),
            backgroundColor: Color(0xFF6B7280),
          ),
        );
        return;
      }

      // Fetch user details
      List<Map<String, dynamic>> usersList = [];
      for (String userId in availableUsers) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data()!;
          usersList.add({
            'id': userId,
            'name': data['name'] ?? data['username'] ?? 'Unknown',
            'avatar': data['profile_picture_url'] ?? '',
          });
        }
      }

      if (!mounted) return;

      // Show dialog to select users
      showDialog(
        context: context,
        builder: (context) => _AddMemberDialog(
          users: usersList,
          onAdd: (selectedIds) async {
            await _addMembers(selectedIds);
          },
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading friends: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addMembers(List<String> userIds) async {
    try {
      final groupRef = FirebaseDatabase.instance.ref('groups/${widget.groupId}/info');
      final snapshot = await groupRef.once();

      if (snapshot.snapshot.exists) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        final members = List<String>.from(data['members'] ?? []);

        for (String userId in userIds) {
          if (!members.contains(userId)) {
            members.add(userId);
          }
        }

        await groupRef.update({'members': members});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${userIds.length} member(s) added!'),
              backgroundColor: const Color(0xFF22C55E),
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add members: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteGroup() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Delete Group',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this group? This action cannot be undone.',
          style: TextStyle(color: Color(0xFF9CA3AF)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF9CA3AF)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Delete group from RTDB
      await FirebaseDatabase.instance.ref('groups/${widget.groupId}').remove();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group deleted successfully'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
        Navigator.pop(context, 'deleted');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete group: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Group Info'),
        actions: [
          if (_isOwner)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteGroup();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Delete Group', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoadingGroupInfo
          ? const Center(
        child: CircularProgressIndicator(color: Color(0xFF0095F6)),
      )
          : ListView(
        children: [
          // Group header
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFF2D2D2D),
                      child: widget.groupImage.isNotEmpty
                          ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: widget.groupImage,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                          const Icon(Icons.group, size: 50),
                        ),
                      )
                          : const Icon(Icons.group, size: 50),
                    ),
                    if (_isOwner || _isAdmin)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _updateGroupLogo,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0095F6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF121212),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  widget.groupName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Group • ${widget.members.length} members',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 14,
                  ),
                ),
                if (_createdAt > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Created ${_formatDate(_createdAt)}',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const Divider(color: Color(0xFF2D2D2D)),

          // Description section
          if (_groupDescription.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Description',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _groupDescription,
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: Color(0xFF2D2D2D)),
                ],
              ),
            ),

          // Members section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Members',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_isOwner || _isAdmin)
                  IconButton(
                    icon: const Icon(Icons.person_add, color: Color(0xFF0095F6)),
                    onPressed: _showAddMemberDialog,
                  ),
              ],
            ),
          ),

          ...widget.members.map((memberId) {
            final details = widget.memberDetails[memberId];
            final isOwner = memberId == widget.createdBy;
            final isAdmin = widget.admins.contains(memberId);

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: details?['avatar'] != null &&
                    details!['avatar'].isNotEmpty
                    ? CachedNetworkImageProvider(details['avatar'])
                    : null,
                child: details?['avatar'] == null ||
                    details!['avatar'].isEmpty
                    ? const Icon(Icons.person)
                    : null,
              ),
              title: Text(
                details?['name'] ?? 'Unknown',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                isOwner ? 'Owner' : isAdmin ? 'Admin' : 'Member',
                style: TextStyle(
                  color: isOwner
                      ? const Color(0xFF0095F6)
                      : const Color(0xFF6B7280),
                ),
              ),
              trailing: (_isOwner && memberId != _currentUserId)
                  ? PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) {
                  if (value == 'make_admin') {
                    _makeAdmin(memberId);
                  } else if (value == 'remove_admin') {
                    _removeAdmin(memberId);
                  } else if (value == 'remove') {
                    _removeMember(memberId);
                  }
                },
                itemBuilder: (context) => [
                  if (!isAdmin)
                    const PopupMenuItem(
                      value: 'make_admin',
                      child: Text('Make Admin'),
                    ),
                  if (isAdmin)
                    const PopupMenuItem(
                      value: 'remove_admin',
                      child: Text('Remove Admin'),
                    ),
                  const PopupMenuItem(
                    value: 'remove',
                    child: Text('Remove from Group'),
                  ),
                ],
              )
                  : null,
            );
          }).toList(),
        ],
      ),
    );
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) return 'today';
    if (difference.inDays == 1) return 'yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    if (difference.inDays < 30) return '${(difference.inDays / 7).floor()} weeks ago';
    if (difference.inDays < 365) return '${(difference.inDays / 30).floor()} months ago';
    return '${(difference.inDays / 365).floor()} years ago';
  }

  Future<void> _makeAdmin(String memberId) async {
    try {
      final groupRef =
      FirebaseDatabase.instance.ref('groups/${widget.groupId}/info');
      final snapshot = await groupRef.once();

      if (snapshot.snapshot.exists) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        final admins = List<String>.from(data['admins'] ?? []);

        if (!admins.contains(memberId)) {
          admins.add(memberId);
          await groupRef.update({'admins': admins});

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('User is now an admin'),
                backgroundColor: Color(0xFF22C55E),
              ),
            );
            Navigator.pop(context);
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _removeAdmin(String memberId) async {
    try {
      final groupRef =
      FirebaseDatabase.instance.ref('groups/${widget.groupId}/info');
      final snapshot = await groupRef.once();

      if (snapshot.snapshot.exists) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        final admins = List<String>.from(data['admins'] ?? []);

        admins.remove(memberId);
        await groupRef.update({'admins': admins});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Admin privileges removed'),
              backgroundColor: Color(0xFF22C55E),
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _removeMember(String memberId) async {
    try {
      final groupRef =
      FirebaseDatabase.instance.ref('groups/${widget.groupId}/info');
      final snapshot = await groupRef.once();

      if (snapshot.snapshot.exists) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        final members = List<String>.from(data['members'] ?? []);
        final admins = List<String>.from(data['admins'] ?? []);

        members.remove(memberId);
        admins.remove(memberId);

        await groupRef.update({
          'members': members,
          'admins': admins,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Member removed'),
              backgroundColor: Color(0xFF22C55E),
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

// =================== ADD MEMBER DIALOG ===================

class _AddMemberDialog extends StatefulWidget {
  final List<Map<String, dynamic>> users;
  final Function(List<String>) onAdd;

  const _AddMemberDialog({
    required this.users,
    required this.onAdd,
  });

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final Set<String> _selectedUsers = {};

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 500),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add Members',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select mutual friends to add',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.users.length,
                itemBuilder: (context, index) {
                  final user = widget.users[index];
                  final isSelected = _selectedUsers.contains(user['id']);

                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedUsers.add(user['id']);
                        } else {
                          _selectedUsers.remove(user['id']);
                        }
                      });
                    },
                    title: Text(
                      user['name'],
                      style: const TextStyle(color: Colors.white),
                    ),
                    secondary: CircleAvatar(
                      backgroundImage: user['avatar'].isNotEmpty
                          ? CachedNetworkImageProvider(user['avatar'])
                          : null,
                      child: user['avatar'].isEmpty
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    activeColor: const Color(0xFF0095F6),
                    checkColor: Colors.white,
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Color(0xFF9CA3AF)),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _selectedUsers.isEmpty
                      ? null
                      : () {
                    widget.onAdd(_selectedUsers.toList());
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0095F6),
                    disabledBackgroundColor: const Color(0xFF2D2D2D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    'Add (${_selectedUsers.length})',
                    style: const TextStyle(
                      color: Colors.white,
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
  }
}