// lib/screens/settings/help_and_feedback_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'report_problem_screen.dart';
import 'send_feedback_screen.dart';
import 'faq_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

class HelpAndFeedbackScreen extends StatelessWidget {
  const HelpAndFeedbackScreen({Key? key}) : super(key: key);

  // 📧 Enhanced Contact Support with pre-filled information
  Future<void> _contactSupport(BuildContext context) async {
    try {
      // 1️⃣ Get current user info from Firebase
      final currentUser = FirebaseAuth.instance.currentUser;
      final userName = currentUser?.displayName ?? 'User';
      final userEmail = currentUser?.email ?? 'Not provided';
      final userId = currentUser?.uid ?? 'Unknown';

      // 2️⃣ Get device information
      String deviceInfo = '';
      try {
        if (Platform.isAndroid) {
          deviceInfo = 'Android ${Platform.operatingSystemVersion}';
        } else if (Platform.isIOS) {
          deviceInfo = 'iOS ${Platform.operatingSystemVersion}';
        } else {
          deviceInfo = Platform.operatingSystem;
        }
      } catch (e) {
        deviceInfo = 'Unknown Device';
      }

      // 3️⃣ Create email body with pre-filled information
      final emailBody = '''
Hello VibeFlick Support Team,

I need help with the following:

[Please describe your issue here]

---
User Information:
- Name: $userName
- Email: $userEmail
- User ID: $userId
- Device: $deviceInfo
- App Version: 1.0.0

Thank you!
      ''';

      // 4️⃣ Create mailto URI with all details
      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: 'officialvibeflickgx@gmail.com',
        query: _encodeQueryParameters({
          'subject': 'VibeFlick Support Request',
          'body': emailBody,
        }),
      );

      debugPrint('📧 Opening email app...');
      debugPrint('Email URI: $emailUri');

      // 5️⃣ Launch email app
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(
          emailUri,
          mode: LaunchMode.externalApplication, // 🔥 Opens external email app
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Email app opened successfully'),
                ],
              ),
              backgroundColor: Color(0xFF43E97B),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('No email app found');
      }
    } catch (e) {
      debugPrint('❌ Email error: $e');

      if (context.mounted) {
        // Show error with copy email option
        _showEmailErrorDialog(context, e.toString());
      }
    }
  }

  // 🔧 Helper function to encode query parameters
  String _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  // 🚨 Show error dialog with option to copy email
  void _showEmailErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Color(0xFFFF3B5C)),
            SizedBox(width: 12),
            Text(
              'No Email App Found',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We couldn\'t find an email app on your device.',
              style: TextStyle(color: Colors.grey.shade300),
            ),
            const SizedBox(height: 16),
            Text(
              'Please install Gmail, Outlook, or another email app, or copy our email address:',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF43E97B)),
              ),
              child: const Text(
                'officialvibeflickgx@gmail.com',
                style: TextStyle(
                  color: Color(0xFF43E97B),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(
                const ClipboardData(text: 'officialvibeflickgx@gmail.com'),
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 12),
                      Text('Email copied to clipboard!'),
                    ],
                  ),
                  backgroundColor: Color(0xFF43E97B),
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy Email'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF43E97B),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        title: const Text(
          'Help & Feedback',
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
        padding: const EdgeInsets.all(16),
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search for help...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                border: InputBorder.none,
              ),
              onSubmitted: (value) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FAQScreen(searchQuery: value),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // FAQ / Help Center
          _buildMenuItem(
            context: context,
            icon: Icons.help_outline,
            iconColor: const Color(0xFF4FACFE),
            title: 'FAQ / Help Center',
            subtitle: 'Find answers to common questions',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FAQScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // Report a Problem
          _buildMenuItem(
            context: context,
            icon: Icons.error_outline,
            iconColor: const Color(0xFFFF3B5C),
            title: 'Report a Problem',
            subtitle: 'Let us know about bugs or issues',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ReportProblemScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // Send Feedback
          _buildMenuItem(
            context: context,
            icon: Icons.chat_bubble_outline,
            iconColor: const Color(0xFF43E97B),
            title: 'Send Feedback',
            subtitle: 'Share your thoughts and suggestions',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SendFeedbackScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // Contact Support - Enhanced with email pre-fill
          _buildMenuItem(
            context: context,
            icon: Icons.email_outlined,
            iconColor: const Color(0xFFF093FB),
            title: 'Contact Support',
            subtitle: 'Get direct help from our team',
            onTap: () => _contactSupport(context),
          ),

          const SizedBox(height: 32),

          // Support Hours
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.access_time,
                  color: Colors.grey.shade400,
                  size: 32,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Support Hours',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Monday - Friday: 9:00 AM - 6:00 PM',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Saturday - Sunday: 10:00 AM - 4:00 PM',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey.shade600,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}