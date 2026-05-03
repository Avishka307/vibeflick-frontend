import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

class ActivityNotification extends StatefulWidget {
  const ActivityNotification({Key? key}) : super(key: key);

  @override
  State<ActivityNotification> createState() => _ActivityNotificationState();
}

class _ActivityNotificationState extends State<ActivityNotification> {
  late SharedPreferences _prefs;
  bool _isInitialized = false;

  // Backend URL - මෙතන ඔබේ server IP එක දාන්න
  static const String BACKEND_URL = "https://avishka-tiktok-api.zeabur.app";

  // Current user
  String? _currentUserId;

  // Notification states
  bool _likesEnabled = true;
  bool _commentsEnabled = true;
  bool _followersEnabled = true;
  bool _mentionsEnabled = true;
  bool _messagesEnabled = true;
  bool _updatesEnabled = false;
  bool _tagsEnabled = true; // ✅ NEW: Tags notification preference

  // Loading states
  bool _likesLoading = false;
  bool _commentsLoading = false;
  bool _followersLoading = false;
  bool _mentionsLoading = false;
  bool _messagesLoading = false;
  bool _updatesLoading = false;
  bool _tagsLoading = false; // ✅ NEW: Tags loading state

  // ── Thought Interactions states ──────────────────────────────────────────────
  bool _thoughtLikesEnabled = true;
  bool _thoughtRepliesEnabled = true;
  bool _thoughtRepostsEnabled = true;

  // ── Thought Interactions loading ──────────────────────────────────────────────
  bool _thoughtLikesLoading = false;
  bool _thoughtRepliesLoading = false;
  bool _thoughtRepostsLoading = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _initializePreferences();
  }

  Future<void> _initializePreferences() async {
    try {
      _prefs = await SharedPreferences.getInstance();

      // Load preferences from SharedPreferences
      _loadPreferences();

      // Load preferences from backend (optional - to sync)
      await _loadPreferencesFromBackend();

    } catch (e) {
      debugPrint('❌ Error initializing preferences: $e');
      setState(() {
        _isInitialized = true;
      });
    }
  }

  void _loadPreferences() {
    setState(() {
      _likesEnabled = _prefs.getBool('likes_enabled') ?? true;
      _commentsEnabled = _prefs.getBool('comments_enabled') ?? true;
      _followersEnabled = _prefs.getBool('followers_enabled') ?? true;
      _mentionsEnabled = _prefs.getBool('mentions_enabled') ?? true;
      _messagesEnabled = _prefs.getBool('messages_enabled') ?? true;
      _updatesEnabled = _prefs.getBool('updates_enabled') ?? false;
      _tagsEnabled = _prefs.getBool('tags_enabled') ?? true; // ✅ NEW: Load tags preference

      // ── Thought Interactions ──
      _thoughtLikesEnabled   = _prefs.getBool('thought_likes_enabled')   ?? true;
      _thoughtRepliesEnabled = _prefs.getBool('thought_replies_enabled') ?? true;
      _thoughtRepostsEnabled = _prefs.getBool('thought_reposts_enabled') ?? true;

      _isInitialized = true;
    });

    debugPrint('✅ Preferences loaded from local storage');
  }

  // ✅ Check internet connection
  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } on SocketException catch (_) {
      return false;
    }
    return false;
  }

  // ✅ NEW: Load preferences from backend
  Future<void> _loadPreferencesFromBackend() async {
    if (_currentUserId == null) {
      debugPrint('⚠️ No user logged in - skipping backend sync');
      return;
    }

    try {
      debugPrint('🔄 Loading preferences from backend...');

      final url = Uri.parse('$BACKEND_URL/api/notification-preferences/$_currentUserId');

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⏰ Backend request timeout');
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['preferences'] != null) {
          final preferences = data['preferences'];

          debugPrint('✅ Backend preferences loaded: $preferences');

          // Update local storage and state
          setState(() {
            _likesEnabled = preferences['likes'] ?? true;
            _commentsEnabled = preferences['comments'] ?? true;
            _followersEnabled = preferences['followers'] ?? true;
            _mentionsEnabled = preferences['mentions'] ?? true;
            _messagesEnabled = preferences['messages'] ?? true;
            _updatesEnabled = preferences['updates'] ?? false;
            _tagsEnabled = preferences['tags'] ?? preferences['mentions'] ?? true; // ✅ NEW: Load tags (fallback to mentions)

            // ── Thought Interactions ──
            _thoughtLikesEnabled   = preferences['thought_likes']   ?? true;
            _thoughtRepliesEnabled = preferences['thought_replies'] ?? true;
            _thoughtRepostsEnabled = preferences['thought_reposts'] ?? true;
          });

          // Save to local storage
          await _prefs.setBool('likes_enabled', _likesEnabled);
          await _prefs.setBool('comments_enabled', _commentsEnabled);
          await _prefs.setBool('followers_enabled', _followersEnabled);
          await _prefs.setBool('mentions_enabled', _mentionsEnabled);
          await _prefs.setBool('messages_enabled', _messagesEnabled);
          await _prefs.setBool('updates_enabled', _updatesEnabled);
          await _prefs.setBool('tags_enabled', _tagsEnabled); // ✅ NEW: Save tags preference

          // ── Thought Interactions ──
          await _prefs.setBool('thought_likes_enabled',   _thoughtLikesEnabled);
          await _prefs.setBool('thought_replies_enabled', _thoughtRepliesEnabled);
          await _prefs.setBool('thought_reposts_enabled', _thoughtRepostsEnabled);

          debugPrint('✅ Local storage synced with backend');
        }
      } else {
        debugPrint('⚠️ Backend returned error: ${response.statusCode}');
      }

    } catch (e) {
      debugPrint('❌ Error loading preferences from backend: $e');
      // Continue with local preferences
    }
  }

  Future<void> _handleSwitchChange({
    required String prefKey,
    required String topic,
    required bool newValue,
    required Function(bool) updateState,
    required Function(bool) updateLoading,
  }) async {
    // ✅ Check internet connection first
    final hasInternet = await _checkInternetConnection();
    if (!hasInternet) {
      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(
                    Icons.wifi_off,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No internet connection. Please check your network.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.red[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        } catch (e) {
          debugPrint('⚠️ Could not show snackbar: $e');
        }
      }
      return;
    }

    // Show loading
    updateLoading(true);

    try {
      debugPrint('\n🔄 ========== NOTIFICATION PREFERENCE CHANGE ==========');
      debugPrint('📝 Key: $prefKey');
      debugPrint('🎯 Topic: $topic');
      debugPrint('💫 New Value: $newValue');

      // Handle Firebase topic
      await _handleFirebaseTopic(topic, newValue);

      // Save preference locally
      await _prefs.setBool(prefKey, newValue);
      debugPrint('✅ Saved to local storage');

      // ✅ NEW: Save to Firestore backend
      await _savePreferencesToBackend(newValue, prefKey);

      // Update state
      updateState(newValue);

      debugPrint('==========================================\n');

      // Show success message
      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    newValue ? Icons.notifications_active : Icons.notifications_off,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      newValue
                          ? 'Notifications enabled'
                          : 'Notifications disabled',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 2),
              backgroundColor: newValue ? const Color(0xFFFF3B5C) : Colors.grey[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        } catch (e) {
          debugPrint('⚠️ Could not show snackbar: $e');
        }
      }

    } catch (e) {
      debugPrint('❌ Failed to update notification setting: $e');

      // Revert on failure
      updateState(!newValue);

      // Show error message
      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Failed to update settings. Please try again.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.red[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        } catch (e) {
          debugPrint('⚠️ Could not show error snackbar: $e');
        }
      }
    } finally {
      // Hide loading
      updateLoading(false);
    }
  }

  // ✅ NEW: Save preferences to backend
  Future<void> _savePreferencesToBackend(bool enabled, String prefKey) async {
    if (_currentUserId == null) {
      debugPrint('⚠️ No user logged in - skipping backend save');
      return;
    }

    try {
      // Map preference keys to notification types
      final Map<String, String> keyMapping = {
        'likes_enabled': 'likes',
        'comments_enabled': 'comments',
        'followers_enabled': 'followers',
        'mentions_enabled': 'mentions',
        'messages_enabled': 'messages',
        'updates_enabled': 'updates',
        'tags_enabled': 'tags', // ✅ NEW: Add tags mapping
        // ── Thought Interactions ──
        'thought_likes_enabled':   'thought_likes',
        'thought_replies_enabled': 'thought_replies',
        'thought_reposts_enabled': 'thought_reposts',
      };

      final notificationType = keyMapping[prefKey];
      if (notificationType == null) {
        debugPrint('⚠️ Unknown preference key: $prefKey');
        return;
      }

      // Get all current preferences
      final preferences = {
        'likes': _prefs.getBool('likes_enabled') ?? true,
        'comments': _prefs.getBool('comments_enabled') ?? true,
        'followers': _prefs.getBool('followers_enabled') ?? true,
        'mentions': _prefs.getBool('mentions_enabled') ?? true,
        'messages': _prefs.getBool('messages_enabled') ?? true,
        'updates': _prefs.getBool('updates_enabled') ?? false,
        'tags': _prefs.getBool('tags_enabled') ?? true, // ✅ NEW: Include tags
        // ── Thought Interactions ──
        'thought_likes':   _prefs.getBool('thought_likes_enabled')   ?? true,
        'thought_replies': _prefs.getBool('thought_replies_enabled') ?? true,
        'thought_reposts': _prefs.getBool('thought_reposts_enabled') ?? true,
      };

      // Update the changed preference
      preferences[notificationType] = enabled;

      final url = Uri.parse('$BACKEND_URL/api/notification-preferences/$_currentUserId');

      debugPrint('💾 Saving preferences to backend...');
      debugPrint('   URL: $url');
      debugPrint('   Type: $notificationType');
      debugPrint('   Value: $enabled');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'preferences': preferences,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⏰ Backend save timeout');
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Preferences saved to backend successfully');
        debugPrint('   Response: ${data['message']}');
      } else {
        debugPrint('⚠️ Backend returned error: ${response.statusCode}');
        debugPrint('   Response: ${response.body}');
      }

    } catch (e) {
      debugPrint('❌ Error saving preferences to backend: $e');
      // Don't rethrow - preferences still saved locally
    }
  }

  Future<void> _handleFirebaseTopic(String topic, bool subscribe) async {
    try {
      if (subscribe) {
        await FirebaseMessaging.instance.subscribeToTopic(topic);
        debugPrint('✅ Subscribed to topic: $topic');
      } else {
        await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
        debugPrint('✅ Unsubscribed from topic: $topic');
      }
    } catch (e) {
      debugPrint('❌ Firebase topic error: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F0F),
        body: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: Color(0xFFFF3B5C),
              strokeWidth: 2.5,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: FutureBuilder<bool>(
        future: _checkInternetConnection(),
        builder: (context, snapshot) {
          final hasConnection = snapshot.data ?? true;

          return Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHeader(),
                    _buildContent(),
                  ],
                ),
              ),

              // ── No Connection Overlay ──
              if (!hasConnection)
                Positioned.fill(
                  child: Container(
                    color: const Color(0xFF0F0F0F).withOpacity(0.95),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1A1A1A),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.wifi_off_rounded,
                            color: Color(0xFF888888),
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No Internet Connection',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Notification settings require an active\nconnection to sync properly.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF888888),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 55, 16, 16),
      color: const Color(0xFF0F0F0F),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 40), // Balance for back button
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _buildSectionHeader('Push Notifications'),
        _buildNotificationItem(
          emoji: '❤️',
          title: 'Likes',
          subtitle: 'Get notified when someone likes your videos or comments',
          value: _likesEnabled,
          isLoading: _likesLoading,
          onChanged: (value) => _handleSwitchChange(
            prefKey: 'likes_enabled',
            topic: 'likes',
            newValue: value,
            updateState: (val) => setState(() => _likesEnabled = val),
            updateLoading: (val) => setState(() => _likesLoading = val),
          ),
        ),
        _buildDivider(),
        _buildNotificationItem(
          emoji: '💬',
          title: 'Comments',
          subtitle: 'Be notified when people comment on your posts',
          value: _commentsEnabled,
          isLoading: _commentsLoading,
          onChanged: (value) => _handleSwitchChange(
            prefKey: 'comments_enabled',
            topic: 'comments',
            newValue: value,
            updateState: (val) => setState(() => _commentsEnabled = val),
            updateLoading: (val) => setState(() => _commentsLoading = val),
          ),
        ),
        _buildDivider(),
        _buildNotificationItem(
          emoji: '👥',
          title: 'New Followers',
          subtitle: 'Get notified when someone starts following you',
          value: _followersEnabled,
          isLoading: _followersLoading,
          onChanged: (value) => _handleSwitchChange(
            prefKey: 'followers_enabled',
            topic: 'followers',
            newValue: value,
            updateState: (val) => setState(() => _followersEnabled = val),
            updateLoading: (val) => setState(() => _followersLoading = val),
          ),
        ),
        _buildDivider(),
        _buildNotificationItem(
          emoji: '@',
          emojiColor: const Color(0xFFFF6B9D),
          title: 'Mentions',
          subtitle: 'When someone mentions you in their post or comment',
          value: _mentionsEnabled,
          isLoading: _mentionsLoading,
          onChanged: (value) => _handleSwitchChange(
            prefKey: 'mentions_enabled',
            topic: 'mentions',
            newValue: value,
            updateState: (val) => setState(() => _mentionsEnabled = val),
            updateLoading: (val) => setState(() => _mentionsLoading = val),
          ),
        ),
        _buildDivider(),
        // ✅ NEW: Tags notification option
        _buildNotificationItem(
          emoji: '🏷️',
          title: 'Tags',
          subtitle: 'Get notified when someone tags you in a post',
          value: _tagsEnabled,
          isLoading: _tagsLoading,
          onChanged: (value) => _handleSwitchChange(
            prefKey: 'tags_enabled',
            topic: 'tags',
            newValue: value,
            updateState: (val) => setState(() => _tagsEnabled = val),
            updateLoading: (val) => setState(() => _tagsLoading = val),
          ),
        ),
        _buildDivider(),
        _buildNotificationItem(
          emoji: '📩',
          title: 'Messages',
          subtitle: 'Receive alerts for new chat messages',
          value: _messagesEnabled,
          isLoading: _messagesLoading,
          onChanged: (value) => _handleSwitchChange(
            prefKey: 'messages_enabled',
            topic: 'messages',
            newValue: value,
            updateState: (val) => setState(() => _messagesEnabled = val),
            updateLoading: (val) => setState(() => _messagesLoading = val),
          ),
        ),

        // ════════════════════════════════════════════════════════════════════
        // 💭 Thought Interactions Section
        // ════════════════════════════════════════════════════════════════════
        _buildSectionHeader('Thought Interactions'),

        _buildNotificationItem(
          emoji: '💭',
          title: 'Likes on Thoughts',
          subtitle: 'Get notified when someone likes your shared thoughts',
          value: _thoughtLikesEnabled,
          isLoading: _thoughtLikesLoading,
          onChanged: (value) => _handleSwitchChange(
            prefKey: 'thought_likes_enabled',
            topic: 'thought_likes',
            newValue: value,
            updateState: (val) => setState(() => _thoughtLikesEnabled = val),
            updateLoading: (val) => setState(() => _thoughtLikesLoading = val),
          ),
        ),
        _buildDivider(),

        _buildNotificationItem(
          emoji: '↩️',
          title: 'Replies on Thoughts',
          subtitle: 'Be notified when people reply to your thoughts',
          value: _thoughtRepliesEnabled,
          isLoading: _thoughtRepliesLoading,
          onChanged: (value) => _handleSwitchChange(
            prefKey: 'thought_replies_enabled',
            topic: 'thought_replies',
            newValue: value,
            updateState: (val) => setState(() => _thoughtRepliesEnabled = val),
            updateLoading: (val) => setState(() => _thoughtRepliesLoading = val),
          ),
        ),
        _buildDivider(),

        _buildNotificationItem(
          emoji: '🔁',
          title: 'Reposts',
          subtitle: 'When someone reposts your thought to their feed',
          value: _thoughtRepostsEnabled,
          isLoading: _thoughtRepostsLoading,
          onChanged: (value) => _handleSwitchChange(
            prefKey: 'thought_reposts_enabled',
            topic: 'thought_reposts',
            newValue: value,
            updateState: (val) => setState(() => _thoughtRepostsEnabled = val),
            updateLoading: (val) => setState(() => _thoughtRepostsLoading = val),
          ),
        ),

        // ════════════════════════════════════════════════════════════════════
        _buildSectionHeader('Other'),
        _buildNotificationItem(
          emoji: '📢',
          title: 'App Updates',
          subtitle: 'Be notified about app news and trending videos',
          value: _updatesEnabled,
          isLoading: _updatesLoading,
          onChanged: (value) => _handleSwitchChange(
            prefKey: 'updates_enabled',
            topic: 'app_updates',
            newValue: value,
            updateState: (val) => setState(() => _updatesEnabled = val),
            updateLoading: (val) => setState(() => _updatesLoading = val),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF888888),
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildNotificationItem({
    required String emoji,
    Color? emojiColor,
    required String title,
    required String subtitle,
    required bool value,
    required bool isLoading,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: isLoading ? null : () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon Container
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: value
                      ? const Color(0xFFFF3B5C).withOpacity(0.3)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: TextStyle(
                    fontSize: emoji == '@' ? 28 : 24,
                    color: emojiColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF888888),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // 🎨 iOS-Style Animated Switch or Loading
            SizedBox(
              width: 52,
              height: 32,
              child: isLoading
                  ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFFF3B5C),
                    ),
                  ),
                ),
              )
                  : GestureDetector(
                onTap: () => onChanged(!value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 52,
                  height: 32,
                  decoration: BoxDecoration(
                    color: value ? const Color(0xFFFF3B5C) : const Color(0xFF3A3A3A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
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

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.only(left: 84),
      height: 1,
      color: const Color(0xFF1A1A1A),
    );
  }

  // Static helper method
  static Future<bool> isNotificationEnabled(String type) async {
    final prefs = await SharedPreferences.getInstance();
    switch (type) {
      case 'likes':
        return prefs.getBool('likes_enabled') ?? true;
      case 'comments':
        return prefs.getBool('comments_enabled') ?? true;
      case 'followers':
        return prefs.getBool('followers_enabled') ?? true;
      case 'mentions':
        return prefs.getBool('mentions_enabled') ?? true;
      case 'messages':
        return prefs.getBool('messages_enabled') ?? true;
      case 'updates':
        return prefs.getBool('updates_enabled') ?? false;
      case 'tags': // ✅ NEW: Add tags check
        return prefs.getBool('tags_enabled') ?? true;
    // ── Thought Interactions ──
      case 'thought_likes':
        return prefs.getBool('thought_likes_enabled') ?? true;
      case 'thought_replies':
        return prefs.getBool('thought_replies_enabled') ?? true;
      case 'thought_reposts':
        return prefs.getBool('thought_reposts_enabled') ?? true;
      default:
        return false;
    }
  }
}