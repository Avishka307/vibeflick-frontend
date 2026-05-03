import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'activity_user_profile.dart';

// ════════════════════════════════════════════════════════════
//  ContactTab
// ════════════════════════════════════════════════════════════

class ContactTab extends StatefulWidget {
  const ContactTab({Key? key}) : super(key: key);

  @override
  State<ContactTab> createState() => _ContactTabState();
}

class _ContactTabState extends State<ContactTab>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _currentUserId;

  // ── Search ─────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  // ── Contacts ───────────────────────────────────────────
  List<Map<String, dynamic>> _matchedAppUsers = [];
  List<Contact> _phoneContactsNotInApp = [];
  bool _isLoadingContacts = false;
  bool _contactsSynced = false;
  bool _contactPermissionDenied = false;

  // ── Suggested ──────────────────────────────────────────
  List<Map<String, dynamic>> _suggestedUsers = [];
  bool _isLoadingSuggested = false;

  // ── Tab controller (Contacts / Suggested) ──────────────
  late TabController _innerTabController;

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid;
    _innerTabController = TabController(length: 2, vsync: this);
    _loadSuggestedUsers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _innerTabController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════
  //  SEARCH
  // ══════════════════════════════════════════════════════

  void _onSearchChanged() {
    final q = _searchController.text.trim();
    setState(() => _searchQuery = q);
    if (q.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    _performSearch(q);
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);
    try {
      final lower = query.toLowerCase();

      // Search by name
      final nameSnap = await _db
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: lower)
          .where('name', isLessThanOrEqualTo: '$lower\uf8ff')
          .limit(20)
          .get();

      final results = <Map<String, dynamic>>[];
      for (final doc in nameSnap.docs) {
        if (doc.id == _currentUserId) continue;
        final data = doc.data();
        data['id'] = doc.id;
        results.add(data);
      }

      // Also search by username field
      final usernameSnap = await _db
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: lower)
          .where('username', isLessThanOrEqualTo: '$lower\uf8ff')
          .limit(10)
          .get();

      for (final doc in usernameSnap.docs) {
        if (doc.id == _currentUserId) continue;
        if (results.any((r) => r['id'] == doc.id)) continue;
        final data = doc.data();
        data['id'] = doc.id;
        results.add(data);
      }

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('❌ Search error: $e');
      setState(() => _isSearching = false);
    }
  }

  // ══════════════════════════════════════════════════════
  //  CONTACTS SYNC
  // ══════════════════════════════════════════════════════

  Future<void> _syncContacts() async {
    setState(() {
      _isLoadingContacts = true;
      _contactPermissionDenied = false;
    });

    // Request permission
    final status = await Permission.contacts.request();
    if (!status.isGranted) {
      setState(() {
        _isLoadingContacts = false;
        _contactPermissionDenied = true;
      });
      return;
    }

    try {
      // Fetch phone contacts
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      // Collect all phone numbers (normalized)
      final phoneNumbers = <String>[];
      for (final c in contacts) {
        for (final p in c.phones) {
          final normalized = p.number.replaceAll(RegExp(r'\D'), '');
          if (normalized.length >= 7) {
            phoneNumbers.add(normalized);
          }
        }
      }

      if (phoneNumbers.isEmpty) {
        setState(() {
          _isLoadingContacts = false;
          _contactsSynced = true;
        });
        return;
      }

      // Query Firestore for users with matching phone numbers
      // Firestore 'whereIn' allows max 30 items per query
      final matchedUsers = <Map<String, dynamic>>[];
      final matchedPhones = <String>{};

      for (int i = 0; i < phoneNumbers.length; i += 30) {
        final chunk = phoneNumbers.sublist(
          i,
          i + 30 > phoneNumbers.length ? phoneNumbers.length : i + 30,
        );
        final snap = await _db
            .collection('users')
            .where('phone_normalized', whereIn: chunk)
            .get();

        for (final doc in snap.docs) {
          if (doc.id == _currentUserId) continue;
          final data = doc.data();
          data['id'] = doc.id;
          matchedUsers.add(data);
          if (data['phone_normalized'] != null) {
            matchedPhones.add(data['phone_normalized'] as String);
          }
        }
      }

      // Contacts NOT in app → invite list
      final notInApp = <Contact>[];
      for (final c in contacts) {
        bool found = false;
        for (final p in c.phones) {
          final normalized = p.number.replaceAll(RegExp(r'\D'), '');
          if (matchedPhones.contains(normalized)) {
            found = true;
            break;
          }
        }
        if (!found && c.phones.isNotEmpty) {
          notInApp.add(c);
        }
      }

      setState(() {
        _matchedAppUsers = matchedUsers;
        _phoneContactsNotInApp = notInApp.take(50).toList();
        _isLoadingContacts = false;
        _contactsSynced = true;
      });

      debugPrint(
          '✅ Contacts synced: ${matchedUsers.length} in app, ${notInApp.length} to invite');
    } catch (e) {
      debugPrint('❌ Contacts sync error: $e');
      setState(() => _isLoadingContacts = false);
    }
  }

  // ══════════════════════════════════════════════════════
  //  SUGGESTED USERS
  // ══════════════════════════════════════════════════════

  Future<void> _loadSuggestedUsers() async {
    setState(() => _isLoadingSuggested = true);
    try {
      // Get users ordered by follower count (popularity based suggestion)
      final snap = await _db
          .collection('users')
          .orderBy('followerCount', descending: true)
          .limit(30)
          .get();

      final results = <Map<String, dynamic>>[];

      for (final doc in snap.docs) {
        if (doc.id == _currentUserId) continue;

        // Check if already following
        if (_currentUserId != null) {
          final followId = '${_currentUserId}_${doc.id}';
          final followDoc =
          await _db.collection('follows').doc(followId).get();
          if (followDoc.exists) continue;
        }

        final data = doc.data();
        data['id'] = doc.id;
        results.add(data);
        if (results.length >= 20) break;
      }

      setState(() {
        _suggestedUsers = results;
        _isLoadingSuggested = false;
      });
    } catch (e) {
      debugPrint('❌ Suggested users error: $e');
      setState(() => _isLoadingSuggested = false);
    }
  }

  // ══════════════════════════════════════════════════════
  //  FOLLOW
  // ══════════════════════════════════════════════════════

  Future<void> _followUser(String targetUserId, String targetUsername) async {
    if (_currentUserId == null || _currentUserId == targetUserId) return;

    try {
      final followDocId = '${_currentUserId}_$targetUserId';
      final followRef = _db.collection('follows').doc(followDocId);
      final followDoc = await followRef.get();

      if (followDoc.exists) {
        await followRef.delete();
        final status = followDoc.data()?['status'];
        if (status == 'active') {
          await _db.collection('users').doc(_currentUserId).update(
              {'followingCount': FieldValue.increment(-1)});
          await _db.collection('users').doc(targetUserId).update(
              {'followerCount': FieldValue.increment(-1)});
        }
        debugPrint('💔 Unfollowed: $targetUserId');
      } else {
        final targetDoc =
        await _db.collection('users').doc(targetUserId).get();
        final isPrivate = targetDoc.data()?['private_account'] ?? false;

        final currentUserDoc =
        await _db.collection('users').doc(_currentUserId).get();
        final currentUsername = currentUserDoc.data()?['name'] ?? 'User';

        await followRef.set({
          'followerId': _currentUserId,
          'followerName': currentUsername,
          'followingId': targetUserId,
          'followingName': targetUsername,
          'status': isPrivate ? 'pending' : 'active',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });

        if (!isPrivate) {
          await _db.collection('users').doc(_currentUserId).update(
              {'followingCount': FieldValue.increment(1)});
          await _db.collection('users').doc(targetUserId).update(
              {'followerCount': FieldValue.increment(1)});
        }
        debugPrint('✅ Followed: $targetUserId (private: $isPrivate)');
      }

      // Refresh lists
      setState(() {});
    } catch (e) {
      debugPrint('❌ Follow error: $e');
    }
  }

  // ══════════════════════════════════════════════════════
  //  INVITE
  // ══════════════════════════════════════════════════════

  void _inviteContact(Contact contact) {
    const appLink = 'https://myvibeflick.page.link/invite';
    final name = contact.displayName;
    Share.share(
      'Hey $name! Join me on MyVibeFlick 🎬🎶 $appLink',
      subject: 'Join MyVibeFlick!',
    );
  }

  // ══════════════════════════════════════════════════════
  //  NAVIGATE TO PROFILE
  // ══════════════════════════════════════════════════════

  void _openProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityUserProfile(userId: userId),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  WIDGETS
  // ══════════════════════════════════════════════════════

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search by name or username...',
          hintStyle:
          TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded,
              color: Colors.white.withOpacity(0.4), size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
            onTap: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _searchResults = [];
              });
            },
            child: Icon(Icons.close_rounded,
                color: Colors.white.withOpacity(0.4), size: 18),
          )
              : null,
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
      ),
    );
  }

  // ── User row (search results / matched contacts / suggested) ──
  Widget _buildUserRow(Map<String, dynamic> user,
      {bool showInvite = false, Contact? contactForInvite}) {
    final userId = user['id'] as String? ?? '';
    final name = user['name'] as String? ?? 'Unknown';
    final username = user['username'] as String? ?? '';
    final avatarUrl = user['profileImageUrl'] as String? ??
        user['profile_picture_url'] as String?;
    final followerCount = user['followerCount'] as int? ?? 0;

    return StreamBuilder<DocumentSnapshot>(
      stream: _currentUserId != null
          ? _db
          .collection('follows')
          .doc('${_currentUserId}_$userId')
          .snapshots()
          : null,
      builder: (context, snapshot) {
        bool isFollowing = false;
        bool isPending = false;

        if (snapshot.hasData && snapshot.data!.exists) {
          final status =
              (snapshot.data!.data() as Map?)? ['status'] ?? '';
          isFollowing = status == 'active';
          isPending = status == 'pending';
        }

        return GestureDetector(
          onTap: () => _openProfile(userId),
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Avatar
                _buildAvatar(name, avatarUrl),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (username.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '@$username',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.45),
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        '${_formatCount(followerCount)} followers',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Follow / Invite buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showInvite && contactForInvite != null)
                      _buildOutlineButton(
                        label: 'Invite',
                        icon: Icons.send_rounded,
                        color: const Color(0xFF4A9EFF),
                        onTap: () => _inviteContact(contactForInvite),
                      ),
                    if (showInvite && contactForInvite != null)
                      const SizedBox(width: 8),
                    _buildFollowChip(
                      isFollowing: isFollowing,
                      isPending: isPending,
                      onTap: () => _followUser(userId, name),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Contact row for phone contacts NOT in app ──────────
  Widget _buildInviteContactRow(Contact contact) {
    final name = contact.displayName;
    final phone = contact.phones.isNotEmpty
        ? contact.phones.first.number
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Avatar (initials only)
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    phone,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),

          _buildOutlineButton(
            label: 'Invite',
            icon: Icons.send_rounded,
            color: const Color(0xFF4A9EFF),
            onTap: () => _inviteContact(contact),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String name, String? avatarUrl) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ClipOval(
        child: avatarUrl != null && avatarUrl.isNotEmpty
            ? Image.network(
          avatarUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _avatarFallback(name),
        )
            : _avatarFallback(name),
      ),
    );
  }

  Widget _avatarFallback(String name) {
    return Container(
      color: const Color(0xFFFF3B5C),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildFollowChip({
    required bool isFollowing,
    required bool isPending,
    required VoidCallback onTap,
  }) {
    Color bg;
    String label;
    IconData icon;

    if (isFollowing) {
      bg = const Color(0xFF2C2C2C);
      label = 'Following';
      icon = Icons.check;
    } else if (isPending) {
      bg = const Color(0xFFFFA500);
      label = 'Requested';
      icon = Icons.access_time;
    } else {
      bg = const Color(0xFFFF3B5C);
      label = 'Follow';
      icon = Icons.person_add_rounded;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 13),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutlineButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section header ──────────────────────────────────────
  Widget _buildSectionHeader(String title, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  // ── Shimmer list ────────────────────────────────────────
  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 6,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey[900]!,
        highlightColor: Colors.grey[800]!,
        child: Padding(
          padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        height: 12,
                        width: 120,
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 6)),
                    Container(height: 10, width: 80, color: Colors.white),
                  ],
                ),
              ),
              Container(
                width: 72,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Empty state ─────────────────────────────────────────
  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withOpacity(0.08), width: 1.5),
            ),
            child: Icon(icon, size: 36, color: Colors.white30),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4), fontSize: 13)),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  // ══════════════════════════════════════════════════════
  //  CONTACTS TAB BODY
  // ══════════════════════════════════════════════════════

  Widget _buildContactsBody() {
    if (_isLoadingContacts) return _buildShimmer();

    if (_contactPermissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.contacts_outlined,
                  size: 64, color: Colors.white30),
              const SizedBox(height: 16),
              const Text(
                'Contacts Permission Denied',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Please allow contacts access in your phone settings to find friends.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.45), fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: openAppSettings,
                icon: const Icon(Icons.settings_rounded, size: 16),
                label: const Text('Open Settings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3B5C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_contactsSynced) {
      // Show sync prompt
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF3B5C), Color(0xFFFF6B35)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF3B5C).withOpacity(0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: const Icon(Icons.contacts_rounded,
                    size: 42, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text(
                'Find Friends from Contacts',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Sync your phone contacts to find people you know who are already on MyVibeFlick.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _syncContacts,
                  icon: const Icon(Icons.sync_rounded, size: 18),
                  label: const Text(
                    'Sync Contacts',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3B5C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Synced - show results
    final hasMatched = _matchedAppUsers.isNotEmpty;
    final hasInvite = _phoneContactsNotInApp.isNotEmpty;

    if (!hasMatched && !hasInvite) {
      return _buildEmptyState(
        'No Contacts Found',
        'None of your contacts are on MyVibeFlick yet.\nInvite them to join!',
        Icons.person_search_rounded,
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // ── In-app contacts ───────────────────────────────
        if (hasMatched) ...[
          _buildSectionHeader(
            '${_matchedAppUsers.length} Contacts on MyVibeFlick',
            trailing: GestureDetector(
              onTap: _syncContacts,
              child: Text('Refresh',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12)),
            ),
          ),
          const Divider(color: Color(0xFF222222), height: 1),
          ...(_matchedAppUsers
              .map((u) => _buildUserRow(u))
              .toList()),
        ],

        // ── Invite contacts ───────────────────────────────
        if (hasInvite) ...[
          _buildSectionHeader(
              '${_phoneContactsNotInApp.length} Contacts to Invite'),
          const Divider(color: Color(0xFF222222), height: 1),
          ...(_phoneContactsNotInApp
              .map((c) => _buildInviteContactRow(c))
              .toList()),
        ],
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  //  SUGGESTED TAB BODY
  // ══════════════════════════════════════════════════════

  Widget _buildSuggestedBody() {
    if (_isLoadingSuggested) return _buildShimmer();

    if (_suggestedUsers.isEmpty) {
      return _buildEmptyState(
        'No Suggestions',
        'Check back later for account suggestions.',
        Icons.people_outline_rounded,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSuggestedUsers,
      backgroundColor: const Color(0xFF1E1E1E),
      color: const Color(0xFFFF3B5C),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _buildSectionHeader(
            'People You May Know',
            trailing: GestureDetector(
              onTap: _loadSuggestedUsers,
              child: Text('Refresh',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12)),
            ),
          ),
          const Divider(color: Color(0xFF222222), height: 1),
          ..._suggestedUsers.map((u) => _buildUserRow(u)).toList(),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  SEARCH RESULTS
  // ══════════════════════════════════════════════════════

  Widget _buildSearchResults() {
    if (_isSearching) return _buildShimmer();

    if (_searchResults.isEmpty) {
      return _buildEmptyState(
        'No Results',
        'Try a different name or username.',
        Icons.search_off_rounded,
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _buildSectionHeader('${_searchResults.length} Results'),
        const Divider(color: Color(0xFF222222), height: 1),
        ..._searchResults.map((u) => _buildUserRow(u)).toList(),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Column(
        children: [
          // ── Search bar ────────────────────────────────
          _buildSearchBar(),

          // ── Inner tabs (only when not searching) ──────
          if (_searchQuery.isEmpty) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              decoration: BoxDecoration(
                color: const Color(0xFF242424),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: TabBar(
                controller: _innerTabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white38,
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w400),
                indicator: BoxDecoration(
                  color: const Color(0xFFFF3B5C),
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                splashFactory: NoSplash.splashFactory,
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.contacts_rounded, size: 15),
                        SizedBox(width: 6),
                        Text('Contacts'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_rounded, size: 15),
                        SizedBox(width: 6),
                        Text('Suggested'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],

          // ── Body ──────────────────────────────────────
          Expanded(
            child: _searchQuery.isNotEmpty
                ? _buildSearchResults()
                : TabBarView(
              controller: _innerTabController,
              children: [
                _buildContactsBody(),
                _buildSuggestedBody(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}