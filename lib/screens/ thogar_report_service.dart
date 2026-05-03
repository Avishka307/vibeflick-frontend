import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ════════════════════════════════════════════════════════════════════
// THOGAR REPORT SERVICE
// Together Feed Report System — Firestore Direct (No Backend)
// Anonymous post threshold: 2 reports → auto-hide
// Public post threshold   : 5 reports → auto-hide
// Reporter sees instant local hide (like "Not Interested")
// Telegram admin alert on every report
// Strike applied to real uid even if post is anonymous
// ════════════════════════════════════════════════════════════════════

class ThogarReportService {
  static final FirebaseFirestore _db  = FirebaseFirestore.instance;
  static final FirebaseAuth      _auth = FirebaseAuth.instance;

  // ── Telegram Config (same bot as VibeFlick) ───────────────────────
  static const String _telegramBotToken =
      '8635340129:AAFpYrTjtM1osB030tm7fs8szGhjXLvBIak';
  static const String _telegramChatId = '5484667748';

  // ── Thresholds ────────────────────────────────────────────────────
  static const int _anonHideThreshold   = 2; // Anonymous posts
  static const int _publicHideThreshold = 5; // Public posts

  // ════════════════════════════════════════════════════════════════════
  // MAIN: Submit Report
  // ════════════════════════════════════════════════════════════════════
  static Future<ThogarReportResult> submitReport({
    required String postId,
    required String postOwnerId,       // real uid (always stored even if anon)
    required String postOwnerUsername, // 'Anonymous' if anon
    required String reason,
    required bool   isAnonymous,
    required String location,          // e.g. "Colombo, Sri Lanka" or "Global"
    String content = '',
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return ThogarReportResult.error('Not logged in');
    }

    try {
      // ── STEP 1: Duplicate check ───────────────────────────────────
      final existing = await _db
          .collection('thogar_reports')
          .where('postId',            isEqualTo: postId)
          .where('reportedByUserId',  isEqualTo: currentUserId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        return ThogarReportResult.alreadyReported();
      }

      final ts = DateTime.now().millisecondsSinceEpoch;

      // ── STEP 2: Write report doc ──────────────────────────────────
      await _db.collection('thogar_reports').add({
        'postId'            : postId,
        'postOwnerId'       : postOwnerId,
        'postOwnerUsername' : postOwnerUsername,
        'reportedByUserId'  : currentUserId,
        'reason'            : reason,
        'isAnonymous'       : isAnonymous,
        'location'          : location,
        'contentPreview'    : content.length > 120
            ? '${content.substring(0, 120)}…'
            : content,
        'timestamp'         : ts,
        'status'            : 'pending',
        'feedType'          : 'together',
      });

      // ── STEP 3: Shadow flag on text_posts doc ─────────────────────
      await _db.collection('text_posts').doc(postId).update({
        'thogar_review_pending': true,
      });

      // ── STEP 4: Count reports for this post ───────────────────────
      final reportsSnap = await _db
          .collection('thogar_reports')
          .where('postId', isEqualTo: postId)
          .where('status', isEqualTo: 'pending')
          .get();

      final reportCount = reportsSnap.docs.length;
      final threshold   = isAnonymous
          ? _anonHideThreshold
          : _publicHideThreshold;
      final shouldHide  = reportCount >= threshold;

      // ── STEP 5: Telegram alert ────────────────────────────────────
      await _sendTelegramAlert(
        postId            : postId,
        postOwnerId       : postOwnerId,
        postOwnerUsername : postOwnerUsername,
        reason            : reason,
        isAnonymous       : isAnonymous,
        location          : location,
        content           : content,
        reportCount       : reportCount,
        threshold         : threshold,
        autoHidden        : shouldHide,
      );

      // ── STEP 6: Auto-hide if threshold reached ────────────────────
      if (shouldHide) {
        await _db.collection('text_posts').doc(postId).update({
          'thogar_is_hidden'     : true,
          'thogar_hidden_reason' : reason,
          'thogar_hidden_at'     : ts,
          'thogar_review_status' : 'hidden_for_review',
          'thogar_review_pending': true,
        });

        // Notify post owner (real uid, even for anon)
        await _notifyOwner(
          postOwnerId : postOwnerId,
          postId      : postId,
          reason      : reason,
          isAnonymous : isAnonymous,
        );

        // Apply strike to real uid
        await _applyStrike(postOwnerId);
      }

      // ── STEP 7: Activity log ──────────────────────────────────────
      await _db.collection('activity_logs').add({
        'type'       : 'thogar_report',
        'userId'     : currentUserId,
        'postId'     : postId,
        'reason'     : reason,
        'isAnonymous': isAnonymous,
        'location'   : location,
        'timestamp'  : ts,
        'autoHidden' : shouldHide,
      });

      debugPrint(
          '✅ Thogar report done | count=$reportCount | hidden=$shouldHide');
      return ThogarReportResult.success(autoHidden: shouldHide);

    } catch (e) {
      debugPrint('❌ ThogarReportService error: $e');
      return ThogarReportResult.error(e.toString());
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // Telegram Admin Alert
  // ════════════════════════════════════════════════════════════════════
  static Future<void> _sendTelegramAlert({
    required String postId,
    required String postOwnerId,
    required String postOwnerUsername,
    required String reason,
    required bool   isAnonymous,
    required String location,
    required String content,
    required int    reportCount,
    required int    threshold,
    required bool   autoHidden,
  }) async {
    try {
      final postType  = isAnonymous ? 'Anonymous' : 'Public';
      final statusLine = autoHidden
          ? '⚠️ Reports: $reportCount/$threshold (Auto-Hidden)'
          : '📊 Reports: $reportCount/$threshold';
      final action = autoHidden
          ? '🚨 Action: වහාම පරීක්ෂා කර Strike එකක් දෙන්න.'
          : '👁️ Action: Monitor — threshold not reached yet.';

      final preview = content.length > 150
          ? '${content.substring(0, 150)}…'
          : content;

      final message =
          '🌍 Together Feed Report!\n\n'
          '📌 Type: $postType\n'
          '📍 Location: $location\n'
          '📝 Content: $preview\n'
          '🚩 Reason: $reason\n'
          '👤 Post Owner: @$postOwnerUsername\n'
          '🆔 Post ID: $postId\n'
          '$statusLine\n'
          '$action';

      await http.post(
        Uri.parse(
            'https://api.telegram.org/bot$_telegramBotToken/sendMessage'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': _telegramChatId,
          'text'   : message,
        }),
      );

      debugPrint('📨 Telegram alert sent');
    } catch (e) {
      // Non-critical — don't fail the whole report
      debugPrint('⚠️ Telegram alert failed (non-critical): $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // Notify Post Owner
  // ════════════════════════════════════════════════════════════════════
  static Future<void> _notifyOwner({
    required String postOwnerId,
    required String postId,
    required String reason,
    required bool   isAnonymous,
  }) async {
    const message =
        'ඔබගේ Together Feed පෝස්ට් එකක් ප්‍රජා මාර්ගෝපදේශ '
        'උල්ලංඝනය කර ඇති බවට වාර්තා වී ඇත. '
        'එම නිසා එම පෝස්ට් එක තාවකාලිකව ඉවත් කර ඇත. '
        'Anonymous ලෙස පළ කළත් ඔබේ ගිණුමට Strike ලැබේ.';

    await _db
        .collection('users')
        .doc(postOwnerId)
        .collection('notifications')
        .add({
      'type'         : 'thogar_post_reported',
      'postId'       : postId,
      'message'      : message,
      'reason'       : reason,
      'isAnonymous'  : isAnonymous,
      'isRead'       : false,
      'timestamp'    : DateTime.now().millisecondsSinceEpoch,
      'fromUserId'   : 'system',
      'fromUserName' : 'Together',
      'toUserId'     : postOwnerId,
    });
  }

  // ════════════════════════════════════════════════════════════════════
  // Strike System (mirrors VibeFlick ReportService logic)
  // ════════════════════════════════════════════════════════════════════
  static Future<void> _applyStrike(String userId) async {
    try {
      final userRef = _db.collection('users').doc(userId);
      final userDoc = await userRef.get();
      if (!userDoc.exists) return;

      final data           = userDoc.data()!;
      final currentStrikes = (data['strikes'] as num?)?.toInt() ?? 0;
      final newStrikes     = currentStrikes + 1;

      String action = '';
      final Map<String, dynamic> updateData = {
        'strikes'     : newStrikes,
        'lastStrikeAt': DateTime.now().millisecondsSinceEpoch,
      };

      if (newStrikes == 1) {
        action                     = 'warning';
        updateData['accountStatus'] = 'active';
      } else if (newStrikes == 2) {
        action                          = 'posting_banned_3days';
        final banUntil                  = DateTime.now()
            .add(const Duration(days: 3))
            .millisecondsSinceEpoch;
        updateData['accountStatus']      = 'posting_restricted';
        updateData['postingBannedUntil'] = banUntil;
      } else {
        action                     = 'permanently_banned';
        updateData['accountStatus'] = 'banned';
        updateData['bannedAt']      = DateTime.now().millisecondsSinceEpoch;
      }

      await userRef.update(updateData);
      await _sendStrikeNotification(
          userId: userId, strikeNumber: newStrikes, action: action);

      debugPrint('⚡ Thogar strike $newStrikes → $userId | $action');
    } catch (e) {
      debugPrint('❌ Thogar strike error: $e');
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
        message = 'ඔබේ Together Feed ගිණුමට Strike 1 ලැබී ඇත. '
            'Anonymous ලෙස පළ කළත් ප්‍රජා නීති උල්ලංඝනය කිරීමට ඉඩ නොදේ.';
        break;
      case 'posting_banned_3days':
        message = 'ඔබේ ගිණුමට Strike 2 ලැබී ඇත. '
            'පෝස්ට් කිරීමේ හැකියාව දින 3කට අත්හිටුවා ඇත.';
        break;
      default:
        message = 'ඔබේ Together Feed ගිණුම ස්ථිරවම අත්හිටුවා ඇත. '
            'නැවත නැවත ප්‍රජා නීති උල්ලංඝනය කිරීම නිසා.';
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
      'fromUserName' : 'Together',
      'toUserId'     : userId,
    });
  }
}

// ════════════════════════════════════════════════════════════════════
// Result Model
// ════════════════════════════════════════════════════════════════════
enum ThogarReportStatus { success, alreadyReported, error }

class ThogarReportResult {
  final ThogarReportStatus status;
  final bool               autoHidden;
  final String?            errorMessage;

  const ThogarReportResult._({
    required this.status,
    this.autoHidden  = false,
    this.errorMessage,
  });

  factory ThogarReportResult.success({bool autoHidden = false}) =>
      ThogarReportResult._(
          status: ThogarReportStatus.success, autoHidden: autoHidden);

  factory ThogarReportResult.alreadyReported() =>
      const ThogarReportResult._(status: ThogarReportStatus.alreadyReported);

  factory ThogarReportResult.error(String msg) =>
      ThogarReportResult._(
          status: ThogarReportStatus.error, errorMessage: msg);

  bool get isSuccess      => status == ThogarReportStatus.success;
  bool get isDuplicate    => status == ThogarReportStatus.alreadyReported;
  bool get isError        => status == ThogarReportStatus.error;
}