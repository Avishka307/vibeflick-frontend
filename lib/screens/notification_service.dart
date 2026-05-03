import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// VibeFlick System Notification Service
/// Handles FCM token management, system notification creation,
/// and local notification display.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  // ─── Update this to your actual backend base URL ───────────────────────────
  static const String _backendBaseUrl = 'https://avishka-tiktok-api.zeabur.app';
  // ───────────────────────────────────────────────────────────────────────────

  // Android notification channel
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'vibeflick_system',
    'VibeFlick System',
    description: 'VibeFlick official system notifications',
    importance: Importance.high,
    playSound: true,
  );

  // ──────────────────────────────────────────────────────────────────────────
  // INIT
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    // 1. Request permission
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Init local notifications
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
    DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(initSettings);

    // 3. Create Android channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 4. Handle foreground FCM messages → show local notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // FCM TOKEN
  // ──────────────────────────────────────────────────────────────────────────

  /// Save FCM token to Firestore and backend for this user.
  Future<void> saveFcmToken(String uid) async {
    try {
      final token = await _fcm.getToken();
      if (token == null) return;

      // Save to Firestore
      await _firestore.collection('users').doc(uid).update({
        'fcm_token': token,
        'fcm_token_updated': FieldValue.serverTimestamp(),
      });

      // Also register with backend endpoint
      await http.post(
        Uri.parse('$_backendBaseUrl/api/users/$uid/fcm-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token}),
      );

      debugPrint('✅ FCM token saved for $uid');

      // Listen for token refresh
      _fcm.onTokenRefresh.listen((newToken) async {
        await _firestore.collection('users').doc(uid).update({
          'fcm_token': newToken,
          'fcm_token_updated': FieldValue.serverTimestamp(),
        });
        await http.post(
          Uri.parse('$_backendBaseUrl/api/users/$uid/fcm-token'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'token': newToken}),
        );
        debugPrint('🔄 FCM token refreshed');
      });
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SYSTEM NOTIFICATIONS → FIRESTORE
  // ──────────────────────────────────────────────────────────────────────────

  /// Check if a specific system notification was already sent to this user.
  Future<bool> _wasAlreadySent(String uid, String notifKey) async {
    try {
      final doc = await _firestore
          .collection('user_system_notifications')
          .doc('${uid}_$notifKey')
          .get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  /// Mark a notification as sent so it won't be sent again.
  Future<void> _markAsSent(String uid, String notifKey) async {
    await _firestore
        .collection('user_system_notifications')
        .doc('${uid}_$notifKey')
        .set({
      'uid': uid,
      'key': notifKey,
      'sent_at': FieldValue.serverTimestamp(),
    });
  }

  /// Add a notification document to the user's system_notifications
  /// sub-collection (read by vibeflick_official_screen).
  Future<void> _addToUserNotifications({
    required String uid,
    required String id,
    required String type,
    required String title,
    required String message,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('system_notifications')
        .doc(id)
        .set({
      'id': id,
      'type': type,
      'title': title,
      'message': message,
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 1. WELCOME NOTIFICATION
  // ──────────────────────────────────────────────────────────────────────────

  /// Send a personalised welcome notification after login / register.
  /// Fires only once per user (idempotent).
  Future<void> sendWelcomeNotification({
    required String uid,
    required String userName,
  }) async {
    const key = 'welcome';
    if (await _wasAlreadySent(uid, key)) {
      debugPrint('ℹ️ Welcome notification already sent, skipping.');
      return;
    }

    const notifId = 'sys_welcome';
    const title = 'Welcome to VibeFlick! 🌹';
    final body = 'Hi $userName, Welcome to VibeFlick! '
        'Explore, share, and connect with the world.';

    // Write to Firestore so the UI stream picks it up
    await _addToUserNotifications(
      uid: uid,
      id: notifId,
      type: 'welcome',
      title: title,
      message: body,
    );

    // Ask the backend to push the FCM notification
    try {
      await http.post(
        Uri.parse('$_backendBaseUrl/api/notifications/welcome'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': uid, 'userName': userName}),
      );
    } catch (e) {
      debugPrint('❌ Backend welcome notification failed: $e');
    }

    await _markAsSent(uid, key);
    debugPrint('✅ Welcome notification sent for $userName');
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 2. ENABLE NOTIFICATIONS PROMPT
  // ──────────────────────────────────────────────────────────────────────────

  /// Write an "Enable Notifications" system card into the user's feed.
  /// Only written once; shown right after the welcome notification.
  Future<void> sendEnableNotificationsCard(String uid) async {
    const key = 'enable_notifications';
    if (await _wasAlreadySent(uid, key)) return;

    await _addToUserNotifications(
      uid: uid,
      id: 'sys_enable_notifs',
      type: 'enable_notifications',
      title: 'Enable Notifications 🔔',
      message:
      'Turn on push notifications to stay updated on likes, comments, '
          'follows, and messages from your community.',
    );

    await _markAsSent(uid, key);
    debugPrint('✅ Enable-notifications card added');
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. COMMUNITY GUIDELINES
  // ──────────────────────────────────────────────────────────────────────────

  /// Write a Community Guidelines system card.  Sent once per user.
  Future<void> sendCommunityGuidelinesNotification(String uid) async {
    const key = 'community_guidelines';
    if (await _wasAlreadySent(uid, key)) return;

    await _addToUserNotifications(
      uid: uid,
      id: 'sys_community_guidelines',
      type: 'community_guidelines',
      title: 'Community Guidelines 📋',
      message:
      'Please take a moment to review our Community Guidelines. '
          'Together we keep VibeFlick a safe and creative space for everyone.',
    );

    await _markAsSent(uid, key);
    debugPrint('✅ Community guidelines notification sent');
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 4. FIRST MEDIA MILESTONE
  // ──────────────────────────────────────────────────────────────────────────

  /// Called after every media upload.  Checks the user's media collection;
  /// if this is their first upload, sends the milestone notification once.
  Future<void> checkAndSendFirstMediaMilestone(String uid) async {
    const key = 'first_media_milestone';
    if (await _wasAlreadySent(uid, key)) return;

    try {
      // Count documents in the user's media sub-collection
      final mediaSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('media')
          .limit(1)
          .get();

      if (mediaSnap.docs.isEmpty) {
        // No media yet – nothing to do
        return;
      }

      // Determine media type for a friendlier message (photo vs video)
      final firstDoc = mediaSnap.docs.first.data();
      final mediaType = (firstDoc['type'] as String? ?? '').toLowerCase();
      final mediaLabel = mediaType.contains('video') ? 'video' : 'media';

      await _addToUserNotifications(
        uid: uid,
        id: 'sys_first_media_milestone',
        type: 'milestone',
        title: 'First ${mediaLabel == 'video' ? 'Video' : 'Media'} Milestone! 🎬',
        message:
        'You uploaded your first $mediaLabel on VibeFlick! '
            'Keep sharing your amazing moments with the world. 🌟',
      );

      await _markAsSent(uid, key);
      debugPrint('✅ First media milestone notification sent');
    } catch (e) {
      debugPrint('❌ Error checking first media milestone: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 5. COMPLETE YOUR PROFILE
  // ──────────────────────────────────────────────────────────────────────────

  /// Profile fields that must ALL be non-empty for the profile to be "complete".
  static const List<String> _requiredProfileFields = [
    'name',
    'username',
    'bio',
    'gender',
    'birthday',
    'region',
  ];

  /// Call this inside `_handleSave()` in `edit_profile_screen.dart` after
  /// the Firestore update succeeds.
  ///
  /// Checks whether every required field is filled.
  /// If yes → sends "Complete Your Profile 📝" notification (once only).
  /// If no  → removes any previously-sent flag so it can fire again later
  ///          when the user eventually completes their profile.
  Future<void> checkAndSendProfileCompleteNotification(String uid) async {
    const key = 'profile_complete';

    try {
      // Read current Firestore user document
      final userDoc =
      await _firestore.collection('users').doc(uid).get();
      final data = userDoc.data() ?? {};

      // Check every required field is present and non-empty
      final bool allFilled = _requiredProfileFields.every((field) {
        final value = data[field];
        return value != null &&
            value.toString().trim().isNotEmpty &&
            value.toString().trim() != 'Add a bio to your profile';
      });

      if (!allFilled) {
        debugPrint('ℹ️ Profile not yet complete – skipping notification.');
        return;
      }

      // Profile is complete – send notification only once
      if (await _wasAlreadySent(uid, key)) {
        debugPrint('ℹ️ Profile-complete notification already sent, skipping.');
        return;
      }

      final userName = data['name'] as String? ?? 'there';

      await _addToUserNotifications(
        uid: uid,
        id: 'sys_profile_complete',
        type: 'profile_complete',
        title: 'Complete Your Profile 📝',
        message:
        'Great job $userName! Your profile is now 100% complete. '
            'You\'re all set to explore and connect on VibeFlick! 🎉',
      );

      await _markAsSent(uid, key);
      debugPrint('✅ Profile-complete notification sent for $userName');
    } catch (e) {
      debugPrint('❌ Error in checkAndSendProfileCompleteNotification: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // CONVENIENCE: send all onboarding notifications at once
  // ──────────────────────────────────────────────────────────────────────────

  /// Call this right after a successful login / register / Google sign-in.
  /// Sends welcome, enable-notifications, and community-guidelines cards –
  /// each only once per user.
  Future<void> sendOnboardingNotifications({
    required String uid,
    required String userName,
  }) async {
    await sendWelcomeNotification(uid: uid, userName: userName);
    await sendEnableNotificationsCard(uid);
    await sendCommunityGuidelinesNotification(uid);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // LOCAL NOTIFICATION (foreground FCM)
  // ──────────────────────────────────────────────────────────────────────────

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}