import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ════════════════════════════════════════════════════════════════════
// REPORT SERVICE
// VibeFlick Report System — Shadow Flagging + Threshold Actions
// + Strike System + Owner Notifications + Telegram Admin Alert
// ════════════════════════════════════════════════════════════════════

class ReportService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Telegram Config ───────────────────────────────────────────────
  // BotFather කෙනෙන් /revoke කරලා නව token එකක් ගෙන මෙතන දාන්න
  static const String _telegramBotToken = '8635340129:AAFpYrTjtM1osB030tm7fs8szGhjXLvBIak';
  static const String _telegramChatId   = '5484667748';

  // ── Threshold Config ──────────────────────────────────────────────
  static const int _shadowHideThreshold = 5;
  static const int _highRiskThreshold   = 2;

  static const Set<String> _highRiskReasons = {
    'Nudity or Sexual Content',
    'Violence or Dangerous Organizations',
  };

  // ── Reason → DB key map ───────────────────────────────────────────
  static String mapReason(String reason) {
    switch (reason) {
      case 'Spam or Misleading':
        return 'Spam';
      case 'Hate Speech or Harassment':
        return 'Hate Speech';
      case 'Violence or Dangerous Organizations':
        return 'Violence';
      case 'Nudity or Sexual Content':
        return 'Nudity';
      case 'False Information':
        return 'False Information';
      default:
        return 'Something Else';
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // MAIN: Submit Report
  // ════════════════════════════════════════════════════════════════════
  static Future<ReportResult> submitReport({
    required String postId,
    required String postOwnerId,
    required String postOwnerUsername,
    required String reason,
    String mediaUrl = '',
  }) async {
    debugPrint('🚀 submitReport START: postId=$postId');
    final currentUserId = _auth.currentUser?.uid;
    debugPrint('👤 currentUserId: $currentUserId');
    if (currentUserId == null) {
      return ReportResult.error('Not logged in');
    }


    try {
      debugPrint('📝 Starting Firestore write...');
      debugPrint('🔍 Checking duplicate...');
      // ── STEP 1: Duplicate Check
      final existing = await _db
          .collection('reports')
          .where('postId', isEqualTo: postId)
          .where('reportedByUserId', isEqualTo: currentUserId)
          .limit(1)
          .get();
      debugPrint('🔍 Duplicate check done: ${existing.docs.length} docs');
      if (existing.docs.isNotEmpty) {
        return ReportResult.alreadyReported();
      }

      // ── STEP 2: Data Logging ─────────────────────────────────────
      final mappedReason = mapReason(reason);
      final timestamp    = DateTime.now().millisecondsSinceEpoch;

      await _db.collection('reports').add({
        'type'              : 'post',
        'reportedUserId'    : postOwnerId,
        'reportedByUserId'  : currentUserId,
        'reason'            : mappedReason,
        'originalReason'    : reason,
        'timestamp'         : timestamp,
        'status'            : 'pending',
        'postId'            : postId,
        'postOwnerUsername' : postOwnerUsername,
        'mediaUrl'          : mediaUrl,
      });

      // ── STEP 3: Shadow Flag (review_pending) ─────────────────────
      await _db.collection('media_posts').doc(postId).update({
        'review_pending': true,
      });

      // ── STEP 4: Count reports for this post ──────────────────────
      final reportsSnap = await _db
          .collection('reports')
          .where('postId', isEqualTo: postId)
          .where('status', isEqualTo: 'pending')
          .get();

      final reportCount = reportsSnap.docs.length;
      final isHighRisk  = _highRiskReasons.contains(reason);

      // ── STEP 5: Telegram Admin Notification ──────────────────────
      // Firestore write ට වැටෙන ගමන්ම admin ට notify කරනවා
      await _sendTelegramNotification(
        postId            : postId,
        postOwnerId       : postOwnerId,
        postOwnerUsername : postOwnerUsername,
        reason            : mappedReason,
        originalReason    : reason,
        reportCount       : reportCount,
        isHighRisk        : isHighRisk,
        mediaUrl          : mediaUrl,
      );

      // ── STEP 6: Threshold Actions ─────────────────────────────────
      bool postHidden = false;

      if (isHighRisk && reportCount >= _highRiskThreshold) {
        await _hidePost(postId, reason: mappedReason);
        await _sendOwnerNotification(
          postOwnerId : postOwnerId,
          postId      : postId,
          reason      : mappedReason,
          isHighRisk  : true,
        );
        await _checkAndApplyStrike(postOwnerId);
        postHidden = true;

      } else if (!isHighRisk && reportCount >= _shadowHideThreshold) {
        await _hidePost(postId, reason: mappedReason);
        await _sendOwnerNotification(
          postOwnerId : postOwnerId,
          postId      : postId,
          reason      : mappedReason,
          isHighRisk  : false,
        );
        await _checkAndApplyStrike(postOwnerId);
        postHidden = true;
      }

      // Activity log
      await _db.collection('activity_logs').add({
        'type'      : 'report',
        'userId'    : currentUserId,
        'postId'    : postId,
        'reason'    : mappedReason,
        'timestamp' : timestamp,
        'postHidden': postHidden,
      });

      debugPrint('✅ Report submitted. Count: $reportCount | Hidden: $postHidden');
      return ReportResult.success();

    } catch (e) {
      debugPrint('❌ Report error: $e');
      return ReportResult.error(e.toString());
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // Telegram Admin Notification
  // ════════════════════════════════════════════════════════════════════
  static Future<void> _sendTelegramNotification({
    required String postId,
    required String postOwnerId,
    required String postOwnerUsername,
    required String reason,
    required String originalReason,
    required int    reportCount,
    required bool   isHighRisk,
    required String mediaUrl,
  }) async {
    try {
      final riskLabel  = isHighRisk ? '🔴 HIGH RISK' : '🟡 General';
      final postLink   = 'https://vibeflick-5fe5c.web.app/post/$postId';
      final reviewLink = 'https://console.firebase.google.com/project/vibeflick-5fe5c/firestore';

      final message =
          '🚨 VibeFlick — New Report Received\n\n'
          '$riskLabel\n'
          '📋 Reason: $originalReason\n'
          '👤 Post Owner: @$postOwnerUsername\n'
          '🆔 Post ID: $postId\n'
          '📊 Total Reports: $reportCount\n'
          '🕐 Time: ${DateTime.now().toLocal()}\n\n'
          '🔗 Post: $postLink\n'
          '🛡️ Firebase: $reviewLink';

      final url = Uri.parse(
        'https://api.telegram.org/bot$_telegramBotToken/sendMessage',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': _telegramChatId,
          'text'   : message,
          // parse_mode නෑ — plain text
        }),
      );

      debugPrint('📨 Telegram status: ${response.statusCode}');
      debugPrint('📨 Telegram body: ${response.body}');

      // ── Media preview ─────────────────────────────────────────────
      if (mediaUrl.isNotEmpty) {
        final isVideo = mediaUrl.contains('.mp4') ||
            mediaUrl.contains('video') ||
            mediaUrl.contains('media_posts');

        final mediaEndpoint = isVideo ? 'sendVideo' : 'sendPhoto';
        final mediaKey      = isVideo ? 'video'     : 'photo';

        final mediaResponse = await http.post(
          Uri.parse('https://api.telegram.org/bot$_telegramBotToken/$mediaEndpoint'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'chat_id' : _telegramChatId,
            mediaKey  : mediaUrl,
            'caption' : '🎬 Reported Post — @$postOwnerUsername | $reason',
          }),
        );

        debugPrint('📷 Telegram media status: ${mediaResponse.statusCode}');
        debugPrint('📷 Telegram media body: ${mediaResponse.body}');
      }

    } catch (e) {
      debugPrint('⚠️ Telegram notification failed (non-critical): $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // Hide Post (Hidden for Review)
  // ════════════════════════════════════════════════════════════════════
  static Future<void> _hidePost(String postId, {required String reason}) async {
    await _db.collection('media_posts').doc(postId).update({
      'is_hidden'     : true,
      'hidden_reason' : reason,
      'hidden_at'     : DateTime.now().millisecondsSinceEpoch,
      'review_status' : 'hidden_for_review',
    });
    debugPrint('🚫 Post hidden: $postId | Reason: $reason');
  }

  // ════════════════════════════════════════════════════════════════════
  // Send Notification to Post Owner
  // Reporter's identity කවදාවත් හෙළි නොකරයි
  // ════════════════════════════════════════════════════════════════════
  static Future<void> _sendOwnerNotification({
    required String postOwnerId,
    required String postId,
    required String reason,
    required bool   isHighRisk,
  }) async {
    final message = _buildOwnerMessage(reason, isHighRisk);

    await _db
        .collection('users')
        .doc(postOwnerId)
        .collection('notifications')
        .add({
      'type'         : 'post_reported',
      'postId'       : postId,
      'message'      : message,
      'reason'       : reason,
      'isRead'       : false,
      'timestamp'    : DateTime.now().millisecondsSinceEpoch,
      'fromUserId'   : 'system',
      'fromUserName' : 'VibeFlick',
      'toUserId'     : postOwnerId,
    });

    debugPrint('📩 Owner notified: $postOwnerId');
  }

  static String _buildOwnerMessage(String reason, bool isHighRisk) {
    if (isHighRisk) {
      return 'ඔබගේ පළ කිරීමක් අපගේ ප්‍රජා මාර්ගෝපදේශ (Community Guidelines) '
          'උල්ලංඝනය කර ඇති බවට වාර්තා වී ඇත. එම නිසා එම පෝස්ට් එක '
          'තාවකාලිකව ඉවත් කර ඇත. ඔබට මෙයට විරුද්ධ වීමට (Appeal) '
          'අවශ්‍ය නම් අපට දන්වන්න.';
    }

    switch (reason) {
      case 'Spam':
        return 'ඔබේ පෝස්ට් එක ස්පෑම් ලෙස වාර්තා වී ඇත. '
            'කරුණාකර ප්‍රජා නීති අනුගමනය කරන්න.';
      case 'Hate Speech':
        return 'හිරිහැර කිරීම් හේතුවෙන් ඔබේ පෝස්ට් එක සමාලෝචනය '
            'සඳහා ඉවත් කර ඇත. නැවත මෙවැනි දේ සිදුවුවහොත් '
            'ඔබේ ගිණුම තාවකාලිකව අත්හිටුවනු ලැබේ.';
      case 'False Information':
        return 'ඔබගේ පෝස්ට් එකේ අඩංගු කරුණු තහවුරු නොකළ '
            'තොරතුරු ලෙස ලකුණු කර ඇත.';
      default:
        return 'ඔබගේ පළ කිරීමක් අපගේ ප්‍රජා මාර්ගෝපදේශ '
            'උල්ලංඝනය කර ඇති බවට වාර්තා වී ඇත. '
            'ඔබට Appeal කිරීමට අවශ්‍ය නම් අපට දන්වන්න.';
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // Strike System
  // ════════════════════════════════════════════════════════════════════
  static Future<void> _checkAndApplyStrike(String userId) async {
    try {
      final userRef = _db.collection('users').doc(userId);
      final userDoc = await userRef.get();

      if (!userDoc.exists) return;

      final data          = userDoc.data()!;
      final currentStrikes = (data['strikes'] ?? 0) as int;
      final newStrikes    = currentStrikes + 1;

      String strikeAction = '';
      Map<String, dynamic> updateData = {
        'strikes'     : newStrikes,
        'lastStrikeAt': DateTime.now().millisecondsSinceEpoch,
      };

      if (newStrikes == 1) {
        strikeAction             = 'warning';
        updateData['accountStatus'] = 'active';

      } else if (newStrikes == 2) {
        strikeAction              = 'posting_banned_3days';
        final banUntil            = DateTime.now()
            .add(const Duration(days: 3))
            .millisecondsSinceEpoch;
        updateData['accountStatus']      = 'posting_restricted';
        updateData['postingBannedUntil'] = banUntil;

      } else if (newStrikes >= 3) {
        strikeAction              = 'permanently_banned';
        updateData['accountStatus'] = 'banned';
        updateData['bannedAt']      = DateTime.now().millisecondsSinceEpoch;
      }

      await userRef.update(updateData);

      await _sendStrikeNotification(
        userId      : userId,
        strikeNumber: newStrikes,
        action      : strikeAction,
      );

      debugPrint('⚡ Strike $newStrikes applied to: $userId | Action: $strikeAction');

    } catch (e) {
      debugPrint('❌ Strike error: $e');
    }
  }

  static Future<void> _sendStrikeNotification({
    required String userId,
    required int    strikeNumber,
    required String action,
  }) async {
    String message;

    switch (action) {
      case 'warning':
        message = 'ඔබේ ගිණුමට Strike 1 ලැබී ඇත. '
            'ප්‍රජා මාර්ගෝපදේශ උල්ලංඝනය කිරීම නිදහසේ '
            'ඉදිරියට කරගෙන යාමට ඉඩ නොදේ.';
        break;
      case 'posting_banned_3days':
        message = 'ඔබේ ගිණුමට Strike 2 ලැබී ඇත. '
            'ඔබේ පෝස්ට් කිරීමේ හැකියාව දින 3කට '
            'අත්හිටුවා ඇත.';
        break;
      default:
        message = 'ඔබේ ගිණුම ස්ථිරවම අත්හිටුවා ඇත. '
            'ප්‍රජා මාර්ගෝපදේශ නැවත නැවත '
            'උල්ලංඝනය කිරීම නිසා මෙම තීරණය ගන්නා ලදී.';
    }

    await _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add({
      'type'         : 'strike_warning',
      'strikeNumber' : strikeNumber,
      'message'      : message,
      'isRead'       : false,
      'timestamp'    : DateTime.now().millisecondsSinceEpoch,
      'fromUserId'   : 'system',
      'fromUserName' : 'VibeFlick',
      'toUserId'     : userId,
    });
  }
}

// ════════════════════════════════════════════════════════════════════
// Result Model
// ════════════════════════════════════════════════════════════════════
enum ReportStatus { success, alreadyReported, error }

class ReportResult {
  final ReportStatus status;
  final String?      errorMessage;

  const ReportResult._({required this.status, this.errorMessage});

  factory ReportResult.success() =>
      const ReportResult._(status: ReportStatus.success);

  factory ReportResult.alreadyReported() =>
      const ReportResult._(status: ReportStatus.alreadyReported);

  factory ReportResult.error(String msg) =>
      ReportResult._(status: ReportStatus.error, errorMessage: msg);

  bool get isSuccess  => status == ReportStatus.success;
  bool get isDuplicate => status == ReportStatus.alreadyReported;
  bool get isError    => status == ReportStatus.error;
}