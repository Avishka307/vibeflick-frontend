import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ════════════════════════════════════════════════════════════════════
// COMMENT REPORT SERVICE
// VibeFlick Comment Report System — Hybrid (Auto-Hide + Telegram)
// + Strike System (comment-level, lenient threshold)
// ════════════════════════════════════════════════════════════════════

class CommentReportService {
  static final FirebaseFirestore _db   = FirebaseFirestore.instance;
  static final FirebaseAuth      _auth = FirebaseAuth.instance;

  // ── Telegram Config (report_service.dart වලින් ගත්ත) ─────────────
  static const String _telegramBotToken =
      '8635340129:AAFpYrTjtM1osB030tm7fs8szGhjXLvBIak';
  static const String _telegramChatId = '5484667748';

  // ── Threshold Config ──────────────────────────────────────────────
  // Report 3 → everyone ට hide
  static const int _autoHideThreshold = 3;

  // User comment strike threshold: hidden comments 5 වෙලාවට 1st strike
  static const int _commentStrikeThreshold = 5;

  // ── High Risk Reasons ─────────────────────────────────────────────
  // මේ reasons 1st report දීම Telegram alert
  static const Set<String> _highRiskReasons = {
    'Hate Speech',
    'Harassment',
  };

  // ── UI Reasons → DB keys ──────────────────────────────────────────
  static String mapReason(String reason) {
    switch (reason) {
      case 'Hate Speech or Harassment':
        return 'Hate Speech';
      case 'Spam or Misleading':
        return 'Spam';
      case 'Violence or Dangerous Content':
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
  // MAIN: Submit Comment Report
  // ════════════════════════════════════════════════════════════════════
  static Future<CommentReportResult> submitCommentReport({
    required String postId,
    required String commentId,
    required String commentText,
    required String commentOwnerId,
    required String commentOwnerUsername,
    required String reason, // UI label
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return CommentReportResult.error('Not logged in');

    try {
      // ── STEP 1: Duplicate Check ───────────────────────────────────
      final existing = await _db
          .collection('comment_reports')
          .where('commentId', isEqualTo: commentId)
          .where('reportedByUserId', isEqualTo: currentUserId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        return CommentReportResult.alreadyReported();
      }

      final mappedReason = mapReason(reason);
      final timestamp    = DateTime.now().millisecondsSinceEpoch;
      final isHighRisk   = _highRiskReasons.contains(mappedReason);

      // ── STEP 2: Shadow Flag — Reporter ට hide ────────────────────
      // reporter ගේ local state (UI) handle කරන්නේ caller side
      // Firestore: comment doc එකේ reporter UID list track කරනවා
      final commentRef = _db
          .collection('media_posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId);

      await commentRef.update({
        'shadow_reported_by': FieldValue.arrayUnion([currentUserId]),
      });

      // ── STEP 3: Log to comment_reports ───────────────────────────
      await _db.collection('comment_reports').add({
        'type'                 : 'comment',
        'postId'               : postId,
        'commentId'            : commentId,
        'commentText'          : commentText,
        'commentOwnerId'       : commentOwnerId,
        'commentOwnerUsername' : commentOwnerUsername,
        'reportedByUserId'     : currentUserId,
        'reason'               : mappedReason,
        'originalReason'       : reason,
        'timestamp'            : timestamp,
        'status'               : 'pending',
        'isHighRisk'           : isHighRisk,
      });

      // ── STEP 4: Count pending reports for this comment ────────────
      final reportsSnap = await _db
          .collection('comment_reports')
          .where('commentId', isEqualTo: commentId)
          .where('status', isEqualTo: 'pending')
          .get();

      final reportCount = reportsSnap.docs.length;

      // ── STEP 5: High Risk → 1st report දීම Telegram ──────────────
      if (isHighRisk) {
        await _sendTelegramAlert(
          postId                : postId,
          commentId             : commentId,
          commentText           : commentText,
          commentOwnerUsername  : commentOwnerUsername,
          reason                : mappedReason,
          reportCount           : reportCount,
          autoHidden            : false,
        );
      }

      // ── STEP 6: Auto-Hide — 3 reports ────────────────────────────
      bool commentHidden = false;

      if (reportCount >= _autoHideThreshold) {
        await commentRef.update({
          'is_hidden'      : true,
          'hidden_reason'  : mappedReason,
          'hidden_at'      : timestamp,
          'review_status'  : 'hidden_for_review',
        });
        commentHidden = true;

        // Auto-hide Telegram alert (high risk ෙනොවෙන report 3+ වෙලාවට)
        if (!isHighRisk) {
          await _sendTelegramAlert(
            postId               : postId,
            commentId            : commentId,
            commentText          : commentText,
            commentOwnerUsername : commentOwnerUsername,
            reason               : mappedReason,
            reportCount          : reportCount,
            autoHidden           : true,
          );
        } else {
          // High risk + auto-hidden — Telegram update
          await _sendTelegramAlert(
            postId               : postId,
            commentId            : commentId,
            commentText          : commentText,
            commentOwnerUsername : commentOwnerUsername,
            reason               : mappedReason,
            reportCount          : reportCount,
            autoHidden           : true,
          );
        }

        // ── STEP 7: Comment Strike Check ──────────────────────────
        await _checkAndApplyCommentStrike(commentOwnerId);
      }

      // ── Activity Log ──────────────────────────────────────────────
      await _db.collection('activity_logs').add({
        'type'          : 'comment_report',
        'userId'        : currentUserId,
        'postId'        : postId,
        'commentId'     : commentId,
        'reason'        : mappedReason,
        'timestamp'     : timestamp,
        'commentHidden' : commentHidden,
      });

      debugPrint(
        '✅ Comment report done. Count: $reportCount | Hidden: $commentHidden',
      );
      return CommentReportResult.success();

    } catch (e) {
      debugPrint('❌ Comment report error: $e');
      return CommentReportResult.error(e.toString());
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // Telegram Alert
  // ════════════════════════════════════════════════════════════════════
  static Future<void> _sendTelegramAlert({
    required String postId,
    required String commentId,
    required String commentText,
    required String commentOwnerUsername,
    required String reason,
    required int    reportCount,
    required bool   autoHidden,
  }) async {
    try {
      final isHigh      = _highRiskReasons.contains(reason);
      final riskLabel   = isHigh ? '🔴 HIGH RISK' : '🟡 General';
      final hiddenLabel = autoHidden ? '🚫 AUTO-HIDDEN' : '👁️ Under Watch';
      final reviewLink  =
          'https://console.firebase.google.com/project/vibeflick-5fe5c/firestore';

      final message =
          '💬 VibeFlick — Comment Reported!\n\n'
          '$riskLabel  |  $hiddenLabel\n\n'
          '📌 Post ID: $postId\n'
          '🆔 Comment ID: $commentId\n'
          '👤 Commenter: @$commentOwnerUsername\n'
          '📝 Content: "${commentText.length > 200 ? commentText.substring(0, 200) + '...' : commentText}"\n'
          '⚠️ Reason: $reason\n'
          '📊 Total Reports: $reportCount\n'
          '🕐 Time: ${DateTime.now().toLocal()}\n\n'
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
        }),
      );

      debugPrint('📨 Telegram comment alert: ${response.statusCode}');
    } catch (e) {
      debugPrint('⚠️ Telegram comment alert failed (non-critical): $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // Comment Strike System
  // User ගේ hidden comments 5 වෙලා → Strike
  // Post strike system ට වඩා lenient (threshold ↑)
  // ════════════════════════════════════════════════════════════════════
  static Future<void> _checkAndApplyCommentStrike(String userId) async {
    try {
      // User ගේ hidden comment count ගන්නවා
      final hiddenSnap = await _db
          .collection('comment_reports')
          .where('commentOwnerId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();

      // Hidden unique comments count (commentId deduplicate)
      final hiddenCommentIds = hiddenSnap.docs
          .map((d) => d.data()['commentId'] as String)
          .toSet();

      // Firestore: actually hidden comments check
      // Threshold: 5 hidden unique comments → strike
      if (hiddenCommentIds.length < _commentStrikeThreshold) {
        debugPrint(
          '📊 Comment strike check: ${hiddenCommentIds.length}/${_commentStrikeThreshold} — no strike yet',
        );
        return;
      }

      // User doc check
      final userRef = _db.collection('users').doc(userId);
      final userDoc = await userRef.get();
      if (!userDoc.exists) return;

      final data           = userDoc.data()!;
      final currentStrikes = (data['commentStrikes'] ?? 0) as int;

      // commentStrikes track separately (post strikes ත් separate)
      // 1st comment strike → warning only, no posting ban
      final newStrikes = currentStrikes + 1;

      String strikeAction = '';
      final Map<String, dynamic> updateData = {
        'commentStrikes'     : newStrikes,
        'lastCommentStrikeAt': DateTime.now().millisecondsSinceEpoch,
      };

      if (newStrikes == 1) {
        strikeAction                = 'comment_warning';
        updateData['accountStatus'] = data['accountStatus'] ?? 'active';

      } else if (newStrikes == 2) {
        strikeAction                     = 'comment_restricted_3days';
        final banUntil                   = DateTime.now()
            .add(const Duration(days: 3))
            .millisecondsSinceEpoch;
        updateData['commentStatus']      = 'commenting_restricted';
        updateData['commentBannedUntil'] = banUntil;

      } else if (newStrikes >= 3) {
        strikeAction                = 'comment_banned';
        updateData['commentStatus'] = 'commenting_banned';
      }

      await userRef.update(updateData);

      await _sendCommentStrikeNotification(
        userId      : userId,
        strikeNumber: newStrikes,
        action      : strikeAction,
      );

      debugPrint(
        '⚡ Comment strike $newStrikes → $userId | Action: $strikeAction',
      );
    } catch (e) {
      debugPrint('❌ Comment strike error: $e');
    }
  }

  static Future<void> _sendCommentStrikeNotification({
    required String userId,
    required int    strikeNumber,
    required String action,
  }) async {
    String message;

    switch (action) {
      case 'comment_warning':
        message = 'ඔබේ ගිණුමේ කමෙන්ට් වලින් ප්‍රජා නීති උල්ලංඝනය '
            'වී ඇත. මෙය Warning 1 ලෙස සටහන් වී ඇත. '
            'ඉදිරියේදී නැවත සිදුවුවහොත් කමෙන්ට් හැකියාව සීමා කෙරේ.';
        break;
      case 'comment_restricted_3days':
        message = 'ඔබේ කමෙන්ට් කිරීමේ හැකියාව දින 3කට '
            'සීමා කර ඇත. ප්‍රජා නීති නැවත නැවත '
            'උල්ලංඝනය කිරීම හේතුවෙනි.';
        break;
      default:
        message = 'ඔබේ කමෙන්ට් කිරීමේ හැකියාව '
            'තාවකාලිකව අත්හිටුවා ඇත. '
            'ප්‍රජා නීති නිතර උල්ලංඝනය කිරීම හේතුවෙනි.';
    }

    await _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add({
      'type'         : 'comment_strike_warning',
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
enum CommentReportStatus { success, alreadyReported, error }

class CommentReportResult {
  final CommentReportStatus status;
  final String?             errorMessage;

  const CommentReportResult._({required this.status, this.errorMessage});

  factory CommentReportResult.success() =>
      const CommentReportResult._(status: CommentReportStatus.success);

  factory CommentReportResult.alreadyReported() =>
      const CommentReportResult._(status: CommentReportStatus.alreadyReported);

  factory CommentReportResult.error(String msg) =>
      CommentReportResult._(
        status: CommentReportStatus.error,
        errorMessage: msg,
      );

  bool get isSuccess   => status == CommentReportStatus.success;
  bool get isDuplicate => status == CommentReportStatus.alreadyReported;
  bool get isError     => status == CommentReportStatus.error;
}