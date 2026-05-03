// block_helper.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BlockHelper {
  static final _db  = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ── දෙපැත්තෙන්ම blocked IDs ටික ගන්නවා ──────────────────────────
  // (මම block කළා) + (මාව block කළා) — දෙකම hide කරන්න ඕනේ
  static Future<List<String>> getBlockedUserIds() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final results = await Future.wait([
      // මම block කළ people
      _db.collection('blocked_users')
          .where('blockerId', isEqualTo: uid)
          .get(),
      // මාව block කළ people
      _db.collection('blocked_users')
          .where('blockedId', isEqualTo: uid)
          .get(),
    ]);

    final ids = <String>{};
    for (final snap in results) {
      for (final doc in snap.docs) {
        final data = doc.data();
        // මගේ ID නෙමෙයි — අනිත් කෙනාගේ ID ගන්නවා
        final other = data['blockerId'] == uid
            ? data['blockedId']
            : data['blockerId'];
        if (other != null) ids.add(other as String);
      }
    }

    return ids.toList();
  }

  // ── කෙනෙකු specific ව block වෙලාද බලන්න ──────────────────────
  static Future<bool> isBlockedWith(String otherUserId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    final results = await Future.wait([
      _db.collection('blocked_users')
          .where('blockerId', isEqualTo: uid)
          .where('blockedId', isEqualTo: otherUserId)
          .limit(1).get(),
      _db.collection('blocked_users')
          .where('blockerId', isEqualTo: otherUserId)
          .where('blockedId', isEqualTo: uid)
          .limit(1).get(),
    ]);

    return results.any((snap) => snap.docs.isNotEmpty);
  }
}