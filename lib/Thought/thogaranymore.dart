import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../screens/ thogar_report_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ThogarAnymore — "More" Action Sheet
//  Dark Glassmorphism | Owner vs Viewer options | Confirm dialogs
// ─────────────────────────────────────────────────────────────────────────────

class ThogarAnymore {
  static const String _baseUrl = 'https://avishka-tiktok-api.zeabur.app';

  /// Call this from onMoreOptions callback
  static void showMoreSheet({
    required BuildContext context,
    required String postId,
    required String postOwnerId,
    required String content,
    required bool isAnonymous,
    required String cityName,
    String? username,
    String? avatarUrl,
    VoidCallback? onDeleted,
    VoidCallback? onEdited,
    void Function(String postId)? onReport,   // ← FIX: added here
  }) {
    HapticFeedback.lightImpact();

    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner     = currentUser != null && currentUser.uid == postOwnerId;

    debugPrint('\n⋯  ========== MORE OPTIONS SHEET ==========');
    debugPrint('   Post ID  : $postId');
    debugPrint('   Owner    : $postOwnerId');
    debugPrint('   Viewer   : ${currentUser?.uid ?? "guest"}');
    debugPrint('   Is Owner : $isOwner');
    debugPrint('==========================================\n');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MoreSheet(
        postId      : postId,
        postOwnerId : postOwnerId,
        content     : content,
        isAnonymous : isAnonymous,
        cityName    : cityName,
        username    : username,
        avatarUrl   : avatarUrl,
        isOwner     : isOwner,
        currentUser : currentUser,
        onDeleted   : onDeleted,
        onEdited    : onEdited,
        onReport    : onReport,   // ← FIX: passed to sheet
        baseUrl     : _baseUrl,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _MoreSheet — Bottom sheet widget
// ─────────────────────────────────────────────────────────────────────────────
class _MoreSheet extends StatefulWidget {
  final String   postId;
  final String   postOwnerId;
  final String   content;
  final bool     isAnonymous;
  final String   cityName;
  final String?  username;
  final String?  avatarUrl;
  final bool     isOwner;
  final User?    currentUser;
  final VoidCallback? onDeleted;
  final VoidCallback? onEdited;
  final void Function(String postId)? onReport;  // ← FIX: final + correct syntax
  final String   baseUrl;

  const _MoreSheet({
    required this.postId,
    required this.postOwnerId,
    required this.content,
    required this.isAnonymous,
    required this.cityName,
    required this.username,
    required this.avatarUrl,
    required this.isOwner,
    required this.currentUser,
    required this.baseUrl,
    this.onDeleted,
    this.onEdited,
    this.onReport,
  });

  @override
  State<_MoreSheet> createState() => _MoreSheetState();
}

class _MoreSheetState extends State<_MoreSheet>
    with SingleTickerProviderStateMixin {

  bool _loading = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  void _dismiss() => Navigator.of(context).pop();

  void _setLoading(bool v) => setState(() => _loading = v);

  void _showSnack(String msg, {Color color = Colors.white24}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── OWNER ACTIONS ─────────────────────────────────────────────────────────────

  void _onEditPost() {
    _dismiss();
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (_) => _EditPostDialog(
        postId  : widget.postId,
        content : widget.content,
        baseUrl : widget.baseUrl,
        onSaved : widget.onEdited,
      ),
    );
  }

  Future<void> _onPinToTop() async {
    _dismiss();
    _showSnack('📌 Post pinned to top!', color: Colors.blueAccent.withOpacity(0.8));

    try {
      await http.post(
        Uri.parse('${widget.baseUrl}/api/text-posts/${widget.postId}/pin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': widget.currentUser?.uid}),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('❌ Pin error: $e');
    }
  }

  Future<void> _onDisableComments() async {
    _dismiss();
    _showSnack('💬 Comments disabled', color: Colors.orange.withOpacity(0.8));

    try {
      await http.post(
        Uri.parse('${widget.baseUrl}/api/text-posts/${widget.postId}/disable-comments'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': widget.currentUser?.uid}),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('❌ Disable comments error: $e');
    }
  }

  void _onDeletePost() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (_) => _DeleteConfirmDialog(
        onConfirm: () async {
          Navigator.of(context).pop();
          _dismiss();

          try {
            final response = await http.delete(
              Uri.parse('${widget.baseUrl}/api/text-posts/${widget.postId}'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'uid': widget.currentUser?.uid}),
            ).timeout(const Duration(seconds: 10));

            final body = jsonDecode(response.body) as Map<String, dynamic>;

            if (response.statusCode == 200 && body['success'] == true) {
              _showSnack('🗑️ Post deleted', color: Colors.redAccent.withOpacity(0.8));
              widget.onDeleted?.call();
            } else {
              _showSnack('Delete failed. Try again.', color: Colors.redAccent);
            }
          } catch (e) {
            debugPrint('❌ Delete error: $e');
            _showSnack('Network error.', color: Colors.redAccent);
          }
        },
      ),
    );
  }

  // ── VIEWER ACTIONS ────────────────────────────────────────────────────────────

  void _onReportPost() {
    _dismiss();
    showDialog(
      context     : context,
      barrierColor: Colors.black.withOpacity(0.75),
      builder     : (_) => _ThogarReportDialog(
        postId            : widget.postId,
        postOwnerId       : widget.postOwnerId,
        postOwnerUsername : widget.username ?? 'Unknown',
        isAnonymous       : widget.isAnonymous,
        cityName          : widget.cityName,
        content           : widget.content,
        onReported        : (autoHidden) {
          // Screen level callback ─ old _reportPost compat
          if (autoHidden) widget.onReport?.call(widget.postId);
        },
      ),
    );
  }

  Future<void> _onBlockUser() async {
    _dismiss();

    try {
      final response = await http.post(
        Uri.parse('${widget.baseUrl}/api/users/${widget.currentUser?.uid}/block'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'targetUid': widget.postOwnerId}),
      ).timeout(const Duration(seconds: 10));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      _showSnack(
        body['success'] == true ? '🚫 User blocked' : 'Could not block user.',
        color: body['success'] == true
            ? Colors.redAccent.withOpacity(0.8)
            : Colors.white24,
      );
    } catch (e) {
      debugPrint('❌ Block error: $e');
      _showSnack('Network error.', color: Colors.redAccent);
    }
  }

  Future<void> _onNotInterested() async {
    _dismiss();
    _showSnack('👎 Got it — fewer posts like this', color: Colors.white24);

    try {
      await http.post(
        Uri.parse('${widget.baseUrl}/api/text-posts/${widget.postId}/not-interested'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': widget.currentUser?.uid}),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('❌ Error: $e');
    }
  }

  void _onCopyLink() {
    final link = 'https://thogar.app/post/${widget.postId}';
    Clipboard.setData(ClipboardData(text: link));
    _dismiss();
    _showSnack('🔗 Link copied!', color: Colors.blueAccent.withOpacity(0.8));
  }

  // ════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0e0e16).withOpacity(0.96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 32,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildPostPreview(),
                  const SizedBox(height: 8),
                  Divider(color: Colors.white.withOpacity(0.07), height: 1),
                  const SizedBox(height: 8),
                  if (widget.isOwner) ..._ownerOptions()
                  else ..._viewerOptions(),
                  const SizedBox(height: 16),
                  _MoreOption(
                    icon    : Icons.close_rounded,
                    label   : 'Cancel',
                    onTap   : _dismiss,
                    iconColor: Colors.white38,
                    labelColor: Colors.white38,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPostPreview() {
    final preview = widget.content.length > 80
        ? '${widget.content.substring(0, 80)}…'
        : widget.content;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white.withOpacity(0.1),
          backgroundImage: (!widget.isAnonymous && widget.avatarUrl != null)
              ? NetworkImage(widget.avatarUrl!) : null,
          child: (widget.isAnonymous || widget.avatarUrl == null)
              ? Icon(
              widget.isAnonymous
                  ? Icons.visibility_off_rounded
                  : Icons.person_rounded,
              size: 16, color: Colors.white54)
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isAnonymous ? 'Anonymous Vibe' : (widget.username ?? 'Unknown'),
              style: const TextStyle(
                  color: Colors.white70, fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(preview,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: widget.isOwner
                ? Colors.blueAccent.withOpacity(0.15)
                : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isOwner
                  ? Colors.blueAccent.withOpacity(0.3)
                  : Colors.white.withOpacity(0.1),
            ),
          ),
          child: Text(
            widget.isOwner ? 'Your post' : 'Vibe',
            style: TextStyle(
              color: widget.isOwner ? Colors.blueAccent : Colors.white38,
              fontSize: 10, fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ]),
    );
  }

  List<Widget> _ownerOptions() => [
    _MoreOption(
      icon    : Icons.edit_rounded,
      label   : 'Edit Post',
      sublabel: 'Change what you wrote',
      onTap   : _onEditPost,
      iconColor: Colors.blueAccent,
    ),
    _MoreOption(
      icon    : Icons.push_pin_rounded,
      label   : 'Pin to Top',
      sublabel: 'Show first on your profile',
      onTap   : _onPinToTop,
      iconColor: Colors.amberAccent,
    ),
    _MoreOption(
      icon    : Icons.comments_disabled_rounded,
      label   : 'Disable Comments',
      sublabel: 'Stop others from commenting',
      onTap   : _onDisableComments,
      iconColor: Colors.orange,
    ),
    _MoreOption(
      icon     : Icons.delete_rounded,
      label    : 'Delete Post',
      sublabel : 'This cannot be undone',
      onTap    : _onDeletePost,
      iconColor : Colors.redAccent,
      labelColor: Colors.redAccent,
      isDanger  : true,
    ),
  ];

  List<Widget> _viewerOptions() => [
    _MoreOption(
      icon    : Icons.flag_rounded,
      label   : 'Report Post',
      sublabel: 'Flag inappropriate content',
      onTap   : _onReportPost,
      iconColor: Colors.orangeAccent,
    ),
    _MoreOption(
      icon    : Icons.block_rounded,
      label   : 'Block User',
      sublabel: 'Hide all posts from this person',
      onTap   : _onBlockUser,
      iconColor: Colors.redAccent,
      labelColor: Colors.redAccent,
      isDanger: true,
    ),
    _MoreOption(
      icon    : Icons.thumb_down_alt_rounded,
      label   : 'Not Interested',
      sublabel: 'See fewer posts like this',
      onTap   : _onNotInterested,
      iconColor: Colors.white54,
    ),
    _MoreOption(
      icon    : Icons.link_rounded,
      label   : 'Copy Link',
      sublabel: 'Share this vibe with others',
      onTap   : _onCopyLink,
      iconColor: Colors.blueAccent,
    ),
  ];
}

// ════════════════════════════════════════════════════════════════════
// STEP 3 — File end කට (last closing brace ට BEFORE) paste කරන්න:
//           (_ReportDialog class ට after කරන්න ‒ file end කට)
// ════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────
//  _ThogarReportDialog — Together-specific reason picker + service call
// ─────────────────────────────────────────────────────────────────────
class _ThogarReportDialog extends StatefulWidget {
  final String   postId;
  final String   postOwnerId;
  final String   postOwnerUsername;
  final bool     isAnonymous;
  final String   cityName;
  final String   content;
  final void Function(bool autoHidden) onReported;

  const _ThogarReportDialog({
    required this.postId,
    required this.postOwnerId,
    required this.postOwnerUsername,
    required this.isAnonymous,
    required this.cityName,
    required this.content,
    required this.onReported,
  });

  @override
  State<_ThogarReportDialog> createState() => _ThogarReportDialogState();
}

class _ThogarReportDialogState extends State<_ThogarReportDialog> {
  String? _selectedReason;
  bool    _sending = false;

  final List<String> _reasons = [
    'Spam or Misleading',
    'Hate Speech or Harassment',
    'Nudity or Sexual Content',
    'Violence or Dangerous Organizations',
    'False Information',
    'Other',
  ];

  Future<void> _submit() async {
    if (_selectedReason == null || _sending) return;
    setState(() => _sending = true);

    final result = await ThogarReportService.submitReport(
      postId            : widget.postId,
      postOwnerId       : widget.postOwnerId,
      postOwnerUsername : widget.isAnonymous
          ? 'Anonymous'
          : widget.postOwnerUsername,
      reason            : _selectedReason!,
      isAnonymous       : widget.isAnonymous,
      location          : widget.cityName.isNotEmpty
          ? widget.cityName
          : 'Unknown',
      content           : widget.content,
    );

    if (!mounted) return;
    Navigator.of(context).pop();

    String snackMsg;
    Color  snackColor;

    if (result.isDuplicate) {
      snackMsg  = 'ඔබ මෙම පෝස්ට් එක දැනටමත් report කර ඇත.';
      snackColor = Colors.orangeAccent;
    } else if (result.isError) {
      snackMsg  = 'Report failed. Try again.';
      snackColor = Colors.redAccent;
    } else if (result.autoHidden) {
      snackMsg  = 'Post hidden due to multiple reports. Thanks!';
      snackColor = Colors.orangeAccent;
    } else {
      snackMsg  = '🚩 Reported. Thank you.';
      snackColor = Colors.orange;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content         : Text(snackMsg,
          style: const TextStyle(color: Colors.white)),
      backgroundColor : snackColor,
      behavior        : SnackBarBehavior.floating,
      shape           : RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
    ));

    widget.onReported(result.autoHidden);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding   : const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color        : const Color(0xFF111118).withOpacity(0.95),
              borderRadius : BorderRadius.circular(24),
              border       : Border.all(
                  color: Colors.orangeAccent.withOpacity(0.2)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [

              // Header
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color       : Colors.orangeAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.flag_rounded,
                      color: Colors.orangeAccent, size: 18),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Report Post',
                        style: TextStyle(color: Colors.white,
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(
                      widget.isAnonymous ? 'Anonymous post' : widget.cityName,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ]),

              const SizedBox(height: 6),
              const Text('Why are you reporting this?',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 16),

              // Reason list
              ..._reasons.map((reason) => GestureDetector(
                onTap: () => setState(() => _selectedReason = reason),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin : const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: _selectedReason == reason
                        ? Colors.orangeAccent.withOpacity(0.12)
                        : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedReason == reason
                          ? Colors.orangeAccent.withOpacity(0.5)
                          : Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Row(children: [
                    Icon(
                      _selectedReason == reason
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: _selectedReason == reason
                          ? Colors.orangeAccent : Colors.white38,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(reason,
                        style: TextStyle(
                          color: _selectedReason == reason
                              ? Colors.white : Colors.white70,
                          fontSize: 14,
                          fontWeight: _selectedReason == reason
                              ? FontWeight.w600 : FontWeight.normal,
                        )),
                  ]),
                ),
              )),

              const SizedBox(height: 8),

              // Anon warning
              if (widget.isAnonymous)
                Container(
                  margin : const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color       : Colors.amber.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border      : Border.all(
                        color: Colors.amber.withOpacity(0.2)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info_outline_rounded,
                        color: Colors.amber, size: 14),
                    SizedBox(width: 7),
                    Expanded(child: Text(
                      'Anonymous වුණත් ඔබේ UID system එකේ ඇත. '
                          'Report valid නම් post owner ට Strike ලැබේ.',
                      style: TextStyle(
                          color: Colors.amber, fontSize: 11, height: 1.4),
                    )),
                  ]),
                ),

              // Buttons
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color       : Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(14),
                      border      : Border.all(
                          color: Colors.white.withOpacity(0.1)),
                    ),
                    child: const Text('Cancel',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70,
                            fontWeight: FontWeight.w600)),
                  ),
                )),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(
                  onTap: (_selectedReason != null && !_sending)
                      ? _submit
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding : const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      gradient: _selectedReason != null
                          ? const LinearGradient(colors: [
                        Colors.orangeAccent,
                        Color(0xFFE65100),
                      ])
                          : null,
                      color: _selectedReason == null
                          ? Colors.white.withOpacity(0.05) : null,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: _sending
                        ? const Center(child: SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2)))
                        : Text('Report',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _selectedReason != null
                              ? Colors.white : Colors.white24,
                          fontWeight: FontWeight.bold,
                        )),
                  ),
                )),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _MoreOption — single row option
// ─────────────────────────────────────────────────────────────────────────────
class _MoreOption extends StatefulWidget {
  final IconData  icon;
  final String    label;
  final String?   sublabel;
  final VoidCallback onTap;
  final Color     iconColor;
  final Color?    labelColor;
  final bool      isDanger;

  const _MoreOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.sublabel,
    this.iconColor  = Colors.white70,
    this.labelColor,
    this.isDanger   = false,
  });

  @override
  State<_MoreOption> createState() => _MoreOptionState();
}

class _MoreOptionState extends State<_MoreOption> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown  : (_) => setState(() => _pressed = true),
      onTapUp    : (_) => setState(() => _pressed = false),
      onTapCancel: ()  => setState(() => _pressed = false),
      onTap      : widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin  : const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding : const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: _pressed
              ? (widget.isDanger
              ? Colors.redAccent.withOpacity(0.12)
              : Colors.white.withOpacity(0.06))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _pressed
                ? (widget.isDanger
                ? Colors.redAccent.withOpacity(0.25)
                : Colors.white.withOpacity(0.1))
                : Colors.transparent,
          ),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: widget.iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: widget.iconColor.withOpacity(0.2)),
            ),
            child: Icon(widget.icon, color: widget.iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.label,
                style: TextStyle(
                  color: widget.labelColor ?? Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (widget.sublabel != null) ...[
                const SizedBox(height: 2),
                Text(widget.sublabel!,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ],
          )),
          Icon(Icons.chevron_right_rounded,
              color: widget.isDanger
                  ? Colors.redAccent.withOpacity(0.5)
                  : Colors.white24,
              size: 18),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _DeleteConfirmDialog
// ─────────────────────────────────────────────────────────────────────────────
class _DeleteConfirmDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  const _DeleteConfirmDialog({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF111118).withOpacity(0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                ),
                child: const Icon(Icons.delete_forever_rounded,
                    color: Colors.redAccent, size: 28),
              ),
              const SizedBox(height: 16),
              const Text('Delete Post?',
                style: TextStyle(color: Colors.white,
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'This vibe will be permanently removed.\nThis action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: const Text('Cancel',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                )),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(
                  onTap: onConfirm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.redAccent,
                        Colors.red.shade700,
                      ]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withOpacity(0.35),
                          blurRadius: 12, offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text('Delete',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                )),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _EditPostDialog
// ─────────────────────────────────────────────────────────────────────────────
class _EditPostDialog extends StatefulWidget {
  final String postId;
  final String content;
  final String baseUrl;
  final VoidCallback? onSaved;

  const _EditPostDialog({
    required this.postId,
    required this.content,
    required this.baseUrl,
    this.onSaved,
  });

  @override
  State<_EditPostDialog> createState() => _EditPostDialogState();
}

class _EditPostDialogState extends State<_EditPostDialog> {
  late TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.content);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newContent = _ctrl.text.trim();
    if (newContent.isEmpty || newContent == widget.content) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _saving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final response = await http.patch(
        Uri.parse('${widget.baseUrl}/api/text-posts/${widget.postId}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': uid, 'content': newContent}),
      ).timeout(const Duration(seconds: 10));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (!mounted) return;
      Navigator.of(context).pop();

      if (body['success'] == true) {
        widget.onSaved?.call();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✏️ Post updated!'),
          backgroundColor: Colors.blueAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      debugPrint('❌ Edit error: $e');
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF111118).withOpacity(0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.edit_rounded,
                      color: Colors.blueAccent, size: 18),
                ),
                const SizedBox(width: 10),
                const Text('Edit Post',
                  style: TextStyle(color: Colors.white,
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ]),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: TextField(
                  controller: _ctrl,
                  maxLines: 6,
                  minLines: 3,
                  style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.all(14),
                    border: InputBorder.none,
                    hintText: 'What\'s your vibe?',
                    hintStyle: TextStyle(color: Colors.white24),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: const Text('Cancel',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                )),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(
                  onTap: _saving ? null : _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [
                        Color(0xFF2979FF),
                        Color(0xFF0D47A1),
                      ]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueAccent.withOpacity(0.3),
                          blurRadius: 12, offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _saving
                        ? const Center(child: SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    ))
                        : const Text('Save',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                )),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ReportDialog — Report reasons
// ─────────────────────────────────────────────────────────────────────────────
class _ReportDialog extends StatefulWidget {
  final String postId;
  final String baseUrl;
  final String uid;
  const _ReportDialog({
    required this.postId,
    required this.baseUrl,
    required this.uid,
  });

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String? _selectedReason;
  bool _sending = false;

  final List<String> _reasons = [
    'Spam or misleading',
    'Hate speech or harassment',
    'Nudity or sexual content',
    'Violence or dangerous content',
    'False information',
    'Other',
  ];

  Future<void> _submit() async {
    if (_selectedReason == null) return;
    setState(() => _sending = true);

    try {
      await http.post(
        Uri.parse('${widget.baseUrl}/api/text-posts/${widget.postId}/report'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': widget.uid, 'reason': _selectedReason}),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('❌ Report error: $e');
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('🚩 Report submitted. Thank you.'),
      backgroundColor: Colors.orangeAccent,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF111118).withOpacity(0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.orangeAccent.withOpacity(0.2)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.flag_rounded,
                      color: Colors.orangeAccent, size: 18),
                ),
                const SizedBox(width: 10),
                const Text('Report Post',
                  style: TextStyle(color: Colors.white,
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ]),
              const SizedBox(height: 6),
              const Text('Why are you reporting this?',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 16),
              ..._reasons.map((reason) => GestureDetector(
                onTap: () => setState(() => _selectedReason = reason),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: _selectedReason == reason
                        ? Colors.orangeAccent.withOpacity(0.12)
                        : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedReason == reason
                          ? Colors.orangeAccent.withOpacity(0.5)
                          : Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Row(children: [
                    Icon(
                      _selectedReason == reason
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: _selectedReason == reason
                          ? Colors.orangeAccent : Colors.white38,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(reason,
                      style: TextStyle(
                        color: _selectedReason == reason
                            ? Colors.white : Colors.white70,
                        fontSize: 14,
                        fontWeight: _selectedReason == reason
                            ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ]),
                ),
              )),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: const Text('Cancel',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                )),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(
                  onTap: (_selectedReason != null && !_sending) ? _submit : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      gradient: _selectedReason != null
                          ? const LinearGradient(colors: [
                        Colors.orangeAccent,
                        Color(0xFFE65100),
                      ])
                          : null,
                      color: _selectedReason == null
                          ? Colors.white.withOpacity(0.05) : null,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: _sending
                        ? const Center(child: SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2)))
                        : Text('Report',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _selectedReason != null
                            ? Colors.white : Colors.white24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}