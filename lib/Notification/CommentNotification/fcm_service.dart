import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

// ✅ Import main.dart to access navigatorKey
import 'package:my_vibe_flick/main.dart';

// ✅ Import CommentBottomSheet
import '../../Comment/comment_bottom_sheet.dart';

// 🔔 FCM Service - Handles all Firebase Cloud Messaging operations
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Backend URL - CHANGE THIS TO YOUR SERVER IP
  static const String BACKEND_URL = "https://avishka-tiktok-api.zeabur.app";

  String? _currentToken;

  // =================== INITIALIZATION ===================

  /// Initialize FCM and request permissions
  Future<void> initialize() async {
    try {
      print('\n🔔 ========== INITIALIZING FCM SERVICE ==========');

      // 1️⃣ Request notification permissions
      print('📱 Requesting notification permissions...');
      final settings = await _requestPermissions();

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ Notification permissions granted');

        // 2️⃣ Get FCM token
        await _getFCMToken();

        // 3️⃣ Setup token refresh listener
        _setupTokenRefreshListener();

        // 4️⃣ ✅ CRITICAL: Setup background notification handler FIRST
        _setupBackgroundNotificationHandlers();

        // 5️⃣ Setup foreground notification handler
        _setupForegroundNotificationHandler();

        print('✅ FCM Service initialized successfully!');
      } else {
        print('❌ Notification permissions denied');
      }

      print('==========================================\n');
    } catch (e) {
      print('❌ FCM initialization error: $e');
    }
  }

  // =================== PERMISSIONS ===================

  /// Request notification permissions from user
  Future<NotificationSettings> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print('📋 Permission status: ${settings.authorizationStatus}');
    return settings;
  }

  // =================== TOKEN MANAGEMENT ===================

  /// Get FCM token and save to database
  Future<String?> _getFCMToken() async {
    try {
      print('\n📱 ========== GETTING FCM TOKEN ==========');

      // Get current user
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No user logged in');
        return null;
      }

      print('👤 Current user: ${user.uid}');

      // Get FCM token
      final token = await _messaging.getToken();

      if (token == null || token.isEmpty) {
        print('❌ Failed to get FCM token');
        return null;
      }

      _currentToken = token;
      print('✅ FCM Token obtained');
      print('🔑 Token preview: ${token.substring(0, 30)}...');
      print('📏 Token length: ${token.length} characters');

      // Save to Firestore
      await _saveTokenToFirestore(user.uid, token);

      // Save to backend
      await _saveTokenToBackend(user.uid, token);

      print('==========================================\n');

      return token;
    } catch (e) {
      print('❌ Error getting FCM token: $e');
      return null;
    }
  }

  /// Save FCM token to Firestore
  Future<void> _saveTokenToFirestore(String userId, String token) async {
    try {
      print('💾 Saving FCM token to Firestore...');
      print('   User ID: $userId');
      print('   Token: ${token.substring(0, 30)}...');

      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        'lastTokenUpdate': DateTime.now().toIso8601String(),
      });

      print('✅ FCM token saved to Firestore successfully!');

      // Verify save
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final savedToken = userDoc.data()?['fcmToken'];

      if (savedToken == token) {
        print('✅ Token verification successful!');
      } else {
        print('⚠️ Token verification failed - saved token differs');
      }
    } catch (e) {
      print('❌ Error saving token to Firestore: $e');
    }
  }

  /// Save FCM token to backend server
  Future<void> _saveTokenToBackend(String userId, String token) async {
    try {
      print('🌐 Saving FCM token to backend...');
      print('   URL: $BACKEND_URL/fcm-token');

      final response = await http.post(
        Uri.parse('$BACKEND_URL/fcm-token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'fcmToken': token,
        }),
      );

      print('📡 Backend response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Backend response: ${data['message']}');
      } else {
        print('⚠️ Backend returned status: ${response.statusCode}');
        print('   Response: ${response.body}');
      }
    } catch (e) {
      print('⚠️ Backend token save failed (non-critical): $e');
      print('   Token is still saved in Firestore ✅');
    }
  }

  /// Setup listener for token refresh
  void _setupTokenRefreshListener() {
    print('🔄 Setting up token refresh listener...');

    _messaging.onTokenRefresh.listen((newToken) async {
      print('\n🔄 ========== FCM TOKEN REFRESHED ==========');
      print('🔑 New token: ${newToken.substring(0, 30)}...');

      _currentToken = newToken;

      final user = _auth.currentUser;
      if (user != null) {
        await _saveTokenToFirestore(user.uid, newToken);
        await _saveTokenToBackend(user.uid, newToken);
        print('✅ New token saved successfully!');
      }

      print('==========================================\n');
    });

    print('✅ Token refresh listener active');
  }

  // =================== ✅ FIXED NOTIFICATION HANDLERS ===================

  /// ✅ Setup background notification handlers - MUST HANDLE TERMINATED STATE
  void _setupBackgroundNotificationHandlers() {
    print('🌙 Setting up background notification handlers...');

    // ✅ Handle notification tap when app is in BACKGROUND
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('\n👆 ========== NOTIFICATION TAPPED (BACKGROUND) ==========');
      print('📱 User tapped notification while app was in background');

      if (message.data.isNotEmpty) {
        print('📦 Data: ${message.data}');
        _handleNotificationData(message.data);
      }

      print('==========================================\n');
    });

    // ✅ CRITICAL: Handle initial notification when app was TERMINATED
    _checkInitialMessage();

    print('✅ Background handlers active');
  }

  /// ✅ CRITICAL: Check if app was opened from notification (TERMINATED state)
  Future<void> _checkInitialMessage() async {
    print('🔍 Checking for initial notification (terminated state)...');

    // This gets the message that opened the app (if any)
    final initialMessage = await _messaging.getInitialMessage();

    if (initialMessage != null) {
      print('\n🎯 ========== APP OPENED FROM NOTIFICATION ==========');
      print('📱 App was terminated and opened via notification');
      print('📦 Data: ${initialMessage.data}');

      // Wait for app to be ready, then handle
      Future.delayed(const Duration(milliseconds: 1000), () {
        _handleNotificationData(initialMessage.data);
      });

      print('==========================================\n');
    } else {
      print('ℹ️ No initial notification found');
    }
  }

  /// Setup foreground notification handler
  void _setupForegroundNotificationHandler() {
    print('📱 Setting up foreground notification handler...');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('\n🔔 ========== FOREGROUND NOTIFICATION ==========');
      print('📬 Notification received while app is open');

      if (message.notification != null) {
        print('📋 Title: ${message.notification!.title}');
        print('📝 Body: ${message.notification!.body}');
      }

      if (message.data.isNotEmpty) {
        print('📦 Data: ${message.data}');
        print('ℹ️ Foreground notification - waiting for user tap');
      }

      print('==========================================\n');
    });

    print('✅ Foreground handler active');
  }

  // =================== ✅ DEEP LINK NAVIGATION ===================

  /// Handle notification data and navigate accordingly
  void _handleNotificationData(Map<String, dynamic> data) {
    print('\n🎯 ========== HANDLING NOTIFICATION DATA ==========');

    final type = data['type'] ?? '';
    final postId = data['postId'] ?? '';
    final postOwnerId = data['postOwnerId'] ?? '';
    final commentId = data['commentId'] ?? '';
    final screen = data['screen'] ?? '';
    final clickAction = data['clickAction'] ?? '';

    print('📋 Notification type: $type');
    print('📝 Post ID: $postId');
    print('👤 Post Owner ID: $postOwnerId');
    print('💬 Comment ID: $commentId');
    print('📱 Target screen: $screen');
    print('🎯 Click action: $clickAction');

    // ✅ Navigate based on type and screen
    switch (type.toLowerCase()) {
      case 'comment':
        if (postId.isNotEmpty && postOwnerId.isNotEmpty) {
          print('💬 Navigating to CommentBottomSheet...');
          _navigateToComments(postId, postOwnerId);
        } else {
          print('⚠️ Missing data for comment navigation');
          print('   postId: $postId');
          print('   postOwnerId: $postOwnerId');
        }
        break;

      case 'like':
        print('❤️ Like notification - navigate to post');
        // TODO: Navigate to post detail screen
        break;

      case 'follow':
        print('👥 Follow notification - navigate to profile');
        // TODO: Navigate to profile screen
        break;

      default:
        print('📱 Unknown notification type: $type');
        print('   Opening app home');
    }

    print('==========================================\n');
  }

  /// Navigate to CommentBottomSheet using global navigator key
  void _navigateToComments(String postId, String postOwnerId) {
    try {
      print('🚀 ========== NAVIGATING TO COMMENTS ==========');
      print('   Post ID: $postId');
      print('   Post Owner ID: $postOwnerId');

      // ✅ Use global navigator key from main.dart
      final navigator = navigatorKey.currentState;

      if (navigator == null) {
        print('❌ Navigator not available - app might not be fully initialized');
        print('   Waiting for app to be ready...');

        // ✅ Retry after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          _navigateToComments(postId, postOwnerId);
        });
        return;
      }

      print('✅ Navigator found - showing CommentBottomSheet...');

      // ✅ Show as bottom sheet
      showModalBottomSheet(
        context: navigator.context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => CommentBottomSheet(
          postId: postId,
          postOwnerId: postOwnerId,
          initialCommentCount: 0,
        ),
      );

      print('✅ Navigation successful!');
      print('==========================================\n');

    } catch (e, stackTrace) {
      print('❌ ========== NAVIGATION ERROR ==========');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      print('==========================================\n');
    }
  }

  // =================== PUBLIC METHODS ===================

  /// Get current FCM token
  Future<String?> getToken() async {
    if (_currentToken != null) {
      return _currentToken;
    }
    return await _getFCMToken();
  }

  /// Refresh FCM token manually
  Future<void> refreshToken() async {
    print('🔄 Manually refreshing FCM token...');
    await _messaging.deleteToken();
    await _getFCMToken();
  }

  /// Check if user has notification permissions
  Future<bool> hasPermissions() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  /// Update token for current user
  Future<void> updateTokenForCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _getFCMToken();
    } else {
      print('⚠️ No user logged in to update token');
    }
  }

  // =================== DEBUG METHODS ===================

  /// Print current FCM configuration
  Future<void> debugPrintConfig() async {
    print('\n🐛 ========== FCM DEBUG INFO ==========');

    final user = _auth.currentUser;
    print('👤 Current user: ${user?.uid ?? "Not logged in"}');
    print('🔑 Current token: ${_currentToken != null ? "${_currentToken!.substring(0, 30)}..." : "Not obtained"}');

    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final savedToken = userDoc.data()?['fcmToken'];
      print('💾 Firestore token: ${savedToken != null ? "${savedToken.substring(0, 30)}..." : "Not saved"}');
      print('✅ Tokens match: ${savedToken == _currentToken}');
    }

    final settings = await _messaging.getNotificationSettings();
    print('🔔 Permission status: ${settings.authorizationStatus}');
    print('📱 Alert enabled: ${settings.alert}');
    print('🔊 Sound enabled: ${settings.sound}');
    print('🔴 Badge enabled: ${settings.badge}');

    print('==========================================\n');
  }
}

// =================== BACKGROUND MESSAGE HANDLER ===================
// This must be a top-level function

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('\n🌙 ========== BACKGROUND NOTIFICATION ==========');
  print('📬 Notification received while app is closed');
  print('📋 Title: ${message.notification?.title}');
  print('📝 Body: ${message.notification?.body}');

  if (message.data.isNotEmpty) {
    print('📦 Data: ${message.data}');
  }

  print('==========================================\n');
}