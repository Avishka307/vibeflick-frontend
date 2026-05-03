// lib/screens/settings/legal_and_policies_screen.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

class LegalAndPoliciesScreen extends StatelessWidget {
  const LegalAndPoliciesScreen({Key? key}) : super(key: key);

  // 🔗 Links
  static const String privacyPolicyUrl = 'https://avishkadilshandev.github.io/vibeflick-legal/';
  static const String termsOfServiceUrl = 'https://avishkadilshandev.github.io/vibeflick-legal/terms.html';

  // 📡 Internet Connection Check කරන method
  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } on SocketException catch (_) {
      return false;
    }
    return false;
  }

  // 🌐 Launch කරන method with Loading & Connection Check
  Future<void> _launchInAppWebView(BuildContext context, String url, String title) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Custom Loading Progress Bar
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(seconds: 2),
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF3B5C)),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Loading...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Opening $title',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Check Internet Connection
    bool hasConnection = await _checkInternetConnection();

    if (!hasConnection) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Show no internet dialog
      if (context.mounted) {
        _showNoInternetDialog(context);
      }
      return;
    }

    final Uri uri = Uri.parse(url);

    try {
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.inAppWebView,
        webViewConfiguration: const WebViewConfiguration(
          enableJavaScript: true,
          enableDomStorage: true,
        ),
      );

      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (!launched) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to open $title'),
              backgroundColor: const Color(0xFFFF3B5C),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: const Color(0xFFFF3B5C),
          ),
        );
      }
    }
  }

  // 📶 No Internet Dialog
  void _showNoInternetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B5C).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off,
                  size: 48,
                  color: Color(0xFFFF3B5C),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Internet Connection',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Please check your internet connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3B5C),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Got it',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F), // ⭐ Dark Background
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F), // ⭐ Dark AppBar
        elevation: 0,
        title: const Text(
          'Legal and Policies',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          // Privacy Policy Card
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF2A2A2A), // ⭐ Dark Card
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B5C).withOpacity(0.1), // ⭐ Pink accent
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.privacy_tip_outlined,
                  color: Color(0xFFFF3B5C), // ⭐ Pink icon
                ),
              ),
              title: const Text(
                'Privacy Policy',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.white, // ⭐ White text
                ),
              ),
              subtitle: const Text(
                'GDPR & CCPA Compliant',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey, // ⭐ Grey subtitle
                ),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey, // ⭐ Grey arrow
              ),
              onTap: () => _launchInAppWebView(
                context,
                privacyPolicyUrl,
                'Privacy Policy',
              ),
            ),
          ),

          // Terms of Service Card
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF2A2A2A), // ⭐ Dark Card
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B5C).withOpacity(0.1), // ⭐ Pink accent
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: Color(0xFFFF3B5C), // ⭐ Pink icon
                ),
              ),
              title: const Text(
                'Terms of Service',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.white, // ⭐ White text
                ),
              ),
              subtitle: const Text(
                'User Agreement',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey, // ⭐ Grey subtitle
                ),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey, // ⭐ Grey arrow
              ),
              onTap: () => _launchInAppWebView(
                context,
                termsOfServiceUrl,
                'Terms of Service',
              ),
            ),
          ),

          // About Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                const Text(
                  'About',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white, // ⭐ White heading
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'VibeFlick is committed to protecting your privacy and ensuring transparency in how we handle your data.',
                  style: TextStyle(
                    color: Colors.grey.shade400, // ⭐ Light grey text
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFFFF3B5C),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'GDPR Compliant (Europe)',
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFFFF3B5C),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CCPA Compliant (USA)',
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Last Updated: February 09, 2026',
                  style: TextStyle(
                    color: Colors.grey.shade600, // ⭐ Darker grey
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}