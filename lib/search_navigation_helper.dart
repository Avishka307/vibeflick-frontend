import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'search_page.dart';

/// 🔍 Search Navigation Helper
/// මේ method එක for_you_screen.dart සහ post_detail_page.dart වල search icon එකේ onTap එකට use කරන්න
class SearchNavigationHelper {
  static void navigateToSearch(BuildContext context) {
    // Haptic feedback
    HapticFeedback.lightImpact();

    debugPrint('🔍 Navigating to search page');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SearchPage(),
      ),
    );
  }
}