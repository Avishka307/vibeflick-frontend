import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:my_vibe_flick/screens/post_detail_page.dart';
import 'package:uuid/uuid.dart';

import 'activity_user_profile.dart';
import 'message_report_service.dart';

class ChatScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final String currentUserAvatar;
  final String receiverId;
  final String receiverName;
  final String receiverAvatar;

  const ChatScreen({
    Key? key,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserAvatar,
    required this.receiverId,
    required this.receiverName,
    required this.receiverAvatar,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final DatabaseReference _rtdb;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late String _chatRoomId;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isTyping = false;
  bool _isSending = false;
  bool _isReceiverOnline = false;
  int? _lastSeenTimestamp;

  // 🆕 NEW: Status tracking
  String _chatStatus = 'checking'; // checking, pending, accepted, declined
  bool _isRequestSender = false;
  bool _isBlockedUser = false; // 🆕
  // Reply & Reactions
  Map<String, dynamic>? _replyingTo;
  Map<String, Map<String, String>> _reactions = {}; // messageId → {userId: emoji}

  // Pin
  String? _pinnedMessageId;
  String? _pinnedMessageText;

  // Wallpaper
  String? _chatWallpaper; // null = default dark
  StreamSubscription? _typingSubscription;
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _onlineStatusSubscription;
  StreamSubscription? _statusSubscription;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _rtdb = FirebaseDatabase.instance.ref();
    FirebaseDatabase.instance.setPersistenceEnabled(true);

    _chatRoomId = _getChatRoomId();
    debugPrint('🔥 Chat initialized: $_chatRoomId');

    _checkOrCreateConversation();
    _listenToMessages();
    _listenToTyping();
    _listenToOnlineStatus();
    _listenToStatus();
    _checkIfBlocked(); // 🆕
    _loadChatSettings();
    _listenToReactions();
    _listenToPinnedMessage();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingSubscription?.cancel();
    _messagesSubscription?.cancel();
    _onlineStatusSubscription?.cancel();
    _statusSubscription?.cancel();
    _typingTimer?.cancel();
    _stopTyping();
    super.dispose();
  }

  String _getChatRoomId() {
    List<String> ids = [widget.currentUserId, widget.receiverId];
    ids.sort();
    return '${ids[0]}_${ids[1]}';
  }

// 🆕 BLOCK CHECK
  Future<void> _checkIfBlocked() async {
    try {
      final db = FirebaseFirestore.instance;
      final myId = widget.currentUserId;
      final theirId = widget.receiverId;

      final results = await Future.wait([
        db.collection('blocked_users')
            .where('blockerId', isEqualTo: myId)
            .where('blockedId', isEqualTo: theirId)
            .limit(1).get(),
        db.collection('blocked_users')
            .where('blockerId', isEqualTo: theirId)
            .where('blockedId', isEqualTo: myId)
            .limit(1).get(),
      ]);

      if (mounted) {
        setState(() {
          _isBlockedUser = results.any((snap) => snap.docs.isNotEmpty);
        });
      }
    } catch (e) {
      debugPrint('❌ Chat block check error: $e');
    }
  }
// ── Load chat settings (wallpaper, pin) ──────────────────────────
  Future<void> _loadChatSettings() async {
    try {
      final settingsRef = _rtdb
          .child('chatSettings')
          .child(_chatRoomId)
          .child(widget.currentUserId);
      final snapshot = await settingsRef.get();
      if (snapshot.exists && mounted) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _chatWallpaper = data['wallpaper'] as String?;
        });
      }
    } catch (e) {
      debugPrint('❌ Load chat settings error: $e');
    }
  }

  // ── Listen to reactions ───────────────────────────────────────────
  void _listenToReactions() {
    _rtdb
        .child('chatRooms')
        .child(_chatRoomId)
        .child('reactions')
        .onValue
        .listen((event) {
      if (event.snapshot.exists && mounted) {
        final raw = event.snapshot.value as Map<dynamic, dynamic>;
        final Map<String, Map<String, String>> parsed = {};
        raw.forEach((msgId, reactions) {
          if (reactions is Map) {
            parsed[msgId.toString()] = Map<String, String>.from(
                reactions.map((k, v) => MapEntry(k.toString(), v.toString())));
          }
        });
        setState(() => _reactions = parsed);
      }
    });
  }

  // ── Listen to pinned message ──────────────────────────────────────
  void _listenToPinnedMessage() {
    _rtdb
        .child('chatRooms')
        .child(_chatRoomId)
        .child('info')
        .child('pinnedMessage')
        .onValue
        .listen((event) {
      if (mounted) {
        if (event.snapshot.exists) {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          setState(() {
            _pinnedMessageId = data['id'] as String?;
            _pinnedMessageText = data['text'] as String?;
          });
        } else {
          setState(() {
            _pinnedMessageId = null;
            _pinnedMessageText = null;
          });
        }
      }
    });
  }

  // ── Add reaction ──────────────────────────────────────────────────
  Future<void> _addReaction(String messageId, String emoji) async {
    try {
      await _rtdb
          .child('chatRooms')
          .child(_chatRoomId)
          .child('reactions')
          .child(messageId)
          .child(widget.currentUserId)
          .set(emoji);
    } catch (e) {
      debugPrint('❌ Reaction error: $e');
    }
  }

  // ── Remove reaction ───────────────────────────────────────────────
  Future<void> _removeReaction(String messageId) async {
    try {
      await _rtdb
          .child('chatRooms')
          .child(_chatRoomId)
          .child('reactions')
          .child(messageId)
          .child(widget.currentUserId)
          .remove();
    } catch (e) {
      debugPrint('❌ Remove reaction error: $e');
    }
  }

  // ── Show reaction picker ──────────────────────────────────────────
  void _showReactionPicker(Map<String, dynamic> message) {
    final emojis = ['❤️', '😂', '😮', '😢', '👍', '🔥'];
    final msgId = message['id'] as String;
    final myReaction = _reactions[msgId]?[widget.currentUserId];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji picker row
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D2D2D),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: emojis.map((emoji) {
                    final isSelected = myReaction == emoji;
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        if (isSelected) {
                          _removeReaction(msgId);
                        } else {
                          _addReaction(msgId, emoji);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF0095F6).withOpacity(0.3)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(emoji,
                            style: const TextStyle(fontSize: 28)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              // Message options
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2D2D2D),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.reply_rounded,
                          color: Colors.white),
                      title: const Text('Reply',
                          style: TextStyle(color: Colors.white)),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() => _replyingTo = message);
                      },
                    ),
                    const Divider(
                        color: Color(0xFF3D3D3D), height: 1),
                    if (message['senderId'] == widget.currentUserId) ...[
                      ListTile(
                        leading: Icon(
                          _pinnedMessageId == msgId
                              ? Icons.push_pin
                              : Icons.push_pin_outlined,
                          color: Colors.white,
                        ),
                        title: Text(
                          _pinnedMessageId == msgId
                              ? 'Unpin Message'
                              : 'Pin Message',
                          style:
                          const TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _pinnedMessageId == msgId
                              ? _unpinMessage()
                              : _pinMessage(message);
                        },
                      ),
                      const Divider(
                          color: Color(0xFF3D3D3D), height: 1),
                    ],
                    ListTile(
                      leading: const Icon(Icons.copy_rounded,
                          color: Colors.white),
                      title: const Text('Copy',
                          style: TextStyle(color: Colors.white)),
                      onTap: () {
                        Navigator.pop(context);
                        _copyMessage(message['text'] ?? '');
                      },
                    ),
                    const Divider(
                        color: Color(0xFF3D3D3D), height: 1),
                    if (message['senderId'] == widget.currentUserId)
                      ListTile(
                        leading: const Icon(Icons.delete_rounded,
                            color: Colors.red),
                        title: const Text('Delete',
                            style: TextStyle(color: Colors.red)),
                        onTap: () {
                          Navigator.pop(context);
                          _deleteMessage(message['id']);
                        },
                      )
                    else
                      ListTile(
                        leading: const Icon(Icons.report_rounded,
                            color: Colors.orange),
                        title: const Text('Report',
                            style:
                            TextStyle(color: Colors.orange)),
                        onTap: () {
                          Navigator.pop(context);
                          _reportMessage(message);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Seen time
              if (message['senderId'] == widget.currentUserId &&
                  message['isSeen'] == true)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D2D2D),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.done_all_rounded,
                          color: Color(0xFF22C55E), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Seen ${_formatExactTime(message['timestamp'] as int)}',
                        style: const TextStyle(
                            color: Color(0xFF22C55E), fontSize: 13),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── Pin message ───────────────────────────────────────────────────
  Future<void> _pinMessage(Map<String, dynamic> message) async {
    try {
      await _rtdb
          .child('chatRooms')
          .child(_chatRoomId)
          .child('info')
          .child('pinnedMessage')
          .set({
        'id': message['id'],
        'text': message['text'] ?? '📎 Media',
        'pinnedBy': widget.currentUserId,
        'pinnedAt': DateTime.now().millisecondsSinceEpoch,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message pinned'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Pin error: $e');
    }
  }

  // ── Unpin message ─────────────────────────────────────────────────
  Future<void> _unpinMessage() async {
    try {
      await _rtdb
          .child('chatRooms')
          .child(_chatRoomId)
          .child('info')
          .child('pinnedMessage')
          .remove();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message unpinned'),
            backgroundColor: Color(0xFF6B7280),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Unpin error: $e');
    }
  }

  // ── Copy message ──────────────────────────────────────────────────
  Future<void> _copyMessage(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied to clipboard'),
          backgroundColor: Color(0xFF374151),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  // ── Wallpaper picker ──────────────────────────────────────────────
  void _showWallpaperPicker() {
    final wallpapers = [
      null, // Default dark
      '0xFF1a1a2e', // Dark blue
      '0xFF16213e', // Navy
      '0xFF0f3460', // Deep blue
      '0xFF1b1b2f', // Dark purple
      '0xFF162447', // Dark teal
      '0xFF1f4068', // Steel blue
      '0xFF1b262c', // Dark green-grey
    ];

    final labels = [
      'Default',
      'Dark Blue',
      'Navy',
      'Deep Blue',
      'Dark Purple',
      'Dark Teal',
      'Steel Blue',
      'Slate',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Chat Wallpaper',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: wallpapers.length,
                itemBuilder: (context, index) {
                  final wp = wallpapers[index];
                  final isSelected = _chatWallpaper == wp;
                  final color = wp == null
                      ? const Color(0xFF121212)
                      : Color(int.parse(wp));

                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _setChatWallpaper(wp);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF0095F6)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isSelected)
                            const Icon(Icons.check_circle,
                                color: Color(0xFF0095F6), size: 20),
                          const SizedBox(height: 4),
                          Text(
                            labels[index],
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // ── Set wallpaper ─────────────────────────────────────────────────
  Future<void> _setChatWallpaper(String? wallpaper) async {
    try {
      await _rtdb
          .child('chatSettings')
          .child(_chatRoomId)
          .child(widget.currentUserId)
          .update({'wallpaper': wallpaper ?? 'default'});

      if (mounted) setState(() => _chatWallpaper = wallpaper);
    } catch (e) {
      debugPrint('❌ Wallpaper error: $e');
    }
  }

  // ── Format exact time ─────────────────────────────────────────────
  String _formatExactTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    final timeStr =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    if (difference.inDays == 0) return 'today at $timeStr';
    if (difference.inDays == 1) return 'yesterday at $timeStr';
    return '${date.day}/${date.month} at $timeStr';
  }
  // 🆕 NEW: Check or create conversation with status
  Future<void> _checkOrCreateConversation() async {
    try {
      final chatRoomRef = _rtdb.child('chatRooms').child(_chatRoomId);
      final snapshot = await chatRoomRef.child('info').get();

      if (!snapshot.exists) {
        // Create new conversation with pending status
        await chatRoomRef.child('info').set({
          'lastMessage': '',
          'lastTimestamp': DateTime
              .now()
              .millisecondsSinceEpoch,
          'participants': [widget.currentUserId, widget.receiverId],
          'status': 'pending',
          'requestedBy': widget.currentUserId,
          'createdAt': DateTime
              .now()
              .millisecondsSinceEpoch,
        });

        setState(() {
          _chatStatus = 'pending';
          _isRequestSender = true;
        });

        debugPrint('✅ New conversation created with pending status');
      } else {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final status = data['status'] ?? 'accepted';
        final requestedBy = data['requestedBy'] ?? '';

        setState(() {
          _chatStatus = status;
          _isRequestSender = requestedBy == widget.currentUserId;
        });

        debugPrint('✅ Existing conversation found: status=$status');
      }
    } catch (e) {
      debugPrint('❌ Error checking conversation: $e');
    }
  }

  // 🆕 NEW: Listen to status changes
  void _listenToStatus() {
    _statusSubscription = _rtdb
        .child('chatRooms')
        .child(_chatRoomId)
        .child('info')
        .onValue
        .listen((event) {
      if (event.snapshot.exists && mounted) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final status = data['status'] ?? 'accepted';
        final requestedBy = data['requestedBy'] ?? '';

        setState(() {
          _chatStatus = status;
          _isRequestSender = requestedBy == widget.currentUserId;
        });

        debugPrint(
            '📊 Status updated: $status (requestSender: $_isRequestSender)');
      }
    });
  }

  // 🆕 NEW: Accept conversation request
  Future<void> _acceptRequest() async {
    try {
      await _rtdb.child('chatRooms').child(_chatRoomId).child('info').update({
        'status': 'accepted',
        'acceptedAt': DateTime
            .now()
            .millisecondsSinceEpoch,
      });

      // 🔔 Mark all pending messages as seen after accepting
      final messagesSnapshot = await _rtdb
          .child('chatRooms')
          .child(_chatRoomId)
          .child('messages')
          .get();

      if (messagesSnapshot.exists) {
        final messagesMap = messagesSnapshot.value as Map<dynamic, dynamic>;
        for (var msgEntry in messagesMap.entries) {
          final msgData = msgEntry.value as Map<dynamic, dynamic>;
          if (msgData['senderId'] != widget.currentUserId) {
            await _rtdb
                .child('chatRooms')
                .child(_chatRoomId)
                .child('messages')
                .child(msgEntry.key)
                .update({'isSeen': true});
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request accepted! You can now chat'),
            backgroundColor: Colors.green,
          ),
        );
      }

      debugPrint('✅ Request accepted');
    } catch (e) {
      debugPrint('❌ Error accepting request: $e');
    }
  }

  // 🆕 NEW: Decline conversation request (completely removes chat from sender's view)
  Future<void> _declineRequest() async {
    try {
      // Delete the entire chat room
      await _rtdb.child('chatRooms').child(_chatRoomId).remove();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request declined'),
            backgroundColor: Colors.red,
          ),
        );

        // Navigate back after decline
        Navigator.pop(context);
      }

      debugPrint('❌ Request declined - Chat removed completely');
    } catch (e) {
      debugPrint('❌ Error declining request: $e');
    }
  }

  void _listenToOnlineStatus() {
    _onlineStatusSubscription = _firestore
        .collection('users')
        .doc(widget.receiverId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data();
        setState(() {
          _isReceiverOnline = data?['isOnline'] ?? false;
          _lastSeenTimestamp = data?['lastSeen'];
        });
      }
    });
  }

  void _listenToMessages() {
    setState(() => _isLoading = true);

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    });

    _messagesSubscription = _rtdb
        .child('chatRooms')
        .child(_chatRoomId)
        .child('messages')
        .orderByChild('timestamp')
        .onValue
        .listen((event) {
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

      // 🆕 UPDATED: Only mark as seen if status is accepted
      if (_chatStatus == 'accepted') {
        for (var msg in loadedMessages) {
          if (msg['senderId'] != widget.currentUserId &&
              msg['isSeen'] == false) {
            _markMessageAsSeen(msg['id']);
          }
        }
      }
    }, onError: (error) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _sendMessage({String? stickerUrl, String type = 'text'}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && stickerUrl == null) return;

    if (_isSending) return;

    setState(() => _isSending = true);

    final messageId = const Uuid().v4();
    final timestamp = DateTime
        .now()
        .millisecondsSinceEpoch;

    final messageData = {
      'senderId': widget.currentUserId,
      'receiverId': widget.receiverId,
      'text': text,
      'type': type,
      'stickerUrl': stickerUrl ?? '',
      'timestamp': timestamp,
      'isSeen': false,
      // Reply support
      if (_replyingTo != null) 'replyTo': {
        'id': _replyingTo!['id'],
        'text': _replyingTo!['text'] ?? '',
        'senderId': _replyingTo!['senderId'],
      },
    };


    _messageController.clear();
    _stopTyping();
    setState(() => _replyingTo = null); // Clear reply
    try {
      final messageRef = _rtdb
          .child('chatRooms')
          .child(_chatRoomId)
          .child('messages')
          .child(messageId);

      await messageRef.set(messageData).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Message send timeout');
        },
      );

      final infoRef = _rtdb.child('chatRooms').child(_chatRoomId).child('info');

      await infoRef.update({
        'lastMessage': type == 'sticker' ? '🎨 Sticker' : text,
        'lastTimestamp': timestamp,
      });
// 🔔 Send FCM notification
      _sendMessageNotification(
        messageText: text,
        messageType: type,
        stickerUrl: stickerUrl,
      );
      if (mounted) {
        setState(() => _isSending = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Send failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

// 🔔 Send message notification via FCM
  Future<void> _sendMessageNotification({
    String? messageText,
    String messageType = 'text',
    String? stickerUrl,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(
            'https://avishka-tiktok-api.zeabur.app/api/messages/send-notification'),


        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'senderId': widget.currentUserId,
          'senderName': widget.currentUserName,
          'receiverId': widget.receiverId,
          'messageText': messageText ?? '',
          'messageType': messageType,
          'chatRoomId': _chatRoomId,
          'stickerUrl': stickerUrl ?? '',
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Message notification sent');
      } else {
        debugPrint('⚠️ Message notification failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('⚠️ Message notification error (non-critical): $e');
      // Don't block message sending if notification fails
    }
  }

  Future<void> _markMessageAsSeen(String messageId) async {
    try {
      await _rtdb
          .child('chatRooms')
          .child(_chatRoomId)
          .child('messages')
          .child(messageId)
          .update({'isSeen': true});
    } catch (e) {
      debugPrint('❌ Error marking as seen: $e');
    }
  }

  void _onTyping() {
    _rtdb
        .child('typing')
        .child(_chatRoomId)
        .child(widget.currentUserId)
        .set(true);

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), _stopTyping);
  }

  void _stopTyping() {
    _rtdb
        .child('typing')
        .child(_chatRoomId)
        .child(widget.currentUserId)
        .remove();
  }

  void _listenToTyping() {
    _typingSubscription = _rtdb
        .child('typing')
        .child(_chatRoomId)
        .child(widget.receiverId)
        .onValue
        .listen((event) {
      if (mounted) {
        setState(() {
          _isTyping = event.snapshot.value == true;
        });
      }
    });
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

  void _showStickerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery
              .of(context)
              .size
              .height * 0.6,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Choose a Sticker',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(child: _buildStickerGrid()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStickerGrid() {
    final stickerAssets = [
      'assets/stickers/anatomical-heart.json',
      'assets/stickers/bouquet.json',
      'assets/stickers/clinking-glasses.json',
      'assets/stickers/clown.json',
      'assets/stickers/dancer-woman.json',
      'assets/stickers/disguise.json',
      'assets/stickers/drum.json',
      'assets/stickers/fire-heart.json',
      'assets/stickers/glowing-star.json',
      'assets/stickers/hand-with-index-finger-and-thumb-crossed.json',
      'assets/stickers/heart-balloons.json',
      'assets/stickers/rubber-duck.json',
      'assets/stickers/saxophone.json',
      'assets/stickers/social-media-like.json',
      'assets/stickers/star.json',
      'assets/stickers/violin.json',
      'assets/stickers/volcano.json',
      'assets/stickers/xmas-star.json',
      'assets/stickers/successfully-done.json',
      'assets/stickers/astronot.json',
      'assets/stickers/couple-taking-photo.json',
      'assets/stickers/kiss.json',
      'assets/stickers/bouquet (1).json',
      'assets/stickers/winne-the-pooh.json',
    ];

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: stickerAssets.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            Navigator.pop(context);
            _sendMessage(
              stickerUrl: stickerAssets[index],
              type: 'sticker',
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Lottie.asset(
                stickerAssets[index],
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMessageOptions(Map<String, dynamic> message) {
    final isMyMessage = message['senderId'] == widget.currentUserId;

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
                  title: const Text(
                      'Delete Message', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMessage(message['id']);
                  },
                ),
              if (!isMyMessage)
                ListTile(
                  leading: const Icon(Icons.report, color: Colors.orange),
                  title: const Text(
                      'Report Message', style: TextStyle(color: Colors.white)),
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
      await _rtdb
          .child('chatRooms')
          .child(_chatRoomId)
          .child('messages')
          .child(messageId)
          .remove();

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
        'reporterId': widget.currentUserId,
        'reporterName': widget.currentUserName,
        'reportedUserId': message['senderId'],
        'messageId': message['id'],
        'messageText': message['text'],
        'chatRoomId': _chatRoomId,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
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

  void _showReportSheet() {
    String? selectedReason;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery
                    .of(context)
                    .viewInsets
                    .bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Report User',
                        style: TextStyle(fontSize: 18,
                            fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  const Divider(color: Color(0xFF2D2D2D), height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Text(
                      'Why are you reporting @${widget.receiverName}?',
                      style: const TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 14),
                    ),
                  ),
                  ...MessageReportService.reportReasons.map((reason) {
                    return RadioListTile<String>(
                      value: reason,
                      groupValue: selectedReason,
                      onChanged: (val) =>
                          setModalState(() => selectedReason = val),
                      title: Text(reason,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15)),
                      activeColor: const Color(0xFFFF3B5C),
                      tileColor: Colors.transparent,
                    );
                  }),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: selectedReason == null
                            ? null
                            : () async {
                          Navigator.pop(ctx);
                          await _submitUserReport(selectedReason!);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF3B5C),
                          disabledBackgroundColor: const Color(0xFF3A3A3A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Submit Report',
                            style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.bold, fontSize: 15)),
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

  Future<void> _submitUserReport(String reason) async {
    // ── Get last message preview ────────────────────────────────────
    String preview = '';
    if (_messages.isNotEmpty) {
      final last = _messages.last;
      preview = last['text'] as String? ?? '';
      if (preview.length > 120) preview = preview.substring(0, 120);
    }

    final result = await MessageReportService.submitMessageReport(
      reportedUserId: widget.receiverId,
      reportedUsername: widget.receiverName,
      reason: reason,
      messagePreview: preview,
      chatRoomId: _chatRoomId,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted. We will review within 24 hours.'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
      // Block ද කරන්නද? ─ Ask user
      _askBlockAfterReport();
    } else if (result.isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have already reported this user.'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report failed: ${result.errorMessage ?? "Unknown"}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  // ── Ask to block after report (WhatsApp style) ───────────────────
  void _askBlockAfterReport() {
    showDialog(
      context: context,
      builder: (ctx) =>
          AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('Block User?',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 17)),
            content: Text(
              'Do you also want to block @${widget.receiverName}? '
                  'They won\'t be able to send you messages anymore.',
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14,
                  height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('No, thanks',
                    style: TextStyle(color: Color(0xFF6B7280))),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _blockUser();
                },
                child: const Text('Block',
                    style: TextStyle(color: Color(0xFFFF3B5C),
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
    );
  }

  // ── Confirm block dialog ─────────────────────────────────────────
  void _confirmBlockUser() {
    showDialog(
      context: context,
      builder: (ctx) =>
          AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('Block User?',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 17)),
            content: Text(
              '@${widget.receiverName} won\'t be able to send you messages. '
                  'They won\'t be notified that you blocked them.',
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14,
                  height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel',
                    style: TextStyle(color: Color(0xFF6B7280))),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _blockUser();
                },
                child: const Text('Block',
                    style: TextStyle(color: Color(0xFFFF3B5C),
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
    );
  }

  // ── Block user ───────────────────────────────────────────────────
  Future<void> _blockUser() async {
    try {
      final myId = widget.currentUserId;
      final theirId = widget.receiverId;

      // Firestore ලෝ block save කරන්න
      await _firestore.collection('blocked_users').add({
        'blockerId': myId,
        'blockedId': theirId,
        'blockedUsername': widget.receiverName,
        'timestamp': DateTime
            .now()
            .millisecondsSinceEpoch,
      });

      // Local state update
      if (mounted) setState(() => _isBlockedUser = true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('@${widget.receiverName} has been blocked.'),
          backgroundColor: Colors.red.shade700,
        ),
      );

      // Chat screen ලෝ ඉඳලා back කරන්න
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      debugPrint('❌ Block error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to block user. Try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
// ── Check: මමද block කළේ? ────────────────────────────────────────
  Future<bool> _didIBlockThem() async {
    try {
      final result = await _firestore
          .collection('blocked_users')
          .where('blockerId', isEqualTo: widget.currentUserId)
          .where('blockedId', isEqualTo: widget.receiverId)
          .limit(1)
          .get();
      return result.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // ── Unblock user ─────────────────────────────────────────────────
  Future<void> _unblockUser() async {
    // Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Unblock User?',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17)),
        content: Text(
          '@${widget.receiverName} will be able to send you messages again.',
          style: const TextStyle(
              color: Color(0xFF9CA3AF), fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unblock',
                style: TextStyle(
                    color: Color(0xFF22C55E),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Firestore ලෝ block record delete කරන්න
      final snapshot = await _firestore
          .collection('blocked_users')
          .where('blockerId', isEqualTo: widget.currentUserId)
          .where('blockedId', isEqualTo: widget.receiverId)
          .limit(1)
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }

      if (mounted) {
        setState(() => _isBlockedUser = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('@${widget.receiverName} has been unblocked.'),
            backgroundColor: const Color(0xFF22C55E),
          ),
        );
      }

      debugPrint('✅ User unblocked: ${widget.receiverName}');
    } catch (e) {
      debugPrint('❌ Unblock error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to unblock. Try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  void _showUserOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.report_rounded, color: Colors.orange),
                title: const Text('Report User',
                    style: TextStyle(color: Colors.white, fontSize: 15)),
                subtitle: const Text('Flag inappropriate behaviour',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _showReportSheet();
                },
              ),
              const Divider(color: Color(0xFF2D2D2D), height: 1),
              ListTile(
                leading: const Icon(Icons.block_rounded, color: Colors.red),
                title: const Text('Block User',
                    style: TextStyle(color: Colors.white, fontSize: 15)),
                subtitle: const Text('Stop receiving messages from this user',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmBlockUser();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActivityUserProfile(userId: widget.receiverId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _chatWallpaper != null
        ? Color(int.parse(_chatWallpaper!))
        : const Color(0xFF121212);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: _navigateToProfile,
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: widget.receiverAvatar.isNotEmpty
                        ? CachedNetworkImageProvider(widget.receiverAvatar)
                        : null,
                    child: widget.receiverAvatar.isEmpty
                        ? const Icon(Icons.person, size: 20)
                        : null,
                  ),
                  if (_isReceiverOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color(0xFF1E1E1E), width: 2),
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
                    Text(
                      widget.receiverName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_isTyping)
                      const Text('typing...',
                          style: TextStyle(
                              color: Color(0xFF22C55E), fontSize: 12))
                    else
                      Text(
                        _isReceiverOnline
                            ? 'Online'
                            : _lastSeenTimestamp != null
                            ? 'Last seen ${_formatTimestamp(_lastSeenTimestamp!)}'
                            : 'Offline',
                        style: TextStyle(
                          color: _isReceiverOnline
                              ? const Color(0xFF22C55E)
                              : const Color(0xFF6B7280),
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
          IconButton(
            icon: const Icon(Icons.wallpaper_rounded, color: Colors.white),
            onPressed: _showWallpaperPicker,
            tooltip: 'Chat Wallpaper',
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: _showUserOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          // 📌 Pinned message banner
          if (_pinnedMessageId != null && _pinnedMessageText != null)
            GestureDetector(
              onTap: () {
                final idx = _messages.indexWhere(
                        (m) => m['id'] == _pinnedMessageId);
                if (idx != -1 && _scrollController.hasClients) {
                  _scrollController.animateTo(
                    idx * 80.0,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                color: const Color(0xFF1E3A5F),
                child: Row(
                  children: [
                    const Icon(Icons.push_pin,
                        color: Color(0xFF0095F6), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pinned Message',
                              style: TextStyle(
                                  color: Color(0xFF0095F6),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                          Text(
                            _pinnedMessageText!,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _unpinMessage,
                      child: const Icon(Icons.close,
                          color: Color(0xFF6B7280), size: 18),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF0095F6)),
            )
                : _messages.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 80,
                      color: Colors.white.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text('No messages yet',
                      style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withOpacity(0.6))),
                  const SizedBox(height: 8),
                  Text('Say hi to ${widget.receiverName}!',
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.4))),
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
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    // Pending status - Receiver's view (show Accept/Decline)
    if (_chatStatus == 'pending' && !_isRequestSender) {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            border: Border(
              top: BorderSide(color: Color(0xFF2D2D2D), width: 1),
            ),
          ),
          child: Column(
            children: [
              Text(
                '${widget.receiverName} wants to message you',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _acceptRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Accept',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _declineRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D2D2D),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Decline',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
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

    // Pending status - Sender's view
    if (_chatStatus == 'pending' && _isRequestSender) {
      if (_isBlockedUser) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              border: Border(top: BorderSide(color: Color(0xFF2D2D2D), width: 1)),
            ),
            child: FutureBuilder<bool>(
              future: _didIBlockThem(),
              builder: (context, snapshot) {
                final iBlockedThem = snapshot.data ?? false;
                if (iBlockedThem) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.block_rounded,
                              color: Colors.red.shade400, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'You blocked @${widget.receiverName}',
                            style: TextStyle(
                                color: Colors.red.shade400,
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _unblockUser,
                          icon: const Icon(Icons.lock_open_rounded,
                              color: Colors.white, size: 18),
                          label: Text(
                            'Unblock @${widget.receiverName}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF374151),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.block_rounded,
                          color: Colors.red.shade400, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'You can\'t reply to this conversation',
                        style: TextStyle(
                            color: Colors.red.shade400,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  );
                }
              },
            ),
          ),
        );
      }

      return SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            border: Border(
              top: BorderSide(color: Color(0xFF2D2D2D), width: 1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.access_time,
                        color: Color(0xFF6B7280), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Waiting for ${widget.receiverName} to accept',
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // ── Reply preview (pending sender) ──
              if (_replyingTo != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D2D2D),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 36,
                        color: const Color(0xFF0095F6),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _replyingTo!['senderId'] ==
                                  widget.currentUserId
                                  ? 'You'
                                  : widget.receiverName,
                              style: const TextStyle(
                                  color: Color(0xFF0095F6),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _replyingTo!['text'] ?? '',
                              style: const TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _replyingTo = null),
                        child: const Icon(Icons.close,
                            color: Color(0xFF6B7280), size: 18),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.emoji_emotions_outlined,
                        color: Color(0xFF9CA3AF)),
                    onPressed: _isSending ? null : _showStickerPicker,
                  ),
                  IconButton(
                    icon: const Icon(Icons.sticky_note_2_outlined,
                        color: Color(0xFF9CA3AF)),
                    onPressed: _isSending ? null : _showStickerPicker,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: !_isSending,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle:
                        const TextStyle(color: Color(0xFF6B7280)),
                        filled: true,
                        fillColor: const Color(0xFF2D2D2D),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                      ),
                      onChanged: (text) => _onTyping(),
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
                            color: Colors.white, strokeWidth: 2),
                      )
                          : const Icon(Icons.send, color: Colors.white),
                      onPressed: _isSending ? null : () => _sendMessage(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Accepted status - Normal chat input (with block check)
    if (_isBlockedUser) {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            border: Border(
                top: BorderSide(color: Color(0xFF2D2D2D), width: 1)),
          ),
          child: FutureBuilder<bool>(
            future: _didIBlockThem(),
            builder: (context, snapshot) {
              final iBlockedThem = snapshot.data ?? false;
              if (iBlockedThem) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.block_rounded,
                            color: Colors.red.shade400, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'You blocked @${widget.receiverName}',
                          style: TextStyle(
                              color: Colors.red.shade400,
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _unblockUser,
                        icon: const Icon(Icons.lock_open_rounded,
                            color: Colors.white, size: 18),
                        label: Text(
                          'Unblock @${widget.receiverName}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF374151),
                          padding:
                          const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.block_rounded,
                        color: Colors.red.shade400, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'You can\'t reply to this conversation',
                      style: TextStyle(
                          color: Colors.red.shade400,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                );
              }
            },
          ),
        ),
      );
    }

    // Normal accepted input
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          border: Border(
            top: BorderSide(color: Color(0xFF2D2D2D), width: 1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Reply preview ──────────────────────────────────────
            if (_replyingTo != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D2D2D),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 36,
                      color: const Color(0xFF0095F6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _replyingTo!['senderId'] ==
                                widget.currentUserId
                                ? 'You'
                                : widget.receiverName,
                            style: const TextStyle(
                                color: Color(0xFF0095F6),
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _replyingTo!['text'] ?? '',
                            style: const TextStyle(
                                color: Color(0xFF9CA3AF), fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _replyingTo = null),
                      child: const Icon(Icons.close,
                          color: Color(0xFF6B7280), size: 18),
                    ),
                  ],
                ),
              ),
            // ── Input row ──────────────────────────────────────────
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.emoji_emotions_outlined,
                      color: Color(0xFF9CA3AF)),
                  onPressed: _isSending ? null : _showStickerPicker,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !_isSending,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText:
                      _isSending ? 'Sending...' : 'Type a message...',
                      hintStyle:
                      const TextStyle(color: Color(0xFF6B7280)),
                      filled: true,
                      fillColor: const Color(0xFF2D2D2D),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                    ),
                    onChanged: (text) => _onTyping(),
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
                          color: Colors.white, strokeWidth: 2),
                    )
                        : const Icon(Icons.send, color: Colors.white),
                    onPressed: _isSending ? null : () => _sendMessage(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMe = message['senderId'] == widget.currentUserId;
    final msgId = message['id'] as String;
    final msgReactions = _reactions[msgId] ?? {};

    return GestureDetector(
      onLongPress: () => _showReactionPicker(message),
      child: Dismissible(
        key: Key('reply_$msgId'),
        direction: isMe
            ? DismissDirection.endToStart
            : DismissDirection.startToEnd,
        confirmDismiss: (_) async {
          setState(() => _replyingTo = message);
          return false; // Don't actually dismiss
        },
        background: Container(
          alignment:
          isMe ? Alignment.centerRight : Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: const Icon(Icons.reply_rounded,
              color: Color(0xFF0095F6), size: 28),
        ),
        child: Align(
          alignment:
          isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                constraints: BoxConstraints(
                  maxWidth:
                  MediaQuery.of(context).size.width * 0.7,
                ),
                decoration: BoxDecoration(
                  color: isMe
                      ? const Color(0xFF0095F6)
                      : const Color(0xFF2D2D2D),
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
                    // Reply preview inside bubble
                    if (message['replyTo'] != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(
                              color: isMe
                                  ? Colors.white.withOpacity(0.6)
                                  : const Color(0xFF0095F6),
                              width: 3,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              message['replyTo']['senderId'] ==
                                  widget.currentUserId
                                  ? 'You'
                                  : widget.receiverName,
                              style: TextStyle(
                                color: isMe
                                    ? Colors.white.withOpacity(0.9)
                                    : const Color(0xFF0095F6),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              message['replyTo']['text'] ?? '',
                              style: TextStyle(
                                color:
                                Colors.white.withOpacity(0.7),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Message content
                    if (message['type'] == 'post_share') ...[
                      _buildPostCard(message['postCard']),
                    ] else if (message['type'] == 'sticker')
                      message['stickerUrl'].startsWith('sticker_')
                          ? Text(
                        [
                          '😀','😂','❤️','👍','🎉',
                          '🔥','😍','👏','🙏','💯','✨','🎊'
                        ][int.tryParse(message['stickerUrl']
                            .replaceAll('sticker_', '')) ?? 0],
                        style:
                        const TextStyle(fontSize: 64),
                      )
                          : SizedBox(
                        width: 120,
                        height: 120,
                        child: Lottie.asset(
                          message['stickerUrl'],
                          fit: BoxFit.contain,
                        ),
                      )
                    else
                      Text(
                        message['text'] ?? '',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 15),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTimestamp(
                              message['timestamp'] as int),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 11,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            _chatStatus == 'pending'
                                ? Icons.done
                                : (message['isSeen'] == true
                                ? Icons.done_all
                                : Icons.done),
                            size: 14,
                            color: _chatStatus == 'pending'
                                ? Colors.white.withOpacity(0.7)
                                : (message['isSeen'] == true
                                ? const Color(0xFF22C55E)
                                : Colors.white
                                .withOpacity(0.7)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Reactions display
              if (msgReactions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D2D2D),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF3D3D3D)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...msgReactions.values
                          .toSet()
                          .map((emoji) => Text(emoji,
                          style:
                          const TextStyle(fontSize: 14))),
                      if (msgReactions.length > 1) ...[
                        const SizedBox(width: 4),
                        Text(
                          msgReactions.length.toString(),
                          style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
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

  Widget _buildPostCard(dynamic postCardData) {
    if (postCardData == null) return const SizedBox.shrink();

    final data = Map<String, dynamic>.from(postCardData as Map);
    final thumbnailUrl = data['thumbnailUrl'] as String? ?? '';
    final description = data['description'] as String? ?? '';
    final username = data['username'] as String? ?? '';
    final postId = data['postId'] as String? ?? '';

    // Extract hashtags and clean description
    final words = description.split(' ');
    final hashtagWords = words.where((w) => w.startsWith('#')).toList();
    final cleanDesc = words.where((w) => !w.startsWith('#')).join(' ').trim();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailPage(postId: postId),
          ),
        );
      },
      child: Container(
        width: 230,
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Thumbnail ──
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: Stack(
                children: [
                  // Thumbnail image
                  thumbnailUrl.isNotEmpty
                      ? Image.network(
                    thumbnailUrl,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(
                          height: 140,
                          color: const Color(0xFF2A2A2A),
                          child: const Center(
                            child: Icon(
                              Icons.videocam_rounded,
                              color: Color(0xFF555555),
                              size: 36,
                            ),
                          ),
                        ),
                  )
                      : Container(
                    height: 140,
                    color: const Color(0xFF2A2A2A),
                    child: const Center(
                      child: Icon(
                        Icons.videocam_rounded,
                        color: Color(0xFF555555),
                        size: 36,
                      ),
                    ),
                  ),

                  // Dark gradient overlay
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.5),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Play button overlay (center)
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.8),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Info section ──
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Creator name - clickable
                  GestureDetector(
                    onTap: () async {
                      try {
                        final querySnapshot = await _firestore
                            .collection('users')
                            .where('name', isEqualTo: username)
                            .limit(1)
                            .get();
                        if (querySnapshot.docs.isNotEmpty && mounted) {
                          final userId = querySnapshot.docs.first.id;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ActivityUserProfile(userId: userId),
                            ),
                          );
                        }
                      } catch (e) {
                        debugPrint('❌ Profile nav error: $e');
                      }
                    },
                    child: Text(
                      '@$username',
                      style: const TextStyle(
                        color: Color(0xFFFF3B5C),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),

                  if (cleanDesc.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      cleanDesc,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  if (hashtagWords.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      hashtagWords.join(' '),
                      style: TextStyle(
                        color: const Color(0xFF4A9EFF).withOpacity(0.85),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Tap to watch row
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B5C).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFF3B5C).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_circle_rounded,
                          color: Color(0xFFFF3B5C),
                          size: 13,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Tap to watch',
                          style: TextStyle(
                            color: Color(0xFFFF3B5C),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
