import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'select_posts_page.dart';

/// 📂 Collection Detail Page (Image 3)
class CollectionDetailPage extends StatefulWidget {
  final String collectionId;
  final String collectionName;
  final bool isPublic;
  final FirebaseFirestore db;
  final FirebaseAuth auth;

  const CollectionDetailPage({
    super.key,
    required this.collectionId,
    required this.collectionName,
    required this.isPublic,
    required this.db,
    required this.auth,
  });

  @override
  State<CollectionDetailPage> createState() => _CollectionDetailPageState();
}

class _CollectionDetailPageState extends State<CollectionDetailPage> {
  late String _name;
  late bool _isPublic;

  @override
  void initState() {
    super.initState();
    _name = widget.collectionName;
    _isPublic = widget.isPublic;
  }

  Stream<QuerySnapshot> get _itemsStream {
    final user = widget.auth.currentUser;
    if (user == null) return const Stream.empty();
    return widget.db
        .collection('users')
        .doc(user.uid)
        .collection('collections')
        .doc(widget.collectionId)
        .collection('items')
        .orderBy('added_at', descending: true)
        .snapshots();
  }

  void _openManageSheet(int postCount) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ManageCollectionSheet(
        collectionId: widget.collectionId,
        currentName: _name,
        isPublic: _isPublic,
        postCount: postCount,
        onNameChanged: (n) => setState(() => _name = n),
        onVisibilityChanged: (p) => setState(() => _isPublic = p),
        onDeleted: () => Navigator.pop(context),
        onAddPosts: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SelectPostsPage(
              collectionId: widget.collectionId,
              collectionName: _name,
              db: widget.db,
              auth: widget.auth,
              mode: SelectPostsMode.addToCollection,
            ),
          ),
        ),
        onSelectPosts: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SelectPostsPage(
              collectionId: widget.collectionId,
              collectionName: _name,
              db: widget.db,
              auth: widget.auth,
              mode: SelectPostsMode.removeFromCollection,
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(dynamic n) {
    final v = (n as num?)?.toDouble() ?? 0;
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toInt().toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: StreamBuilder<QuerySnapshot>(
        stream: _itemsStream,
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          final postCount = docs.length;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: const Color(0xFF121212),
                elevation: 0,
                pinned: true,
                systemOverlayStyle: SystemUiOverlayStyle.light,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: Colors.white, size: 24),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share_outlined,
                        color: Colors.white, size: 24),
                    onPressed: () => HapticFeedback.lightImpact(),
                  ),
                ],
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$postCount post${postCount == 1 ? '' : 's'}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => _openManageSheet(postCount),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 9),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C2C2E),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Manage',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (snapshot.connectionState == ConnectionState.waiting)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFFF3B5C), strokeWidth: 2),
                  ),
                )
              else if (docs.isEmpty)
                SliverFillRemaining(
                  child: _EmptyDetailState(
                    onAddTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SelectPostsPage(
                          collectionId: widget.collectionId,
                          collectionName: _name,
                          db: widget.db,
                          auth: widget.auth,
                          mode: SelectPostsMode.addToCollection,
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                          (context, i) {
                        final data =
                        docs[i].data() as Map<String, dynamic>;
                        final thumb =
                            data['thumbnail_url'] as String? ?? '';
                        final viewCount = data['view_count'];
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            thumb.isNotEmpty
                                ? Image.network(thumb,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _ThumbPlaceholder(index: i))
                                : _ThumbPlaceholder(index: i),
                            if (viewCount != null)
                              Positioned(
                                bottom: 6,
                                left: 6,
                                child: Row(
                                  children: [
                                    const Icon(Icons.play_arrow,
                                        color: Colors.white, size: 13),
                                    const SizedBox(width: 2),
                                    Text(
                                      _fmt(viewCount),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        shadows: [
                                          Shadow(
                                              blurRadius: 4,
                                              color: Colors.black54)
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                      childCount: docs.length,
                    ),
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                      childAspectRatio: 9 / 16,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Manage Collection Bottom Sheet (Image 2) — 5 actions
// ─────────────────────────────────────────────────────────────
class _ManageCollectionSheet extends StatelessWidget {
  final String collectionId;
  final String currentName;
  final bool isPublic;
  final int postCount;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<bool> onVisibilityChanged;
  final VoidCallback onDeleted;
  final VoidCallback onAddPosts;
  final VoidCallback onSelectPosts;

  const _ManageCollectionSheet({
    required this.collectionId,
    required this.currentName,
    required this.isPublic,
    required this.postCount,
    required this.onNameChanged,
    required this.onVisibilityChanged,
    required this.onDeleted,
    required this.onAddPosts,
    required this.onSelectPosts,
  });

  Future<void> _changeName(BuildContext ctx) async {
    // ❌ Navigator.pop(ctx) කලින් දාන්නේ නැ
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Change name',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF2C2C2E),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF888888))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B5C),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child:
            const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      // Dialog close වුනාට පස්සේ sheet close කරනවා
      if (ctx.mounted) Navigator.pop(ctx);
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('collections')
            .doc(collectionId)
            .update({'name': newName});
        onNameChanged(newName);
        HapticFeedback.mediumImpact();
      } catch (e) {
        debugPrint('❌ Rename error: $e');
      }
    }
  }

  Future<void> _toggleVisibility(BuildContext ctx) async {
    // Sheet close කරනවා — මේකෙ dialog නැති නිසා කලින් pop කළත් OK
    // හැබැයි mounted check කරනවා
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final newVal = !isPublic;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('collections')
          .doc(collectionId)
          .update({'is_public': newVal});
      onVisibilityChanged(newVal);
      HapticFeedback.mediumImpact();
      if (ctx.mounted) Navigator.pop(ctx);
    } catch (e) {
      debugPrint('❌ Visibility error: $e');
    }
  }

  Future<void> _deleteCollection(BuildContext ctx) async {
    // ❌ Navigator.pop(ctx) කලින් දාන්නේ නැ
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete collection?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          'Permanently delete "$currentName"? '
              '${postCount > 0 ? '$postCount post${postCount == 1 ? '' : 's'} will be removed from it.' : ''}',
          style: const TextStyle(
              color: Color(0xFF888888), fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF888888))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child:
            const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Confirm වුනාට පස්සේ sheet close කරනවා
    if (ctx.mounted) Navigator.pop(ctx);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final colRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('collections')
          .doc(collectionId);

      final itemsSnap = await colRef.collection('items').get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in itemsSnap.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(colRef);
      await batch.commit();
      HapticFeedback.mediumImpact();
      onDeleted();
    } catch (e) {
      debugPrint('❌ Delete error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 14),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const Text(
              'Manage collection',
              style: TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF2C2C2C), height: 1),

            _SheetTile(
              icon: Icons.add,
              label: 'Add posts',
              onTap: () {
                Navigator.pop(context);
                onAddPosts();
              },
            ),
            const Divider(
                color: Color(0xFF2C2C2C), height: 1, indent: 56),

            _SheetTile(
              icon: Icons.check_box_outline_blank,
              label: 'Select posts',
              onTap: () {
                Navigator.pop(context);
                onSelectPosts();
              },
            ),
            const Divider(
                color: Color(0xFF2C2C2C), height: 1, indent: 56),

            _SheetTile(
              icon: Icons.edit_outlined,
              label: 'Change name',
              onTap: () => _changeName(context),
            ),
            const Divider(
                color: Color(0xFF2C2C2C), height: 1, indent: 56),

            _SheetTile(
              icon: isPublic
                  ? Icons.lock_outline
                  : Icons.lock_open_outlined,
              label: isPublic ? 'Make private' : 'Make public',
              onTap: () => _toggleVisibility(context),
            ),
            const Divider(
                color: Color(0xFF2C2C2C), height: 1, indent: 56),

            _SheetTile(
              icon: Icons.delete_outline,
              label: 'Delete collection',
              isDestructive: true,
              onTap: () => _deleteCollection(context),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────
class _SheetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SheetTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
    isDestructive ? const Color(0xFFFF3B5C) : Colors.white;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _EmptyDetailState extends StatelessWidget {
  final VoidCallback onAddTap;
  const _EmptyDetailState({required this.onAddTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_box_outlined,
              color: Colors.white.withOpacity(0.3), size: 56),
          const SizedBox(height: 14),
          const Text('No posts yet',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Add your saved posts\nto this collection.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 14,
                  height: 1.5)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onAddTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                  color: const Color(0xFFFF3B5C),
                  borderRadius: BorderRadius.circular(20)),
              child: const Text('Add posts',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThumbPlaceholder extends StatelessWidget {
  final int index;
  const _ThumbPlaceholder({required this.index});
  static const _c = [
    Color(0xFF2C2C2E),
    Color(0xFF3A3A3C),
    Color(0xFF252525)
  ];

  @override
  Widget build(BuildContext context) => Container(
    color: _c[index % _c.length],
    child: Icon(Icons.play_circle_outline,
        color: Colors.white.withOpacity(0.2), size: 28),
  );
}