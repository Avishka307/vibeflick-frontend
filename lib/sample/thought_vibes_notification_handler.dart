import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

// ════════════════════════════════════════════════════════════════════════════
//  thought_vibes_notification_handler.dart
//
//  ✅ CIRCULAR IMPORT FIX:
//     - thought_vibes_screen.dart import කරන්නේ නෑ!
//     - ThoughtVibesScreen navigate කරන්නේ named route '/thought-vibes' හරහා
//
//  ─────────────────────────────────────────────────────────────────────────
//  SETUP 1 — main.dart:
//
//    @pragma('vm:entry-point')
//    Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage msg) async {
//      await Firebase.initializeApp();
//    }
//
//    void main() async {
//      WidgetsFlutterBinding.ensureInitialized();
//      await Firebase.initializeApp();
//      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
//      await ThoughtVibesNotificationHandler.initLocalNotifications();
//      runApp(const MyApp());
//    }
//
//  ─────────────────────────────────────────────────────────────────────────
//  SETUP 2 — MaterialApp (routes ලේ '/thought-vibes' register කරන්න):
//
//    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
//
//    MaterialApp(
//      navigatorKey: navigatorKey,
//      routes: {
//        '/thought-vibes': (_) => const ThoughtVibesScreen(),
//        // ↑ ThoughtVibesScreen import කරන්නේ app.dart / main.dart ලේ — handler ලේ නෙවෙයි
//      },
//    );
//
//  ─────────────────────────────────────────────────────────────────────────
//  SETUP 3 — HomePage initState():
//
//    @override
//    void initState() {
//      super.initState();
//      ThoughtVibesNotificationHandler.init(navigatorKey);
//      final user = FirebaseAuth.instance.currentUser;
//      if (user != null) {
//        ThoughtVibesNotificationHandler.saveFcmToken(
//          userId : user.uid,
//          baseUrl: 'http://10.132.108.236:5000',
//        );
//      }
//    }
// ════════════════════════════════════════════════════════════════════════════

final FlutterLocalNotificationsPlugin _localNotifications =
FlutterLocalNotificationsPlugin();

class ThoughtVibesNotificationHandler {

  // ── Android notification channel init — main() ලේ call ──────────────────
  static Future<void> initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (details) {
        _handleLocalNotifTap(details.payload);
      },
    );

    const channel = AndroidNotificationChannel(
      'thought_vibes_channel',
      'Thought Vibes',
      description: 'Likes, comments and reposts on your thoughts',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    debugPrint('✅ ThoughtVibes local notifications initialized');
  }

  // ── Main init — HomePage initState() ─────────────────────────────────────
  static void init(GlobalKey<NavigatorState> navigatorKey) {
    _setupForegroundHandler(navigatorKey);
    _setupBackgroundTapHandler(navigatorKey);
    _checkTerminatedNotification(navigatorKey);
    _requestPermission();
    debugPrint('✅ ThoughtVibesNotificationHandler initialized');
  }

  // ── 1. FOREGROUND — in-app SnackBar toast ────────────────────────────────
  static void _setupForegroundHandler(GlobalKey<NavigatorState> navigatorKey) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final data     = message.data;
      final category = data['notifCategory'] ?? '';

      // thought_vibe notifications ONLY
      if (category != 'thought_vibe') return;

      final title = message.notification?.title ?? '';
      final body  = message.notification?.body  ?? '';
      debugPrint('📲 Foreground thought_vibe → $title');

      final ctx = navigatorKey.currentContext;
      if (ctx == null) return;

      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          content: GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
              _navigateToThoughtVibes(navigatorKey);
            },
            child: _NotifToast(title: title, body: body, data: data),
          ),
        ),
      );
    });
  }

  // ── 2. BACKGROUND tap ────────────────────────────────────────────────────
  static void _setupBackgroundTapHandler(GlobalKey<NavigatorState> navigatorKey) {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if ((message.data['notifCategory'] ?? '') == 'thought_vibe') {
        debugPrint('📲 Background tap → thought_vibe');
        _navigateToThoughtVibes(navigatorKey);
      }
    });
  }

  // ── 3. TERMINATED app — getInitialMessage ─────────────────────────────────
  static Future<void> _checkTerminatedNotification(
      GlobalKey<NavigatorState> navigatorKey) async {
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial == null) return;

    if ((initial.data['notifCategory'] ?? '') == 'thought_vibe') {
      debugPrint('📲 Terminated app tap → thought_vibe');
      Future.delayed(const Duration(milliseconds: 800), () {
        _navigateToThoughtVibes(navigatorKey);
      });
    }
  }

  // ── Navigate via NAMED ROUTE — circular import නෑ ✅ ──────────────────────
  // MaterialApp routes: { '/thought-vibes': (_) => const ThoughtVibesScreen() }
  static void _navigateToThoughtVibes(GlobalKey<NavigatorState> navigatorKey) {
    final state = navigatorKey.currentState;
    if (state == null) {
      debugPrint('⚠️ Navigator state null');
      return;
    }
    debugPrint('🧭 pushNamed /thought-vibes');
    state.pushNamed('/thought-vibes');
  }

  // ── Local notification tap handler ────────────────────────────────────────
  static void _handleLocalNotifTap(String? payload) {
    if (payload == null) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      if ((data['notifCategory'] ?? '') == 'thought_vibe') {
        debugPrint('🔔 Local notif tapped → thought_vibe');
      }
    } catch (_) {}
  }

  // ── iOS permission request ────────────────────────────────────────────────
  static Future<void> _requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true, badge: true, sound: true,
    );
    debugPrint('📋 FCM permission: ${settings.authorizationStatus}');
  }

  // ── FCM token save + refresh listener ─────────────────────────────────────
  static Future<void> saveFcmToken({
    required String userId,
    required String baseUrl,
  }) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        debugPrint('⚠️ FCM token null');
        return;
      }
      await _postToken(userId: userId, token: token, baseUrl: baseUrl);

      // Token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _postToken(userId: userId, token: newToken, baseUrl: baseUrl);
      });
    } catch (e) {
      debugPrint('❌ FCM token save error: $e');
    }
  }

  // ✅ Real http.post — dynamic import hack නෑ
  static Future<void> _postToken({
    required String userId,
    required String token,
    required String baseUrl,
  }) async {
    try {
      final response = await http
          .post(
        Uri.parse('$baseUrl/api/users/$userId/fcm-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fcmToken': token}),
      )
          .timeout(const Duration(seconds: 10));

      debugPrint(response.statusCode == 200
          ? '✅ FCM token saved'
          : '⚠️ FCM token save failed: ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ FCM token HTTP error: $e');
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  _NotifToast — Foreground in-app notification toast (glassmorphic)
// ════════════════════════════════════════════════════════════════════════════
class _NotifToast extends StatelessWidget {
  final String title;
  final String body;
  final Map<String, dynamic> data;
  const _NotifToast({
    required this.title,
    required this.body,
    required this.data,
  });

  // server.js FCMNotification.js type mapping:
  //   thought_like → 'like'  | thought_comment → 'comment' | thought_repost → 'share'
  IconData get _icon {
    switch (data['type'] ?? '') {
      case 'like'   : return Icons.favorite_rounded;
      case 'comment': return Icons.chat_bubble_rounded;
      case 'share'  : return Icons.repeat_rounded;
      default       : return Icons.auto_awesome_rounded;
    }
  }

  Color get _color {
    switch (data['type'] ?? '') {
      case 'like'   : return const Color(0xFFFF3B5C);
      case 'comment': return const Color(0xFF9B59B6);
      case 'share'  : return const Color(0xFF2ECC71);
      default       : return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e).withOpacity(0.97),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: _color.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: _color.withOpacity(0.3)),
          ),
          child: Icon(_icon, color: _color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title.isNotEmpty)
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(body,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 18),
      ]),
    );
  }
}