import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Dialog එක වීඩියෝ එකක් සේව් කරන විට පෙන්වන්න
/// යූසර්ට පුළුවන් collection එකක් තෝරන්න හෝ "Just Save" කරන්න
class AddToCollectionDialog {
  static Future<String?> show(BuildContext context) async {
    final FirebaseAuth auth = FirebaseAuth.instance;
    final FirebaseFirestore db = FirebaseFirestore.instance;
    final currentUser = auth.currentUser;

    if (currentUser == null) return null;

    // Load user's collections
    List<Map<String, dynamic>> collections = [];
    try {
      final snapshot = await db
          .collection('users')
          .doc(currentUser.uid)
          .collection('collections')
          .orderBy('created_at', descending: true)
          .get();

      collections = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Untitled',
          'item_count': data['item_count'] ?? 0,
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Error loading collections: $e');
    }

    return showDialog<String?>(
      context: context,
      builder: (context) => _AddToCollectionDialogContent(
        collections: collections,
        userId: currentUser.uid,
      ),
    );
  }
}

class _AddToCollectionDialogContent extends StatefulWidget {
  final List<Map<String, dynamic>> collections;
  final String userId;

  const _AddToCollectionDialogContent({
    required this.collections,
    required this.userId,
  });

  @override
  State<_AddToCollectionDialogContent> createState() =>
      _AddToCollectionDialogContentState();
}

class _AddToCollectionDialogContentState
    extends State<_AddToCollectionDialogContent> {
  String? _selectedCollectionId;
  bool _isCreatingNew = false;
  final TextEditingController _newCollectionController = TextEditingController();

  @override
  void dispose() {
    _newCollectionController.dispose();
    super.dispose();
  }

  Future<void> _createNewCollection() async {
    final name = _newCollectionController.text.trim();
    if (name.isEmpty) return;

    try {
      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('collections')
          .add({
        'name': name,
        'item_count': 0,
        'created_at': FieldValue.serverTimestamp(),
      });

      // Return the new collection ID
      Navigator.pop(context, docRef.id);
    } catch (e) {
      debugPrint('❌ Error creating collection: $e');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Add to a collection?',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isCreatingNew) ...[
              // Create new collection input
              TextField(
                controller: _newCollectionController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Collection name (e.g., Gym Music)',
                  hintStyle: const TextStyle(color: Color(0xFF888888)),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _isCreatingNew = false;
                          _newCollectionController.clear();
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF888888),
                        side: const BorderSide(color: Color(0xFF444444)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _createNewCollection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Create',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // List of existing collections
              if (widget.collections.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'තාම collections නෑ\nපහළින් "Create New" ඔබලා හදාගන්න',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF888888), fontSize: 14),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.collections.length,
                    itemBuilder: (context, index) {
                      final collection = widget.collections[index];
                      final isSelected =
                          _selectedCollectionId == collection['id'];

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCollectionId = collection['id'];
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFE53935).withOpacity(0.2)
                                : const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFE53935)
                                  : const Color(0xFF3A3A3A),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.folder,
                                color: isSelected
                                    ? const Color(0xFFE53935)
                                    : const Color(0xFF888888),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      collection['name'],
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xCCCCCCCC),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${collection['item_count']} items',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF888888),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFFE53935),
                                  size: 22,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              // Create New Collection button
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _isCreatingNew = true;
                  });
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create New Collection'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE53935),
                  side: const BorderSide(color: Color(0xFFE53935)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!_isCreatingNew) ...[
          TextButton(
            onPressed: () => Navigator.pop(context), // null = just save without collection
            child: const Text(
              'Just Save',
              style: TextStyle(color: Color(0xFF888888)),
            ),
          ),
          ElevatedButton(
            onPressed: _selectedCollectionId != null
                ? () => Navigator.pop(context, _selectedCollectionId)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              disabledBackgroundColor: const Color(0xFF444444),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Add to Collection',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ],
    );
  }
}

/// Example usage when saving a video/sound/effect:
///
/// ```dart
/// // When user taps "Save" button on a video
/// final collectionId = await AddToCollectionDialog.show(context);
///
/// // Save the item to Firestore
/// await FirebaseFirestore.instance
///     .collection('users')
///     .doc(currentUserId)
///     .collection('saved_items')
///     .add({
///   'title': videoTitle,
///   'thumbnail_url': thumbnailUrl,
///   'type': 'video', // or 'sound', 'effect'
///   'duration': duration,
///   'collection_id': collectionId, // null if "Just Save" was selected
///   'saved_at': FieldValue.serverTimestamp(),
/// });
///
/// // If added to a collection, increment the collection's item count
/// if (collectionId != null) {
///   await FirebaseFirestore.instance
///       .collection('users')
///       .doc(currentUserId)
///       .collection('collections')
///       .doc(collectionId)
///       .update({
///     'item_count': FieldValue.increment(1),
///   });
/// }
/// ```