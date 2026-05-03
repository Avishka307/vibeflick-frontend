import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_vibe_flick/screens/post_detail_page.dart';
import 'collection_detail_page.dart';

// ══════════════════════════════════════════════════════════════════════════════
// 📁 TabSaved — Collections grid (Image 1 empty | Image 4 with collections)
// ══════════════════════════════════════════════════════════════════════════════

class TabSaved extends StatelessWidget {
  final FirebaseFirestore? db;
  final FirebaseAuth? auth;
  final VoidCallback? onCreateCollection;

  const TabSaved({
    super.key,
    this.db,
    this.auth,
    this.onCreateCollection,
  });

  FirebaseFirestore get _db => db ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => auth ?? FirebaseAuth.instance;
  VoidCallback get _onCreateCollection => onCreateCollection ?? () {};

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) return const _EmptyCollectionsState(showCreateButton: false);

    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('users')
          .doc(user.uid)
          .collection('collections')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF3B5C), strokeWidth: 2),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _EmptyCollectionsState(
            showCreateButton: true,
            onCreateTap: _onCreateCollection,
          );
        }
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _CreateCollectionRow(onTap: _onCreateCollection),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.85,
                ),
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    if (index == 0) {
                      return _PostsCard(db: _db, auth: _auth);
                    }
                    final doc = docs[index - 1];
                    final data = doc.data() as Map<String, dynamic>;
                    return _CollectionCard(
                      collectionId: doc.id,
                      name: data['name'] as String? ?? 'Collection',
                      postCount: (data['post_count'] as num?)?.toInt() ?? 0,
                      isPublic: data['is_public'] as bool? ?? false,
                      thumbnailUrl: data['thumbnail_url'] as String? ?? '',
                      db: _db,
                      auth: _auth,
                    );
                  },
                  childCount: docs.length + 1,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── "Posts" fixed card — bookmark කරන සියලු posts ──
class _PostsCard extends StatelessWidget {
  final FirebaseFirestore db;
  final FirebaseAuth auth;

  const _PostsCard({required this.db, required this.auth});

  @override
  Widget build(BuildContext context) {
    final user = auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('users')
          .doc(user.uid)
          .collection('saved_posts')
          .orderBy('saved_at', descending: true)
          .limit(1) // thumbnail සඳහා first doc විතරක්
          .snapshots(),
      builder: (context, snapshot) {
        // Total count stream
        // AFTER:
        return StreamBuilder<QuerySnapshot>(
          stream: db
              .collection('users')
              .doc(user.uid)
              .collection('saved_posts')
              .snapshots(),
          builder: (context, countSnapshot) {
            final postCount = countSnapshot.data?.docs.length ?? 0;
            final firstDoc = snapshot.data?.docs.firstOrNull;
            final thumbnailUrl = firstDoc != null
                ? (firstDoc.data() as Map<String, dynamic>)['thumbnail_url'] as String? ?? ''
                : '';

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _AllSavedPostsPage(
                      db: db,
                      auth: auth,
                    ),
                  ),
                );
              },
              child: SizedBox(
                height: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Thumbnail හෝ placeholder
                      thumbnailUrl.isNotEmpty
                          ? Image.network(
                        thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFF2C2C2E),
                        ),
                      )
                          : Container(color: const Color(0xFF2C2C2E)),

                      // Gradient
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.75),
                              ],
                              stops: const [0.3, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // Bookmark icon top-left
                      const Positioned(
                        top: 10,
                        left: 10,
                        child: Icon(Icons.bookmark, color: Colors.white, size: 20),
                      ),

                      // Name + count bottom
                      Positioned(
                        bottom: 10,
                        left: 10,
                        right: 10,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Posts',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                              ),
                            ),
                            if (postCount > 0)
                              Text(
                                '$postCount post${postCount != 1 ? 's' : ''}',
                                style: const TextStyle(
                                  color: Color(0xFFCCCCCC),
                                  fontSize: 12,
                                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── All Saved Posts Page ──
class _AllSavedPostsPage extends StatelessWidget {
  final FirebaseFirestore db;
  final FirebaseAuth auth;

  const _AllSavedPostsPage({required this.db, required this.auth});

  @override
  Widget build(BuildContext context) {
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Posts',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: user == null
          ? const Center(
        child: Text('Not logged in', style: TextStyle(color: Colors.white)),
      )
          : StreamBuilder<QuerySnapshot>(
        stream: db
            .collection('users')
            .doc(user.uid)
            .collection('saved_posts')
            .orderBy('saved_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF3B5C),
                strokeWidth: 2,
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bookmark_border,
                      color: Colors.white.withOpacity(0.3),
                      size: 60,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No saved posts yet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bookmark posts to save them here',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
              childAspectRatio: 0.75,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              // saved_posts doc ID == postId
              final postId = (data['postId'] as String?)?.isNotEmpty == true
                  ? data['postId'] as String
                  : doc.id;
              final thumbnailUrl = (data['thumbnail_url'] as String?) ?? '';
              final viewCount = (data['view_count'] as num?)?.toInt()
                  ?? (data['viewCount'] as num?)?.toInt()
                  ?? 0;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PostDetailPage(
                        postId: postId,
                      ),
                    ),
                  );
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    thumbnailUrl.isNotEmpty
                        ? Image.network(
                      thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF2C2C2E),
                        child: Icon(
                          Icons.play_circle_outline,
                          color: Colors.white.withOpacity(0.15),
                          size: 28,
                        ),
                      ),
                    )
                        : Container(
                      color: const Color(0xFF2C2C2E),
                      child: Icon(
                        Icons.play_circle_outline,
                        color: Colors.white.withOpacity(0.15),
                        size: 28,
                      ),
                    ),
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Row(
                        children: [
                          const Icon(Icons.play_arrow,
                              color: Colors.white, size: 13),
                          const SizedBox(width: 2),
                          Text(
                            _formatCount(viewCount),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(blurRadius: 4, color: Colors.black54)
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatCount(dynamic count) {
    final n = (count as num?)?.toDouble() ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toInt().toString();
  }
}

// ── Empty state — Image 1 ──
class _EmptyCollectionsState extends StatelessWidget {
  final bool showCreateButton;
  final VoidCallback? onCreateTap;

  const _EmptyCollectionsState({required this.showCreateButton, this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your collections',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text(
              'Create a new collection with your favourite videos. Your collections will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF999999), fontSize: 14, height: 1.5),
            ),
            if (showCreateButton) ...[
              const SizedBox(height: 28),
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onCreateTap?.call();
                },
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: Colors.white, size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Create collection',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── "Create new collection" row at top when collections exist — Image 4 ──
class _CreateCollectionRow extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateCollectionRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          children: [
            const Icon(Icons.add, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            const Text(
              'Create new collection',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Color(0xFF777777), size: 22),
          ],
        ),
      ),
    );
  }
}

// ── Single collection card — Image 4 ──
class _CollectionCard extends StatelessWidget {
  final String collectionId;
  final String name;
  final int postCount;
  final bool isPublic;
  final String thumbnailUrl;
  final FirebaseFirestore db;
  final FirebaseAuth auth;

  const _CollectionCard({
    required this.collectionId,
    required this.name,
    required this.postCount,
    required this.isPublic,
    required this.thumbnailUrl,
    required this.db,
    required this.auth,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CollectionDetailPage(
              collectionId: collectionId,
              collectionName: name,
              isPublic: isPublic,
              db: db,
              auth: auth,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail or placeholder
            thumbnailUrl.isNotEmpty
                ? Image.network(thumbnailUrl, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _Placeholder(name: name))
                : _Placeholder(name: name),

            // Gradient overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
            ),

            // Bookmark icon top-left
            const Positioned(
              top: 10,
              left: 10,
              child: Icon(Icons.bookmark, color: Colors.white, size: 20),
            ),

            // Lock icon top-right if private
            if (!isPublic)
              const Positioned(
                top: 10,
                right: 10,
                child: Icon(Icons.lock, color: Colors.white, size: 16),
              ),

            // Name bottom
            Positioned(
              bottom: 10,
              left: 10,
              right: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                    ),
                  ),
                  if (postCount > 0)
                    Text(
                      '$postCount post${postCount != 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: Color(0xFFCCCCCC),
                        fontSize: 12,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String name;
  const _Placeholder({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF2C2C2E),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(color: Color(0xFF555555), fontSize: 40, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}