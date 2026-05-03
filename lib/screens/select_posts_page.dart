import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ══════════════════════════════════════════════════════════════════════════════
// 🖼️ SelectPostsPage — Image 6
// mode: addToCollection  → saved_posts stream
// mode: removeFromCollection → collection items stream
// ══════════════════════════════════════════════════════════════════════════════

enum SelectPostsMode { addToCollection, removeFromCollection }

class SelectPostsPage extends StatefulWidget {
  final String collectionId;
  final String collectionName;
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  final SelectPostsMode mode;

  const SelectPostsPage({
    super.key,
    required this.collectionId,
    required this.collectionName,
    required this.db,
    required this.auth,
    required this.mode,
  });

  @override
  State<SelectPostsPage> createState() => _SelectPostsPageState();
}

class _SelectPostsPageState extends State<SelectPostsPage> {
  final Set<String> _selectedIds = {};
  bool _isProcessing = false;

  bool get _isRemoveMode => widget.mode == SelectPostsMode.removeFromCollection;

  Stream<QuerySnapshot> get _savedPostsStream {
    final user = widget.auth.currentUser;
    if (user == null) return const Stream.empty();
    return widget.db
        .collection('users')
        .doc(user.uid)
        .collection('saved_posts')
        .orderBy('saved_at', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> get _collectionItemsStream {
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

  Stream<QuerySnapshot> get _activeStream =>
      _isRemoveMode ? _collectionItemsStream : _savedPostsStream;

  Future<void> _addPosts(List<QueryDocumentSnapshot> allDocs) async {
    if (_selectedIds.isEmpty) return;
    setState(() => _isProcessing = true);

    try {
      final user = widget.auth.currentUser;
      if (user == null) return;

      final colRef = widget.db
          .collection('users')
          .doc(user.uid)
          .collection('collections')
          .doc(widget.collectionId);

      final batch = widget.db.batch();
      String? thumbnailUrl;

      for (final postId in _selectedIds) {
        final doc = allDocs.firstWhere((d) => d.id == postId);
        final data = doc.data() as Map<String, dynamic>;
        thumbnailUrl ??= data['thumbnail_url'] as String?;
        batch.set(colRef.collection('items').doc(postId), {
          ...data,
          'added_at': FieldValue.serverTimestamp(),
        });
      }

      batch.update(colRef, {
        'post_count': FieldValue.increment(_selectedIds.length),
        if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
          'thumbnail_url': thumbnailUrl,
      });

      await batch.commit();
      HapticFeedback.mediumImpact();

      if (mounted) {
        _showSnackbar(
          '${_selectedIds.length} post${_selectedIds.length > 1 ? 's' : ''} added to "${widget.collectionName}"',
          isSuccess: true,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Add posts error: $e');
      setState(() => _isProcessing = false);
      if (mounted) _showSnackbar('Failed to add posts', isSuccess: false);
    }
  }

  Future<void> _removePosts() async {
    if (_selectedIds.isEmpty) return;
    setState(() => _isProcessing = true);

    try {
      final user = widget.auth.currentUser;
      if (user == null) return;

      final colRef = widget.db
          .collection('users')
          .doc(user.uid)
          .collection('collections')
          .doc(widget.collectionId);

      final batch = widget.db.batch();
      for (final postId in _selectedIds) {
        batch.delete(colRef.collection('items').doc(postId));
      }
      batch.update(colRef, {
        'post_count': FieldValue.increment(-_selectedIds.length),
      });
      await batch.commit();

      HapticFeedback.mediumImpact();
      if (mounted) {
        _showSnackbar(
          '${_selectedIds.length} post${_selectedIds.length > 1 ? 's' : ''} removed',
          isSuccess: true,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Remove posts error: $e');
      setState(() => _isProcessing = false);
      if (mounted) _showSnackbar('Failed to remove posts', isSuccess: false);
    }
  }

  void _showSnackbar(String msg, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isSuccess ? Icons.check_circle : Icons.error_outline,
            color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: isSuccess ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Select posts',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _activeStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF3B5C), strokeWidth: 2),
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
                    Icon(Icons.bookmark_border, color: Colors.white.withOpacity(0.3), size: 60),
                    const SizedBox(height: 16),
                    Text(
                      _isRemoveMode ? 'No posts in this collection' : 'No saved posts yet',
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isRemoveMode
                          ? 'Add posts to manage them here'
                          : 'Save posts to add them to collections',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14, height: 1.5),
                    ),
                  ],
                ),
              ),
            );
          }

          return Stack(
            children: [
              GridView.builder(
                padding: const EdgeInsets.only(bottom: 110),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                  childAspectRatio: 9 / 16,
                ),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final postId = doc.id;
                  final isSelected = _selectedIds.contains(postId);
                  final thumbnailUrl = data['thumbnail_url'] as String? ?? '';
                  final viewCount = data['view_count'] ?? 0;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        isSelected ? _selectedIds.remove(postId) : _selectedIds.add(postId);
                      });
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        thumbnailUrl.isNotEmpty
                            ? Image.network(thumbnailUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _ThumbPlaceholder(index: index))
                            : _ThumbPlaceholder(index: index),

                        if (isSelected) Container(color: Colors.black.withOpacity(0.4)),

                        Positioned(
                          bottom: 6,
                          left: 6,
                          child: Row(
                            children: [
                              const Icon(Icons.play_arrow, color: Colors.white, size: 13),
                              const SizedBox(width: 2),
                              Text(
                                _formatCount(viewCount),
                                style: const TextStyle(
                                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600,
                                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                                ),
                              ),
                            ],
                          ),
                        ),

                        Positioned(
                          top: 8,
                          right: 8,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? const Color(0xFFFF3B5C) : Colors.transparent,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.white, size: 14)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Bottom button
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF121212).withOpacity(0.95),
                        const Color(0xFF121212),
                      ],
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (_selectedIds.isEmpty || _isProcessing)
                          ? null
                          : () => _isRemoveMode
                          ? _removePosts()
                          : _addPosts(docs),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isRemoveMode
                            ? const Color(0xFFE53935)
                            : const Color(0xFFFF3B5C),
                        disabledBackgroundColor: const Color(0xFF3A1520),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        elevation: 0,
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : Text(
                        _isRemoveMode
                            ? (_selectedIds.isEmpty ? 'Remove posts (0)' : 'Remove posts (${_selectedIds.length})')
                            : (_selectedIds.isEmpty ? 'Add posts (0)' : 'Add posts (${_selectedIds.length})'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ],
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

class _ThumbPlaceholder extends StatelessWidget {
  final int index;
  const _ThumbPlaceholder({required this.index});

  @override
  Widget build(BuildContext context) {
    const colors = [Color(0xFF2C2C2E), Color(0xFF3A3A3C), Color(0xFF252525)];
    return Container(
      color: colors[index % colors.length],
      child: Icon(Icons.play_circle_outline, color: Colors.white.withOpacity(0.15), size: 28),
    );
  }
}