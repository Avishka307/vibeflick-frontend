import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ════════════════════════════════════════════════════════════════════
// MESSAGE REPORT SERVICE
// VibeFlick — Messages Screen User/Message Report
// Bot token + chatId → report_service.dart ගොනුවෙ සමාන values
// ════════════════════════════════════════════════════════════════════

class MessageReportService {
  static final FirebaseFirestore _db    = FirebaseFirestore.instance;
  static final FirebaseAuth      _auth  = FirebaseAuth.instance;

  // ── Telegram Config (report_service.dart සමාන) ─────────────────
  static const String _telegramBotToken = '8635340129:AAFpYrTjtM1osB030tm7fs8szGhjXLvBIak';
  static const String _telegramChatId   = '5484667748';

  // ── Report Reasons ────────────────────────────────────────────────
  static const List<String> reportReasons = [
    'Spam or Unwanted Messages',
    'Harassment or Bullying',
    'Threats or Violence',
    'Inappropriate Content',
    'Scam or Fraud',
    'Hate Speech',
    'Something Else',
  ];

  static const Set<String> _highRiskReasons = {
    'Threats or Violence',
    'Inappropriate Content',
  };

  // ════════════════════════════════════════════════════════════════════
  // MAIN: Submit Message/User Report
  // ════════════════════════════════════════════════════════════════════
  static Future<MessageReportResult> submitMessageReport({
    required String reportedUserId,
    required String reportedUsername,
    required String reason,
    String messagePreview = '',
    String chatRoomId    = '',
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return MessageReportResult.error('Not logged in');

    try {
      // ── STEP 1: Duplicate Check ───────────────────────────────────
      final existing = await _db
          .collection('message_reports')
          .where('reportedUserId',   isEqualTo: reportedUserId)
          .where('reportedByUserId', isEqualTo: currentUserId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        return MessageReportResult.alreadyReported();
      }

      final isHighRisk = _highRiskReasons.contains(reason);
      final timestamp  = DateTime.now().millisecondsSinceEpoch;

      // ── STEP 2: Firestore Save ────────────────────────────────────
      await _db.collection('message_reports').add({
        'type'             : 'message',
        'reportedUserId'   : reportedUserId,
        'reportedUsername' : reportedUsername,
        'reportedByUserId' : currentUserId,
        'reason'           : reason,
        'messagePreview'   : messagePreview.length > 150
            ? messagePreview.substring(0, 150)
            : messagePreview,
        'chatRoomId'       : chatRoomId,
        'timestamp'        : timestamp,
        'status'           : 'pending',
        'isHighRisk'       : isHighRisk,
      });

      // ── STEP 3: Telegram Admin Notification ──────────────────────
      await _sendTelegramNotification(
        reportedUserId    : reportedUserId,
        reportedUsername  : reportedUsername,
        reason            : reason,
        messagePreview    : messagePreview,
        isHighRisk        : isHighRisk,
      );

      // ── STEP 4: Activity Log ──────────────────────────────────────
      await _db.collection('activity_logs').add({
        'type'            : 'message_report',
        'userId'          : currentUserId,
        'reportedUserId'  : reportedUserId,
        'reason'          : reason,
        'timestamp'       : timestamp,
        'isHighRisk'      : isHighRisk,
      });

      debugPrint('✅ Message report submitted → @$reportedUsername | $reason');
      return MessageReportResult.success();

    } catch (e) {
      debugPrint('❌ Message report error: $e');
      return MessageReportResult.error(e.toString());
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // Telegram Notification
  // ════════════════════════════════════════════════════════════════════
  static Future<void> _sendTelegramNotification({
    required String reportedUserId,
    required String reportedUsername,
    required String reason,
    required String messagePreview,
    required bool   isHighRisk,
  }) async {
    try {
      final riskLabel  = isHighRisk ? '🔴 HIGH RISK' : '🟡 General';
      final reviewLink = 'https://console.firebase.google.com/project/vibeflick-5fe5c/firestore';
      final preview    = messagePreview.isNotEmpty
          ? (messagePreview.length > 120
          ? messagePreview.substring(0, 120) + '...'
          : messagePreview)
          : 'N/A';

      final message =
          '🚨 VibeFlick — Message/User Report\n\n'
          '$riskLabel\n'
          '💬 Type: Message Report\n'
          '📋 Reason: $reason\n'
          '👤 Reported User: @$reportedUsername\n'
          '🆔 User ID: $reportedUserId\n'
          '📝 Message Preview: $preview\n'
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

      debugPrint('📨 Telegram (msg report) status: ${response.statusCode}');
    } catch (e) {
      debugPrint('⚠️ Telegram message report notification failed: $e');
    }
  }
}

// ════════════════════════════════════════════════════════════════════
// Result Model
// ════════════════════════════════════════════════════════════════════
enum MessageReportStatus { success, alreadyReported, error }

class MessageReportResult {
  final MessageReportStatus status;
  final String?             errorMessage;

  const MessageReportResult._({required this.status, this.errorMessage});

  factory MessageReportResult.success() =>
      const MessageReportResult._(status: MessageReportStatus.success);

  factory MessageReportResult.alreadyReported() =>
      const MessageReportResult._(status: MessageReportStatus.alreadyReported);

  factory MessageReportResult.error(String msg) =>
      MessageReportResult._(status: MessageReportStatus.error, errorMessage: msg);

  bool get isSuccess   => status == MessageReportStatus.success;
  bool get isDuplicate => status == MessageReportStatus.alreadyReported;
  bool get isError     => status == MessageReportStatus.error;
}