import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileShareBottomSheet extends StatefulWidget {
  final String profileUserId;
  final String profileUsername;
  final String profileDisplayName;
  final String? profileImageUrl;

  const ProfileShareBottomSheet({
    Key? key,
    required this.profileUserId,
    required this.profileUsername,
    required this.profileDisplayName,
    this.profileImageUrl,
  }) : super(key: key);

  static Future<void> show(
      BuildContext context, {
        required String profileUserId,
        required String profileUsername,
        required String profileDisplayName,
        String? profileImageUrl,
      }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) => ProfileShareBottomSheet(
        profileUserId: profileUserId,
        profileUsername: profileUsername,
        profileDisplayName: profileDisplayName,
        profileImageUrl: profileImageUrl,
      ),
    );
  }

  @override
  State<ProfileShareBottomSheet> createState() =>
      _ProfileShareBottomSheetState();
}

class _ProfileShareBottomSheetState extends State<ProfileShareBottomSheet>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late AnimationController _animController;
  late Animation<double> _slideAnim;
  late Animation<double> _fadeAnim;

  List<_FrequentContact> _frequentContacts = [];
  bool _isLoadingContacts = true;
  bool _isSendingDM = false;
  String? _sendingToUserId;


  static const String _appStoreUrl =
      'https://play.google.com/store/apps/details?id=com.vibeflick.app';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
    _loadFrequentContacts();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _buildDeepLink() {
    return 'https://vibeflick-5fe5c.web.app/u/${widget.profileUsername}';
  }

  Future<void> _loadFrequentContacts() async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) {
      setState(() => _isLoadingContacts = false);
      return;
    }
    try {
      final followingSnap = await _db
          .collection('follows')
          .where('followerId', isEqualTo: myUid)
          .where('status', isEqualTo: 'active')
          .limit(10)
          .get();

      final followingIds = followingSnap.docs
          .map((d) => d.data()['followingId'] as String)
          .toList();

      if (followingIds.isEmpty) {
        setState(() => _isLoadingContacts = false);
        return;
      }

      final userDocs = await Future.wait(
        followingIds.take(6).map((uid) => _db.collection('users').doc(uid).get()),
      );

      final contacts = <_FrequentContact>[];
      for (final doc in userDocs) {
        if (doc.exists) {
          final data = doc.data()!;
          contacts.add(_FrequentContact(
            uid: doc.id,
            username: data['name'] as String? ?? 'User',
            avatarUrl: data['profile_picture_url'] as String? ??
                data['profileImageUrl'] as String?,
          ));
        }
      }
      if (mounted) {
        setState(() {
          _frequentContacts = contacts;
          _isLoadingContacts = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Load contacts error: $e');
      if (mounted) setState(() => _isLoadingContacts = false);
    }
  }

  Future<void> _sendInternalDM(String toUserId, String toUsername) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    setState(() {
      _isSendingDM = true;
      _sendingToUserId = toUserId;
    });

    try {
      final deepLink = _buildDeepLink();
      final conversationId = [myUid, toUserId]..sort();
      final convId = conversationId.join('_');

      await _db
          .collection('conversations')
          .doc(convId)
          .collection('messages')
          .add({
        'senderId': myUid,
        'receiverId': toUserId,
        'type': 'profile_share',
        'content': deepLink,
        'profileUserId': widget.profileUserId,
        'profileUsername': widget.profileUsername,
        'profileDisplayName': widget.profileDisplayName,
        'profileImageUrl': widget.profileImageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      await _db.collection('conversations').doc(convId).set({
        'participants': [myUid, toUserId],
        'lastMessage': '${widget.profileDisplayName} ගේ profile share කළා',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageType': 'profile_share',
        'unreadCount_$toUserId': FieldValue.increment(1),
      }, SetOptions(merge: true));

      await _incrementShareCount();

      if (mounted) {
        setState(() {
          _isSendingDM = false;
          _sendingToUserId = null;
        });
        _showSuccessToast('Sent to @$toUsername');
      }
    } catch (e) {
      debugPrint('❌ DM send error: $e');
      if (mounted) {
        setState(() {
          _isSendingDM = false;
          _sendingToUserId = null;
        });
        _showErrorToast('Failed to send');
      }
    }
  }

  Future<void> _incrementShareCount() async {
    try {
      await _db.collection('users').doc(widget.profileUserId).update({
        'shareCount': FieldValue.increment(1),
        'lastSharedAt': FieldValue.serverTimestamp(),
      });
      final userDoc =
      await _db.collection('users').doc(widget.profileUserId).get();
      final shareCount = (userDoc.data()?['shareCount'] as int? ?? 0);
      if (shareCount >= 50) {
        await _db.collection('users').doc(widget.profileUserId).update({
          'isTrending': true,
        });
      }
    } catch (e) {
      debugPrint('⚠️ Share count error: $e');
    }
  }

  Future<void> _copyLink() async {
    final link = _buildDeepLink();
    await Clipboard.setData(ClipboardData(text: link));
    await _incrementShareCount();
    HapticFeedback.lightImpact();
    if (mounted) _showSuccessToast('Link Copied! 🔗');
  }

  Future<void> _shareWhatsApp() async {
    final link = _buildDeepLink();
    final text =
        'Check out ${widget.profileDisplayName} on VibeFlick! 🎵\n$link';
    final waUrl =
    Uri.parse('whatsapp://send?text=${Uri.encodeComponent(text)}');
    await _incrementShareCount();
    if (await canLaunchUrl(waUrl)) {
      await launchUrl(waUrl);
    } else {
      _showErrorToast('WhatsApp not installed');
    }
  }

  Future<void> _shareInstagramStories() async {
    await _incrementShareCount();
    const igUrl = 'instagram-stories://share?source_application=vibeflick';
    final uri = Uri.parse(igUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await _copyLink();
      _showSuccessToast('Instagram not found. Link copied!');
    }
  }

  Future<void> _shareFacebook() async {
    final link = _buildDeepLink();
    final fbUrl = Uri.parse(
        'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(link)}');
    await _incrementShareCount();
    if (await canLaunchUrl(fbUrl)) {
      await launchUrl(fbUrl, mode: LaunchMode.externalApplication);
    } else {
      await _systemShare();
    }
  }

  Future<void> _systemShare() async {
    final link = _buildDeepLink();
    final text =
        'Check out ${widget.profileDisplayName} (@${widget.profileUsername}) on VibeFlick! 🎵\n$link';
    await _incrementShareCount();
    await Share.share(text,
        subject: '${widget.profileDisplayName} on VibeFlick');
  }

  void _showSuccessToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(msg, style: const TextStyle(color: Colors.white)),
      ]),
      backgroundColor: const Color(0xFF1DB954),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
    ));
  }

  void _showErrorToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(_slideAnim),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0E0E0E).withOpacity(0.96),
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDragHandle(),
                    _buildProfileHeader(),
                    const SizedBox(height: 24),
                    _buildQuickSendSection(),
                    const SizedBox(height: 24),
                    _buildExternalActionsGrid(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Container(
        width: 44,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFF3B5C), Color(0xFF8B0000)],
              ),
              border: Border.all(
                color: const Color(0xFFFF3B5C).withOpacity(0.5),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: widget.profileImageUrl != null &&
                  widget.profileImageUrl!.isNotEmpty
                  ? Image.network(
                widget.profileImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _buildAvatarFallback(widget.profileDisplayName),
              )
                  : _buildAvatarFallback(widget.profileDisplayName),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.profileDisplayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '@${widget.profileUsername}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B5C).withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFFF3B5C).withOpacity(0.3),
              ),
            ),
            child: const Icon(
              Icons.ios_share_rounded,
              color: Color(0xFFFF3B5C),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback(String name) {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickSendSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B5C),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Send to Friends',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 88,
          child: _isLoadingContacts
              ? _buildContactsShimmer()
              : _frequentContacts.isEmpty
              ? _buildNoContactsPlaceholder()
              : ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _frequentContacts.length,
            itemBuilder: (context, i) =>
                _buildContactItem(_frequentContacts[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildContactItem(_FrequentContact contact) {
    final isSending = _isSendingDM && _sendingToUserId == contact.uid;
    return GestureDetector(
      onTap: () => _sendInternalDM(contact.uid, contact.username),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 70,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                if (isSending)
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFF3B5C),
                        width: 2,
                      ),
                    ),
                  ),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1A1A1A),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: isSending
                        ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFFF3B5C),
                        ),
                      ),
                    )
                        : (contact.avatarUrl != null &&
                        contact.avatarUrl!.isNotEmpty
                        ? Image.network(
                      contact.avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _buildAvatarFallback(contact.username),
                    )
                        : _buildAvatarFallback(contact.username)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              contact.username,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsShimmer() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 5,
      itemBuilder: (_, __) => Container(
        width: 70,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 40,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoContactsPlaceholder() {
    return Center(
      child: Text(
        'Follow people to send directly',
        style: TextStyle(
          color: Colors.white.withOpacity(0.3),
          fontSize: 13,
        ),
      ),
    );
  }

  // ── SECTION 3: External Actions Grid ──────────────────────────────────────
  Widget _buildExternalActionsGrid() {
    final actions = [
      _ShareAction(
        assetPath: 'assets/images/copy-link-svgrepo-com.svg',
        label: 'Copy Link',
        onTap: _copyLink,
      ),
      _ShareAction(
        assetPath: 'assets/images/whatsapp-svgrepo-com.svg',
        label: 'WhatsApp',
        onTap: _shareWhatsApp,
      ),
      _ShareAction(
        assetPath: 'assets/images/instagram-1-svgrepo-com.svg',
        label: 'Stories',
        onTap: _shareInstagramStories,
      ),
      _ShareAction(
        assetPath: 'assets/images/facebook-svgrepo-com.svg',
        label: 'Facebook',
        onTap: _shareFacebook,
      ),
      _ShareAction(
        fallbackIcon: Icons.more_horiz_rounded,
        label: 'More',
        onTap: _systemShare,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: actions.map((a) => _buildActionTile(a)).toList(),
      ),
    );
  }

  Widget _buildActionTile(_ShareAction action) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        action.onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1,
              ),
            ),
            child: Center(
              child: action.assetPath != null
                  ? SvgPicture.asset(
                action.assetPath!,
                width: 28,
                height: 28,
                // SVG color override කරන්න ඕනෑ නම්:
                // colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
                errorBuilder: (_, __, ___) =>
                action.fallbackIcon != null
                    ? Icon(action.fallbackIcon, color: Colors.white54, size: 24)
                    : const SizedBox.shrink(),
              )
                  : action.fallbackIcon != null
                  ? Icon(action.fallbackIcon, color: Colors.white54, size: 24)
                  : const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            action.label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Helper models
// ══════════════════════════════════════════════════════════════════════════════
class _FrequentContact {
  final String uid;
  final String username;
  final String? avatarUrl;
  const _FrequentContact({
    required this.uid,
    required this.username,
    this.avatarUrl,
  });
}

class _ShareAction {
  final String? assetPath;
  final IconData? fallbackIcon;
  final String label;
  final VoidCallback onTap;
  const _ShareAction({
    this.assetPath,
    this.fallbackIcon,
    required this.label,
    required this.onTap,
  });
}