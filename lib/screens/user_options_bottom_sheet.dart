import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────
const _kBaseUrl          = 'https://avishka-tiktok-api.zeabur.app';
const _kTelegramBotToken = '8635340129:AAFpYrTjtM1osB030tm7fs8szGhjXLvBIak';
const _kTelegramChatId   = '5484667748';

// ─────────────────────────────────────────────────────────────────
// MAIN WIDGET
// ─────────────────────────────────────────────────────────────────
class UserMoreOptionsSheet extends StatefulWidget {
  final String currentUserId;
  final String targetUserId;
  final String targetUsername;
  final String targetName;
  final String targetAvatarUrl;

  const UserMoreOptionsSheet({
    Key? key,
    required this.currentUserId,
    required this.targetUserId,
    required this.targetUsername,
    required this.targetName,
    required this.targetAvatarUrl,
  }) : super(key: key);

  @override
  State<UserMoreOptionsSheet> createState() => _UserMoreOptionsSheetState();
}

class _UserMoreOptionsSheetState extends State<UserMoreOptionsSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  bool _isLoadingBlock = false;
  bool _isBlocked      = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync   : this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim  = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end  : Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _animController.forward();
    _checkBlockStatus();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────
  // FIX 1: BLOCK STATUS — Firestore direct (backend fallback)
  // ──────────────────────────────────────────────────────────────

  Future<void> _checkBlockStatus() async {
    try {
      // Primary: Firestore direct check (blocked_users collection)
      final db  = FirebaseFirestore.instance;
      final doc = await db
          .collection('blocked_users')
          .where('blockerId', isEqualTo: widget.currentUserId)
          .where('blockedId', isEqualTo: widget.targetUserId)
          .limit(1)
          .get();

      if (mounted) setState(() => _isBlocked = doc.docs.isNotEmpty);
    } catch (_) {
      // Fallback: backend API
      try {
        final res = await http.get(
          Uri.parse(
            '$_kBaseUrl/api/users/block-status/${widget.currentUserId}/${widget.targetUserId}',
          ),
        ).timeout(const Duration(seconds: 6));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (mounted) setState(() => _isBlocked = data['isBlocked'] ?? false);
        }
      } catch (_) {}
    }
  }

  // ──────────────────────────────────────────────────────────────
  // FIX 1: BLOCK — Firestore direct write
  // ──────────────────────────────────────────────────────────────

  Future<bool> _blockUser() async {
    if (mounted) setState(() => _isLoadingBlock = true);
    try {
      final db    = FirebaseFirestore.instance;
      final docId = '${widget.currentUserId}_${widget.targetUserId}';

      await db.collection('blocked_users').doc(docId).set({
        'blockerId'      : widget.currentUserId,
        'blockedId'      : widget.targetUserId,
        'blockedUsername': widget.targetUsername,
        'timestamp'      : DateTime.now().millisecondsSinceEpoch,
      });

      // Fire-and-forget backend sync
      http.post(
        Uri.parse('$_kBaseUrl/api/users/block'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'blockerId'      : widget.currentUserId,
          'blockedId'      : widget.targetUserId,
          'blockedUsername': widget.targetUsername,
        }),
      ).timeout(const Duration(seconds: 8)).catchError((_) {});

      return true;
    } catch (e) {
      debugPrint('Block error: $e');
      return false;
    } finally {
      if (mounted) setState(() => _isLoadingBlock = false);
    }
  }

  Future<bool> _unblockUser() async {
    if (mounted) setState(() => _isLoadingBlock = true);
    try {
      final db    = FirebaseFirestore.instance;
      final docId = '${widget.currentUserId}_${widget.targetUserId}';

      await db.collection('blocked_users').doc(docId).delete();

      // Fire-and-forget backend sync
      http.post(
        Uri.parse('$_kBaseUrl/api/users/unblock'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'blockerId': widget.currentUserId,
          'blockedId': widget.targetUserId,
        }),
      ).timeout(const Duration(seconds: 8)).catchError((_) {});

      return true;
    } catch (e) {
      debugPrint('Unblock error: $e');
      return false;
    } finally {
      if (mounted) setState(() => _isLoadingBlock = false);
    }
  }

  // ──────────────────────────────────────────────────────────────
  // FIX 2: ABOUT ACCOUNT — Direct Firestore (no backend needed)
  // ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _fetchAboutAccount() async {
    try {
      final db  = FirebaseFirestore.instance;
      final doc = await db.collection('users').doc(widget.targetUserId).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      debugPrint('🔥 USER DOC FIELDS: ${data.keys.toList()}');
      debugPrint('🔥 RAW DATES: createdAt=${data['createdAt']} | joinDate=${data['joinDate']} | created_at=${data['created_at']} | registeredAt=${data['registeredAt']}');
      // Post count from media_posts
      final postsSnap = await db
          .collection('media_posts')
          .where('uid', isEqualTo: widget.targetUserId)
          .where('is_active', isEqualTo: true)
          .count()
          .get();

      final postCount     = postsSnap.count ?? 0;
      final followerCount = data['followerCount'] ?? 0;
      final isVerified    = data['isVerified'] ?? data['verified'] ?? false;

      // joinDate — handle Timestamp or int (ms or s)
      dynamic joinDate;
      final raw = data['joined_at'] ?? data['createdAt'] ?? data['joinDate'] ?? data['created_at'];
      if (raw is Timestamp) {
        joinDate = raw.millisecondsSinceEpoch ~/ 1000;
      } else if (raw is int) {
        joinDate = raw > 9999999999 ? raw ~/ 1000 : raw;
      } else if (raw is String) {
        // ISO string fallback e.g. "2023-10-15T08:00:00Z"
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) joinDate = parsed.millisecondsSinceEpoch ~/ 1000;
      }

      // Country / location
      final country = (data['country'] ?? data['location'] ?? '').toString().trim();

      // Former usernames — stored as List<String> under 'formerUsernames' or 'previousUsernames'
      List<String> formerUsernames = [];
      final rawNames = data['formerUsernames'] ?? data['previousUsernames'];
      if (rawNames is List) {
        formerUsernames = rawNames
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      return {
        'joinDate'        : joinDate,
        'postCount'       : postCount,
        'followerCount'   : followerCount,
        'isVerified'      : isVerified,
        'country'         : country,
        'formerUsernames' : formerUsernames,
      };
    } catch (e) {
      debugPrint('fetchAboutAccount error: $e');
      return null;
    }
  }
  // ──────────────────────────────────────────────────────────────
  // PROFILE REPORT — Direct Firestore + Telegram
  // ──────────────────────────────────────────────────────────────

  Future<bool> _submitProfileReport(String reason) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not logged in');

    final db = FirebaseFirestore.instance;

    final existing = await db
        .collection('reports')
        .where('type',             isEqualTo: 'profile')
        .where('targetUserId',     isEqualTo: widget.targetUserId)
        .where('reportedByUserId', isEqualTo: uid)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) return false;

    final ts = DateTime.now().millisecondsSinceEpoch;

    await db.collection('reports').add({
      'type'            : 'profile',
      'targetUserId'    : widget.targetUserId,
      'targetUsername'  : widget.targetUsername,
      'targetName'      : widget.targetName,
      'reportedByUserId': uid,
      'reason'          : reason,
      'timestamp'       : ts,
      'status'          : 'pending',
      'reviewRequired'  : true,
    });

    _fireTelegramAlert(reason: reason, timestamp: ts);
    return true;
  }

  void _fireTelegramAlert({required String reason, required int timestamp}) {
    final dt       = DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal();
    final viewLink = 'https://vibeflick-5fe5c.web.app/user/${widget.targetUserId}';
    final fbLink   = 'https://console.firebase.google.com/project/vibeflick-5fe5c/firestore';

    final msg =
        '🚨 VibeFlick — Profile Report\n\n'
        '👤 Reported : @${widget.targetUsername}\n'
        '🆔 User ID  : ${widget.targetUserId}\n'
        '📋 Reason   : $reason\n'
        '🕐 Time     : $dt\n\n'
        '⚠️ Manual review required — NOT auto-hidden.\n\n'
        '🔗 Profile  : $viewLink\n'
        '🛡️ Firebase : $fbLink';

    http
        .post(
      Uri.parse(
          'https://api.telegram.org/bot$_kTelegramBotToken/sendMessage'),
      headers: {'Content-Type': 'application/json'},
      body   : jsonEncode({'chat_id': _kTelegramChatId, 'text': msg}),
    )
        .then((r) => debugPrint('📨 Telegram: ${r.statusCode}'))
        .catchError((e) => debugPrint('⚠️ Telegram failed: $e'));
  }

  // ──────────────────────────────────────────────────────────────
  // SHARE
  // ──────────────────────────────────────────────────────────────

  Future<void> _handleShareProfile() async {
    HapticFeedback.lightImpact();
    Navigator.pop(context);
    final text =
        'Check out @${widget.targetUsername} on VibeFlick!\n'
        'https://vibeflick-5fe5c.web.app/user/${widget.targetUserId}';
    try {
      await Share.share(text);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) _showToast('Profile link copied!', isSuccess: true);
    }
  }

  // ──────────────────────────────────────────────────────────────
  // BLOCK FLOW
  // ──────────────────────────────────────────────────────────────

  void _handleBlockTap() {
    HapticFeedback.mediumImpact();
    _isBlocked ? _showUnblockConfirmSheet() : _showBlockConfirmSheet();
  }

  void _showBlockConfirmSheet() {
    showModalBottomSheet(
      context           : context,
      backgroundColor   : Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BlockConfirmSheet(
        targetName    : widget.targetName,
        targetUsername: widget.targetUsername,
        avatarUrl     : widget.targetAvatarUrl,
        onConfirm: () async {
          final ok = await _blockUser();
          if (!mounted) return;
          Navigator.pop(context);       // close block confirm sheet
          if (ok) {
            Navigator.pop(context);     // close main options sheet
            _showToast('@${widget.targetUsername} blocked.', isSuccess: false);
          } else {
            _showToast('Something went wrong. Try again.', isSuccess: false);
          }
        },
      ),
    );
  }

  void _showUnblockConfirmSheet() {
    showModalBottomSheet(
      context           : context,
      backgroundColor   : Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _UnblockConfirmSheet(
        targetName    : widget.targetName,
        targetUsername: widget.targetUsername,
        avatarUrl     : widget.targetAvatarUrl,
        onConfirm: () async {
          final ok = await _unblockUser();
          if (!mounted) return;
          Navigator.pop(context);       // close unblock confirm sheet
          if (ok) {
            Navigator.pop(context);     // close main options sheet
            _showToast('@${widget.targetUsername} unblocked.', isSuccess: true);
          } else {
            _showToast('Something went wrong. Try again.', isSuccess: false);
          }
        },
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // FIX 3: REPORT — rootContext captured before Navigator.pop
  // ──────────────────────────────────────────────────────────────

  void _handleReportTap() {
    HapticFeedback.mediumImpact();

    // Capture context BEFORE async gap / Navigator.pop
    final rootContext = context;
    Navigator.pop(context);

    showModalBottomSheet(
      context           : rootContext,
      backgroundColor   : Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => _ProfileReportSheet(
        targetUsername: widget.targetUsername,
        targetName    : widget.targetName,
        avatarUrl     : widget.targetAvatarUrl,
        onReasonSelected: (reason) async {
          // Close reason sheet immediately using its own context
          Navigator.of(sheetCtx).pop();

          bool isDuplicate = false;
          bool hasError    = false;

          try {
            final ok = await _submitProfileReport(reason);
            isDuplicate = !ok;
          } catch (_) {
            hasError = true;
          }

          if (hasError) {
            _showToastOn(rootContext,
                'දෝෂයක් ඇතිවිය. නැවත උත්සාහ කරන්න.',
                isSuccess: false);
            return;
          }
          if (isDuplicate) {
            _showToastOn(rootContext,
                'ඔබ දැනටමත් මෙම ප්‍රොෆයිල් එක report කර ඇත.',
                isSuccess: false);
            return;
          }

          // Success sheet
          if (rootContext.mounted) {
            showModalBottomSheet(
              context        : rootContext,
              backgroundColor: Colors.transparent,
              isDismissible  : true,
              builder        : (_) => const _ProfileReportSuccessSheet(),
            );
          }
        },
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // ABOUT
  // ──────────────────────────────────────────────────────────────

  void _handleAboutTap() {
    HapticFeedback.lightImpact();
    final rootContext = context;
    Navigator.pop(context);

    showModalBottomSheet(
      context           : rootContext,
      backgroundColor   : Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AboutAccountSheet(
        targetName    : widget.targetName,
        targetUsername: widget.targetUsername,
        avatarUrl     : widget.targetAvatarUrl,
        fetchAbout    : _fetchAboutAccount,
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // TOAST
  // ──────────────────────────────────────────────────────────────

  void _showToast(String msg, {required bool isSuccess}) =>
      _showToastOn(context, msg, isSuccess: isSuccess);

  void _showToastOn(BuildContext ctx, String msg, {required bool isSuccess}) {
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.info_outline,
              color: Colors.white,
              size : 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(msg,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13.5)),
            ),
          ],
        ),
        backgroundColor: isSuccess
            ? const Color(0xFF1E7D4F)
            : const Color(0xFF2C2C2C),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape   : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          decoration: const BoxDecoration(
            color        : Color(0xFF1C1C1E),
            borderRadius : BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width : 40,
                height: 4,
                decoration: BoxDecoration(
                  color        : Colors.white.withOpacity(0.2),
                  borderRadius : BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                child: Row(
                  children: [
                    _SmallAvatar(
                        url : widget.targetAvatarUrl,
                        name: widget.targetName),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.targetName,
                            style: const TextStyle(
                              color     : Colors.white,
                              fontSize  : 15,
                              fontWeight: FontWeight.w600,
                            )),
                        Text('@${widget.targetUsername}',
                            style: const TextStyle(
                              color   : Color(0xFF888888),
                              fontSize: 12.5,
                            )),
                      ],
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
                child  : Divider(color: Color(0xFF2C2C2C), height: 1),
              ),
              _OptionTile(
                icon     : Icons.share_outlined,
                iconColor: const Color(0xFF4FC3F7),
                title    : 'Share Profile',
                subtitle : 'Share this profile link with others',
                onTap    : _handleShareProfile,
              ),
              _OptionTile(
                icon     : Icons.flag_outlined,
                iconColor: const Color(0xFFFFB74D),
                title    : 'Report',
                subtitle : 'Report inappropriate profile',
                onTap    : _handleReportTap,
              ),
              _OptionTile(
                icon     : _isBlocked
                    ? Icons.block_flipped
                    : Icons.block_outlined,
                iconColor: const Color(0xFFEF5350),
                title    : _isBlocked
                    ? 'Unblock @${widget.targetUsername}'
                    : 'Block @${widget.targetUsername}',
                subtitle : _isBlocked
                    ? 'Allow this person to interact with you'
                    : 'They won\'t be able to see your content',
                onTap    : _isLoadingBlock ? null : _handleBlockTap,
                trailing : _isLoadingBlock
                    ? const SizedBox(
                  width : 18,
                  height: 18,
                  child : CircularProgressIndicator(
                    strokeWidth: 2,
                    color      : Color(0xFFEF5350),
                  ),
                )
                    : null,
              ),
              _OptionTile(
                icon     : Icons.info_outline_rounded,
                iconColor: const Color(0xFFA5D6A7),
                title    : 'About this Account',
                subtitle : 'See when this account joined',
                onTap    : _handleAboutTap,
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
                child  : Divider(color: Color(0xFF2C2C2C), height: 1),
              ),
              _OptionTile(
                icon     : Icons.close_rounded,
                iconColor: const Color(0xFF888888),
                title    : 'Cancel',
                subtitle : '',
                onTap    : () => Navigator.pop(context),
                isCancel : true,
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PROFILE REPORT SHEET
// ═══════════════════════════════════════════════════════════════════
class _ProfileReportSheet extends StatefulWidget {
  final String targetUsername;
  final String targetName;
  final String avatarUrl;
  final void Function(String reason) onReasonSelected;

  const _ProfileReportSheet({
    required this.targetUsername,
    required this.targetName,
    required this.avatarUrl,
    required this.onReasonSelected,
  });

  @override
  State<_ProfileReportSheet> createState() => _ProfileReportSheetState();
}

class _ProfileReportSheetState extends State<_ProfileReportSheet> {
  bool _isSubmitting = false;

  static const List<Map<String, dynamic>> _reasons = [
    {
      'label'      : 'Fake Account',
      'description': 'This account appears fake or doesn\'t represent a real person',
      'icon'       : Icons.person_off_outlined,
      'color'      : Color(0xFFFFB74D),
    },
    {
      'label'      : 'Impersonation',
      'description': 'Pretending to be someone else or another account',
      'icon'       : Icons.masks_outlined,
      'color'      : Color(0xFFEF5350),
    },
    {
      'label'      : 'Inappropriate Profile Info',
      'description': 'Offensive profile picture, bio, or profile content',
      'icon'       : Icons.no_photography_outlined,
      'color'      : Color(0xFFCE93D8),
    },
    {
      'label'      : 'Harassment',
      'description': 'Sending abusive messages or bullying other users',
      'icon'       : Icons.report_gmailerrorred_outlined,
      'color'      : Color(0xFF90CAF9),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color        : Color(0xFF1C1C1E),
        borderRadius : BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width : 40,
            height: 4,
            decoration: BoxDecoration(
              color        : Colors.white.withOpacity(0.2),
              borderRadius : BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Column(
              children: [
                _SmallAvatar(url: widget.avatarUrl, name: widget.targetName, size: 52),
                const SizedBox(height: 12),
                Text(
                  'Report @${widget.targetUsername}',
                  style: const TextStyle(
                    color     : Colors.white,
                    fontSize  : 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Why are you reporting this profile?',
                  style: TextStyle(color: Color(0xFF888888), fontSize: 13),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color        : const Color(0xFF1E3A4A),
                    borderRadius : BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF4FC3F7).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: Color(0xFF4FC3F7), size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Profile reports are reviewed manually by our team.',
                          style: TextStyle(
                            color   : Colors.white.withOpacity(0.65),
                            fontSize: 11.5,
                            height  : 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
            child  : Divider(color: Color(0xFF2C2C2C), height: 1),
          ),
          if (_isSubmitting)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child  : CircularProgressIndicator(
                color      : Color(0xFFFFB74D),
                strokeWidth: 2.5,
              ),
            )
          else
            ..._reasons.map(
                  (r) => _ReportReasonTile(
                label      : r['label']       as String,
                description: r['description'] as String,
                icon       : r['icon']        as IconData,
                color      : r['color']       as Color,
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (!_isSubmitting) {
                    setState(() => _isSubmitting = true);
                    widget.onReasonSelected(r['label'] as String);
                  }
                },
              ),
            ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// REPORT REASON TILE
// ═══════════════════════════════════════════════════════════════════
class _ReportReasonTile extends StatelessWidget {
  final String   label;
  final String   description;
  final IconData icon;
  final Color    color;
  final VoidCallback onTap;

  const _ReportReasonTile({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap         : onTap,
        splashColor   : Colors.white.withOpacity(0.04),
        highlightColor: Colors.white.withOpacity(0.02),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(
            children: [
              Container(
                width : 42,
                height: 42,
                decoration: BoxDecoration(
                  color        : color.withOpacity(0.13),
                  borderRadius : BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                          color     : Colors.white,
                          fontSize  : 14.5,
                          fontWeight: FontWeight.w500,
                        )),
                    const SizedBox(height: 2),
                    Text(description,
                        style: const TextStyle(
                            color: Color(0xFF666666), fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: Color(0xFF444444), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PROFILE REPORT SUCCESS SHEET
// ═══════════════════════════════════════════════════════════════════
class _ProfileReportSuccessSheet extends StatefulWidget {
  const _ProfileReportSuccessSheet();

  @override
  State<_ProfileReportSuccessSheet> createState() =>
      _ProfileReportSuccessSheetState();
}

class _ProfileReportSuccessSheetState
    extends State<_ProfileReportSuccessSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fadeAnim  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D2B1F), Color(0xFF1A3A2A)],
          begin : Alignment.topLeft,
          end   : Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          28, 28, 28, MediaQuery.of(context).padding.bottom + 28),
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scaleAnim,
              child: Container(
                width : 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1BC270), Color(0xFF0DA55A)],
                    begin : Alignment.topLeft,
                    end   : Alignment.bottomRight,
                  ),
                  shape    : BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color      : const Color(0xFF1BC270).withOpacity(0.45),
                      blurRadius : 28,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 44),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Report Submitted',
                style: TextStyle(
                  color     : Colors.white,
                  fontSize  : 21,
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 8),
            Text(
              'ඔබගේ report එක අපට ලැබී ඇත.\n'
                  'අපගේ team එක manually review කරලා\n'
                  'ඉක්මනින් action ගන්නවා.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 13.5,
                  height  : 1.65),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color        : Colors.white.withOpacity(0.06),
                borderRadius : BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF1BC270).withOpacity(0.25),
                    width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined,
                      color: Color(0xFF1BC270), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Profile reports are reviewed manually. '
                          'The account will NOT be hidden automatically.',
                      style: TextStyle(
                          color  : Colors.white.withOpacity(0.5),
                          fontSize: 11.5,
                          height : 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TweenAnimationBuilder<double>(
              tween   : Tween(begin: 0, end: 1),
              duration: const Duration(seconds: 3),
              builder : (_, v, __) => ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value          : v,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor     : const AlwaysStoppedAnimation(
                      Color(0xFF1BC270)),
                  minHeight      : 4,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text('Closing automatically…',
                style: TextStyle(
                    color   : Colors.white.withOpacity(0.35),
                    fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// OPTION TILE
// ═══════════════════════════════════════════════════════════════════
class _OptionTile extends StatelessWidget {
  final IconData      icon;
  final Color         iconColor;
  final String        title;
  final String        subtitle;
  final VoidCallback? onTap;
  final Widget?       trailing;
  final bool          isCancel;

  const _OptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.isCancel = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap         : onTap,
        splashColor   : Colors.white.withOpacity(0.04),
        highlightColor: Colors.white.withOpacity(0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(
            children: [
              Container(
                width : 40,
                height: 40,
                decoration: BoxDecoration(
                  color        : iconColor.withOpacity(0.12),
                  borderRadius : BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color     : isCancel
                            ? const Color(0xFF888888)
                            : Colors.white,
                        fontSize  : 14.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              color: Color(0xFF666666), fontSize: 12)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// BLOCK CONFIRM SHEET
// ═══════════════════════════════════════════════════════════════════
class _BlockConfirmSheet extends StatelessWidget {
  final String targetName;
  final String targetUsername;
  final String avatarUrl;
  final VoidCallback onConfirm;

  const _BlockConfirmSheet({
    required this.targetName,
    required this.targetUsername,
    required this.avatarUrl,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color        : Color(0xFF1C1C1E),
        borderRadius : BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width : 40, height: 4,
            decoration: BoxDecoration(
              color        : Colors.white.withOpacity(0.2),
              borderRadius : BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          _SmallAvatar(url: avatarUrl, name: targetName, size: 56),
          const SizedBox(height: 14),
          Text('Block @$targetUsername?',
              style: const TextStyle(
                  color: Colors.white, fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(
            'They won\'t be able to find your profile, posts,\nor send you messages on VibeFlick.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.55),
                fontSize: 13.5, height: 1.5),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height    : 48,
                    decoration: BoxDecoration(
                        color       : const Color(0xFF2C2C2E),
                        borderRadius: BorderRadius.circular(14)),
                    child: const Center(
                      child: Text('Cancel',
                          style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: onConfirm,
                  child: Container(
                    height    : 48,
                    decoration: BoxDecoration(
                      gradient    : const LinearGradient(
                          colors: [Color(0xFFEF5350), Color(0xFFB71C1C)]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text('Block',
                          style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// UNBLOCK CONFIRM SHEET
// ═══════════════════════════════════════════════════════════════════
class _UnblockConfirmSheet extends StatelessWidget {
  final String targetName;
  final String targetUsername;
  final String avatarUrl;
  final VoidCallback onConfirm;

  const _UnblockConfirmSheet({
    required this.targetName,
    required this.targetUsername,
    required this.avatarUrl,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color        : Color(0xFF1C1C1E),
        borderRadius : BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width : 40, height: 4,
            decoration: BoxDecoration(
              color        : Colors.white.withOpacity(0.2),
              borderRadius : BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          _SmallAvatar(url: avatarUrl, name: targetName, size: 56),
          const SizedBox(height: 14),
          Text('Unblock @$targetUsername?',
              style: const TextStyle(
                  color: Colors.white, fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(
            'They will be able to find your profile and\ninteract with your content again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.55),
                fontSize: 13.5, height: 1.5),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height    : 48,
                    decoration: BoxDecoration(
                        color       : const Color(0xFF2C2C2E),
                        borderRadius: BorderRadius.circular(14)),
                    child: const Center(
                      child: Text('Cancel',
                          style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: onConfirm,
                  child: Container(
                    height    : 48,
                    decoration: BoxDecoration(
                      gradient    : const LinearGradient(
                          colors: [Color(0xFF1BC270), Color(0xFF0DA55A)]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text('Unblock',
                          style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ABOUT ACCOUNT SHEET — Firestore direct
// ═══════════════════════════════════════════════════════════════════
class _AboutAccountSheet extends StatefulWidget {
  final String targetName;
  final String targetUsername;
  final String avatarUrl;
  final Future<Map<String, dynamic>?> Function() fetchAbout;

  const _AboutAccountSheet({
    required this.targetName,
    required this.targetUsername,
    required this.avatarUrl,
    required this.fetchAbout,
  });

  @override
  State<_AboutAccountSheet> createState() => _AboutAccountSheetState();
}

class _AboutAccountSheetState extends State<_AboutAccountSheet> {
  bool _loading = true;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    widget.fetchAbout().then((d) {
      if (mounted) setState(() { _data = d; _loading = false; });
    });
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return 'Unknown';
    try {
      final int secs = (ts is int && ts > 9999999999) ? ts ~/ 1000 : (ts as int);
      final dt = DateTime.fromMillisecondsSinceEpoch(secs * 1000);
      const months = [
        'January','February','March','April','May','June',
        'July','August','September','October','November','December',
      ];
      return 'Joined ${months[dt.month - 1]} ${dt.year}';
    } catch (_) { return 'Unknown'; }
  }

  String _fmt(dynamic n) {
    final v = (n is num) ? n.toInt() : int.tryParse('$n') ?? 0;
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '${(v / 1000).toStringAsFixed(1)}K';
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color        : Color(0xFF1C1C1E),
        borderRadius : BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width : 40, height: 4,
            decoration: BoxDecoration(
              color        : Colors.white.withOpacity(0.2),
              borderRadius : BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _SmallAvatar(url: widget.avatarUrl, name: widget.targetName, size: 44),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.targetName,
                      style: const TextStyle(color: Colors.white,
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  Text('@${widget.targetUsername}',
                      style: const TextStyle(
                          color: Color(0xFF888888), fontSize: 12.5)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child  : CircularProgressIndicator(
                  color: Color(0xFF1BC270), strokeWidth: 2.5),
            )
          else if (_data == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(
                children: [
                  Icon(Icons.cloud_off_outlined,
                      color: Colors.white.withOpacity(0.25), size: 36),
                  const SizedBox(height: 10),
                  Text('Could not load account info.',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 13.5)),
                ],
              ),
            )
          else ...[
              const Divider(color: Color(0xFF2C2C2C), height: 1),
              const SizedBox(height: 16),
              _InfoRow(
                icon     : Icons.calendar_today_outlined,
                iconColor: const Color(0xFF90CAF9),
                label    : 'Account Created',
                value    : _formatDate(_data!['joinDate']),
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon     : Icons.movie_creation_outlined,
                iconColor: const Color(0xFFCE93D8),
                label    : 'Posts',
                value    : _fmt(_data!['postCount']),
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon     : Icons.people_outline,
                iconColor: const Color(0xFF80DEEA),
                label    : 'Followers',
                value    : _fmt(_data!['followerCount']),
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon     : Icons.verified_outlined,
                iconColor: const Color(0xFFA5D6A7),
                label    : 'Verified Account',
                value    : (_data!['isVerified'] == true) ? 'Yes ✓' : 'No',
              ),

              // ── Country ───────────────────────────────────────────
              if ((_data!['country'] as String).isNotEmpty) ...[
                const SizedBox(height: 12),
                _InfoRow(
                  icon     : Icons.public_outlined,
                  iconColor: const Color(0xFFFFCC80),
                  label    : 'Account Location',
                  value    : _data!['country'] as String,
                ),
              ],

              // ── Former Usernames ──────────────────────────────────
              if ((_data!['formerUsernames'] as List<String>).isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(color: Color(0xFF2C2C2C), height: 1),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width : 36, height: 36,
                      decoration: BoxDecoration(
                        color        : const Color(0xFFFFB74D).withOpacity(0.13),
                        borderRadius : BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.history_rounded,
                          color: Color(0xFFFFB74D), size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Text('Former Usernames',
                        style: TextStyle(
                            color: Color(0xFF888888), fontSize: 13.5)),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (_data!['formerUsernames'] as List<String>)
                      .map((name) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color        : const Color(0xFF2C2C2E),
                      borderRadius : BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFFFFB74D).withOpacity(0.25),
                          width: 1),
                    ),
                    child: Text('@$name',
                        style: const TextStyle(
                          color    : Colors.white,
                          fontSize : 12.5,
                          fontWeight: FontWeight.w500,
                        )),
                  ))
                      .toList(),
                ),
              ],

              const SizedBox(height: 20),
              Container(
                width  : double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color        : const Color(0xFF0D2B1F).withOpacity(0.8),
                  borderRadius : BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF1BC270).withOpacity(0.2), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined,
                        color: Color(0xFF1BC270), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Account information is provided\nto help keep VibeFlick safe.',
                        style: TextStyle(color: Colors.white.withOpacity(0.55),
                            fontSize: 12, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// INFO ROW
// ═══════════════════════════════════════════════════════════════════
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   label;
  final String   value;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width : 36, height: 36,
          decoration: BoxDecoration(
            color        : iconColor.withOpacity(0.12),
            borderRadius : BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: const TextStyle(color: Color(0xFF888888), fontSize: 13.5)),
        ),
        Text(value,
            style: const TextStyle(color: Colors.white,
                fontSize: 13.5, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SMALL AVATAR
// ═══════════════════════════════════════════════════════════════════
class _SmallAvatar extends StatelessWidget {
  final String url;
  final String name;
  final double size;

  const _SmallAvatar({
    required this.url,
    required this.name,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final colours  = [
      const Color(0xFF3B82F6), const Color(0xFFE53935),
      const Color(0xFF10B981), const Color(0xFF8B5CF6),
    ];
    final bg = colours[name.hashCode.abs() % colours.length];

    return Container(
      width : size, height: size,
      decoration: BoxDecoration(
        shape : BoxShape.circle,
        color : bg,
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
      ),
      child: ClipOval(
        child: url.isNotEmpty
            ? CachedNetworkImage(
          imageUrl   : url,
          fit        : BoxFit.cover,
          errorWidget: (_, __, ___) => Center(
            child: Text(initials,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        )
            : Center(
          child: Text(initials,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}