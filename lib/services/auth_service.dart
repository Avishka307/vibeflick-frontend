import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../main.dart';
import '../screens/activity_interest_selection.dart';


/// AuthService - පොදු Authentication Functions හැමතැනම use කරන්න
///
/// මේ class එකේ තියෙන්නේ:
/// 1. Network check කරන function
/// 2. User interests check කරලා navigate කරන function
/// 3. Dialog boxes show කරන functions
class AuthService {
  // Firebase instances - static කරලා තියෙන්නේ හැමතැනම access කරන්න
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 1️⃣ Network තියෙනවද බලන්න
  /// Return: true = ඉන්ටර්නෙට් තියෙනවා, false = නෑ
  static Future<bool> isNetworkAvailable() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      debugPrint('Network check error: $e');
      return false;
    }
  }

  /// 2️⃣ "No Internet" dialog එක show කරන්න
  static void showNoInternetDialog(BuildContext context, {VoidCallback? onRetry}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text(
          'No Internet Connection',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Please check your internet connection and try again.',
          style: TextStyle(color: Color(0xFFAAAAAA)),
        ),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: const Text('Retry', style: TextStyle(color: Color(0xFFFF3B5C))),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              onRetry != null ? 'Cancel' : 'OK',
              style: const TextStyle(color: Color(0xFF888888)),
            ),
          ),
        ],
      ),
    );
  }

  /// 3️⃣ User ගේ interests check කරලා සුදුසු page එකට යන්න
  ///
  /// Logic:
  /// - Interests තියෙනවා නම් → MainActivity යන්න
  /// - Interests නැත්නම් → InterestSelectionActivity යන්න
  static Future<void> checkUserInterestsAndNavigate({
    required BuildContext context,
    required String uid,
    VoidCallback? onLoadingStart,
    VoidCallback? onLoadingEnd,
  }) async {
    // Network check කරන්න
    if (!await isNetworkAvailable()) {
      showNoInternetDialog(context);
      if (onLoadingEnd != null) onLoadingEnd();
      return;
    }

    try {
      if (onLoadingStart != null) onLoadingStart();

      // Firestore එකෙන් user document එක ගන්න
      final docSnapshot = await _firestore.collection('users').doc(uid).get();

      if (onLoadingEnd != null) onLoadingEnd();

      if (!context.mounted) return;

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        final interests = data?['interests'];

        // Interests තියෙනවද බලන්න
        if (interests != null && interests.toString().trim().isNotEmpty) {
          // ✅ Interests තියෙනවා → MainActivity යන්න
          debugPrint('User has interests, navigating to MainActivity');
          _navigateToMainActivity(context);
        } else {
          // ❌ Interests නෑ → InterestSelectionActivity යන්න
          debugPrint('User has no interests, navigating to InterestSelectionActivity');
          _navigateToInterestSelection(context);
        }
      } else {
        // Document එක නෑ → InterestSelectionActivity යන්න
        debugPrint('User document does not exist, navigating to InterestSelectionActivity');
        _navigateToInterestSelection(context);
      }
    } catch (e) {
      debugPrint('Error checking interests: $e');
      if (onLoadingEnd != null) onLoadingEnd();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error checking user data. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );

      // Error වුණොත් default විදියට InterestSelection එකට යන්න
      _navigateToInterestSelection(context);
    }
  }

  /// 4️⃣ MainActivity එකට navigate කරන්න
  static void _navigateToMainActivity(BuildContext context) {
    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
    );
  }

  /// 5️⃣ InterestSelectionActivity එකට navigate කරන්න
  static void _navigateToInterestSelection(BuildContext context) {
    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const InterestSelectionActivity()),
          (route) => false,
    );
  }

  /// 6️⃣ User email provider එකකින්ද (Google එකෙන් නෙවෙයිද) login වුණේ කියලා check කරන්න
  static bool isEmailUser(User user) {
    for (var info in user.providerData) {
      if (info.providerId == 'google.com') {
        return false; // Google user
      }
    }
    return true; // Email user
  }

  /// 7️⃣ Current logged in user ගන්න (null return වෙයි නැත්නම්)
  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// 8️⃣ Firebase Auth instance එක ගන්න (rare cases වලට)
  static FirebaseAuth get auth => _auth;

  /// 9️⃣ Firestore instance එක ගන්න (rare cases වලට)
  static FirebaseFirestore get firestore => _firestore;
}