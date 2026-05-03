import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/select_posts_page.dart';
import '../screens/tab_likes.dart';
import '../screens/tab_saved.dart';
import '../screens/tab_sounds.dart';


/// 📱 Main Saved Page — TabBar container
/// Tab 0: Likes  |  Tab 1: Saved (Collections)  |  Tab 2: Sounds
class TabSavedPage extends StatefulWidget {
  const TabSavedPage({super.key});

  @override
  State<TabSavedPage> createState() => _TabSavedPageState();
}

class _TabSavedPageState extends State<TabSavedPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _activeTab = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleCreateCollection() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _CreateCollectionSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Column(
        children: [
          _buildTopBar(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const TabLikes(),
                TabSaved(
                  db: FirebaseFirestore.instance,
                  auth: FirebaseAuth.instance,
                  onCreateCollection: _handleCreateCollection,
                ),
                const TabSounds(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        border: Border(
          bottom: BorderSide(color: Color(0xFF2C2C2C), width: 0.5),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Text(
              'Saved',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => HapticFeedback.lightImpact(),
              icon: const Icon(Icons.search, color: Colors.white, size: 26),
            ),
            IconButton(
              onPressed: () => HapticFeedback.lightImpact(),
              icon: const Icon(Icons.more_horiz,
                  color: Colors.white, size: 26),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    const tabs = ['Likes', 'Saved', 'Sounds'];

    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        border: Border(
          bottom: BorderSide(color: Color(0xFF2C2C2C), width: 0.5),
        ),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final active = _activeTab == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                _tabController.animateTo(index);
              },
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    tabs[index],
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                      active ? FontWeight.w700 : FontWeight.w400,
                      color: active
                          ? Colors.white
                          : const Color(0xFF777777),
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 2,
                    width: active ? 36 : 0,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 🆕 Create Collection Sheet — Image 1
// X close | "Create new collection" title
// Name text field card
// Share with a friend row (chevron) + Make public toggle card
// Next button (disabled until name typed, red when active)
// ══════════════════════════════════════════════════════════════════════════════

class _CreateCollectionSheet extends StatefulWidget {
  const _CreateCollectionSheet();

  @override
  State<_CreateCollectionSheet> createState() =>
      _CreateCollectionSheetState();
}

class _CreateCollectionSheetState extends State<_CreateCollectionSheet> {
  final TextEditingController _nameController = TextEditingController();
  bool _isPublic = false;
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canProceed => _nameController.text.trim().isNotEmpty;

  Future<void> _onNext() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _isCreating) return;

    setState(() => _isCreating = true);
    HapticFeedback.mediumImpact();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isCreating = false);
        return;
      }

      // Create the collection document in Firestore
      final colRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('collections')
          .add({
        'name': name,
        'is_public': _isPublic,
        'post_count': 0,
        'thumbnail_url': '',
        'created_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // Close the sheet first
      Navigator.pop(context);

      // Navigate to Select Posts so user can add posts immediately (Image 2)
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SelectPostsPage(
            collectionId: colRef.id,
            collectionName: name,
            db: FirebaseFirestore.instance,
            auth: FirebaseAuth.instance,
            mode: SelectPostsMode.addToCollection,
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Create collection error: $e');
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(0, 0, 0, bottomInset),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Create new collection',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // ── Name card ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Name',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      autofocus: true,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15),
                      cursorColor: const Color(0xFFFF3B5C),
                      decoration: const InputDecoration(
                        hintText: 'Enter collection name',
                        hintStyle: TextStyle(
                            color: Color(0xFF666666), fontSize: 15),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ── Share with a friend + Make public card ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // Share with a friend
                    InkWell(
                      onTap: () => HapticFeedback.selectionClick(),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: const [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Share with a friend',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'They will be able to add their favourite posts.',
                                    style: TextStyle(
                                      color: Color(0xFF888888),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                color: Color(0xFF888888), size: 22),
                          ],
                        ),
                      ),
                    ),

                    const Divider(
                        color: Color(0xFF3A3A3C), height: 1, indent: 16),

                    // Make public
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Make public',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'The collection will be shown on your profile.',
                                  style: TextStyle(
                                    color: Color(0xFF888888),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isPublic,
                            onChanged: (val) {
                              HapticFeedback.selectionClick();
                              setState(() => _isPublic = val);
                            },
                            activeColor: Colors.white,
                            activeTrackColor: const Color(0xFFFF3B5C),
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: const Color(0xFF555555),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Next button ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_canProceed && !_isCreating) ? _onNext : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3B5C),
                    disabledBackgroundColor: const Color(0xFF4A1520),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                    elevation: 0,
                  ),
                  child: _isCreating
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                      : const Text(
                    'Next',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}