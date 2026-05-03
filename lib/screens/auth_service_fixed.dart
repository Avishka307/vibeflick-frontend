import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import 'activity_interest_selection.dart';


class AuthService {
  // Firebase instances
  static final FirebaseAuth auth = FirebaseAuth.instance;
  static final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // Get current user
  static User? getCurrentUser() {
    return auth.currentUser;
  }

  // Check if user is email user
  static bool isEmailUser(User user) {
    return user.providerData.any((userInfo) =>
    userInfo.providerId == 'password'
    );
  }

  // Check network availability
  static Future<bool> isNetworkAvailable() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult.any((result) =>
      result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet
      );
    } catch (e) {
      debugPrint('Error checking network: $e');
      return false;
    }
  }

  // Show no internet dialog
  static void showNoInternetDialog(
      BuildContext context, {
        VoidCallback? onRetry,
      }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.red[700]),
            const SizedBox(width: 12),
            const Text('No Internet Connection'),
          ],
        ),
        content: const Text(
          'Please check your internet connection and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (onRetry != null) {
                onRetry();
              }
            },
            child: const Text('Retry'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // ✅ FIXED: Check if user has completed interests selection
  static Future<bool> hasCompletedInterests(String uid) async {
    try {
      debugPrint('Checking interests for UID: $uid');

      final docSnapshot = await firestore
          .collection('users')
          .doc(uid)
          .get();

      if (!docSnapshot.exists) {
        debugPrint('❌ User document does not exist');
        return false;
      }

      final data = docSnapshot.data();

      if (data == null) {
        debugPrint('❌ User document data is null');
        return false;
      }

      // Check if interests field exists and is not empty
      if (data.containsKey('interests')) {
        final interests = data['interests'];

        // Check if interests is a non-empty string
        if (interests is String && interests.trim().isNotEmpty) {
          debugPrint('✅ User has interests: $interests');
          return true;
        }

        // Check if interests is a non-empty list
        if (interests is List && interests.isNotEmpty) {
          debugPrint('✅ User has interests (list): $interests');
          return true;
        }
      }

      debugPrint('❌ User has no interests or interests is empty');
      return false;
    } catch (e) {
      debugPrint('❌ Error checking interests: $e');
      return false;
    }
  }

  // ✅ FIXED: Check user interests and navigate with proper logic
  static Future<void> checkUserInterestsAndNavigate({
    required BuildContext context,
    required String uid,
    VoidCallback? onLoadingStart,
    VoidCallback? onLoadingEnd,
  }) async {
    try {
      if (onLoadingStart != null) {
        onLoadingStart();
      }

      debugPrint('🔍 Checking interests for user: $uid');

      // Check if user has completed interests
      final hasInterests = await hasCompletedInterests(uid);

      if (onLoadingEnd != null) {
        onLoadingEnd();
      }

      if (!context.mounted) return;

      if (hasInterests) {
        // ✅ User has interests - Go to main screen
        debugPrint('✅ User has interests - Navigating to MainActivity');
        await _saveLoginState(true); // Mark as logged in
        _navigateToMainActivity(context);
      } else {
        // ❌ User needs to select interests
        debugPrint('❌ User needs to select interests - Navigating to InterestSelection');
        await _saveLoginState(false); // Mark as not fully onboarded
        _navigateToInterestSelectionActivity(context);
      }
    } catch (e) {
      debugPrint('❌ Error in checkUserInterestsAndNavigate: $e');

      if (onLoadingEnd != null) {
        onLoadingEnd();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error loading user data. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Save login state to SharedPreferences
  static Future<void> _saveLoginState(bool hasCompletedOnboarding) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      await prefs.setBool('has_completed_onboarding', hasCompletedOnboarding);
      debugPrint('Login state saved: onboarding=$hasCompletedOnboarding');
    } catch (e) {
      debugPrint('Error saving login state: $e');
    }
  }

  // Clear login state (for logout)
  static Future<void> clearLoginState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_logged_in');
      await prefs.remove('has_completed_onboarding');
      debugPrint('Login state cleared');
    } catch (e) {
      debugPrint('Error clearing login state: $e');
    }
  }

  // Check if user is logged in (for auto-login)
  static Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('is_logged_in') ?? false;
    } catch (e) {
      debugPrint('Error checking login state: $e');
      return false;
    }
  }

  // Check if user has completed onboarding
  static Future<bool> hasCompletedOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('has_completed_onboarding') ?? false;
    } catch (e) {
      debugPrint('Error checking onboarding state: $e');
      return false;
    }
  }

  // Navigate to MainActivity
  static void _navigateToMainActivity(BuildContext context) {
    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const MainScreen(),
      ),
          (route) => false, // Remove all previous routes
    );
  }

  // Navigate to InterestSelectionActivity
  static void _navigateToInterestSelectionActivity(BuildContext context) {
    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const InterestSelectionActivity(),
      ),
          (route) => false, // Remove all previous routes
    );
  }

  // ✅ NEW: Auto-login check (call this in splash screen or initial page)
  static Future<void> checkAutoLogin(BuildContext context) async {
    try {
      final currentUser = getCurrentUser();

      if (currentUser == null) {
        debugPrint('❌ No user logged in - Show login page');
        return; // Stay on login page
      }

      debugPrint('✅ User is logged in: ${currentUser.uid}');

      // Check if email user and if email is verified
      if (isEmailUser(currentUser) && !currentUser.emailVerified) {
        debugPrint('❌ Email not verified');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please verify your email to continue'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Check if user has completed interests
      final hasInterests = await hasCompletedInterests(currentUser.uid);

      if (!context.mounted) return;

      if (hasInterests) {
        // User has completed onboarding - Go directly to main screen
        debugPrint('✅ Auto-login: Navigating to MainActivity');
        _navigateToMainActivity(context);
      } else {
        // User needs to complete interests
        debugPrint('⚠️ Auto-login: User needs to select interests');
        _navigateToInterestSelectionActivity(context);
      }
    } catch (e) {
      debugPrint('❌ Error in auto-login check: $e');
    }
  }

  // ✅ NEW: Logout function
  static Future<void> logout(BuildContext context) async {
    try {
      await auth.signOut();
      await clearLoginState();
      debugPrint('✅ User logged out successfully');

      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const MainScreen(), // Replace with your login page
          ),
              (route) => false,
        );
      }
    } catch (e) {
      debugPrint('❌ Error logging out: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error logging out. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}