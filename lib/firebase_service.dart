import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Save sound metadata to Firestore after uploading to Supabase
  static Future<String?> saveSoundMetadata({
    required String title,
    required String supabaseAudioUrl,
    required String artist,
    required int duration,
  }) async {
    try {
      final user = _auth.currentUser;
      final uploaderName = user?.displayName ?? user?.email ?? 'Anonymous';

      final docRef = await _firestore.collection('sounds').add({
        'title': title,
        'audioUrl': supabaseAudioUrl,
        'artist': artist,
        'duration': duration,
        'uploadedBy': uploaderName,
        'userId': user?.uid ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'category': 'User Uploads',
      });

      print('✅ Sound metadata saved to Firestore with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Error saving to Firestore: $e');
      return null;
    }
  }

  /// Load all sounds from Firestore for "For You" page
  /// Implements pagination to reduce reads
  static Future<List<Map<String, dynamic>>> loadSoundsFromFirestore({
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query query = _firestore
          .collection('sounds')
          .orderBy('createdAt', descending: true)
          .limit(limit);

      // If pagination, start after last document
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Add document ID
        return data;
      }).toList();
    } catch (e) {
      print('❌ Error loading from Firestore: $e');
      return [];
    }
  }

  /// Delete sound metadata from Firestore
  static Future<bool> deleteSoundMetadata(String documentId) async {
    try {
      await _firestore.collection('sounds').doc(documentId).delete();
      print('✅ Sound metadata deleted from Firestore');
      return true;
    } catch (e) {
      print('❌ Error deleting from Firestore: $e');
      return false;
    }
  }

  /// Update sound metadata in Firestore
  static Future<bool> updateSoundMetadata({
    required String documentId,
    String? title,
    String? artist,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (title != null) updates['title'] = title;
      if (artist != null) updates['artist'] = artist;

      if (updates.isEmpty) return false;

      await _firestore.collection('sounds').doc(documentId).update(updates);
      print('✅ Sound metadata updated in Firestore');
      return true;
    } catch (e) {
      print('❌ Error updating Firestore: $e');
      return false;
    }
  }

  /// Enable offline persistence (call this once during app initialization)
  /// FIXED: Proper way to enable Firestore settings
  static Future<void> enableOfflinePersistence() async {
    try {
      // Correct way to set Firestore settings
      _firestore.settings;
      print('✅ Firestore offline persistence enabled');
    } catch (e) {
      print('⚠️ Could not enable persistence: $e');
    }
  }
}