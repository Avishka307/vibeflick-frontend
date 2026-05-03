import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page_activity.dart'; // path adjust කරන්න

class BannedUserScreen extends StatelessWidget {
  const BannedUserScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPageActivity()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Icon ─────────────────────────────────────
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFDC2626).withOpacity(0.15),
                    border: Border.all(
                      color: const Color(0xFFDC2626),
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      '💀',
                      style: TextStyle(fontSize: 56),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ── Title ────────────────────────────────────
                const Text(
                  'Account Permanently Banned',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // ── Sinhala Message ──────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFDC2626).withOpacity(0.4),
                    ),
                  ),
                  child: const Text(
                    'ඔබේ ගිණුම ප්‍රජා මාර්ගෝපදේශ (Community Guidelines) '
                        'නැවත නැවත උල්ලංඝනය කිරීම නිසා ස්ථිරවම '
                        'අත්හිටුවා ඇත.\n\n'
                        'ඔබට VibeFlick භාවිතා කිරීමට තවදුරටත් '
                        'ඉඩ නොලැබේ.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFFCCCCCC),
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 24),

                // ── Strike Info ──────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.close,
                            color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Strike ${i + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )),
                ),

                const SizedBox(height: 40),

                // ── Only Action: Logout ──────────────────────
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _logout(context),
                    icon: const Icon(Icons.logout,
                        color: Color(0xFF9CA3AF)),
                    label: const Text(
                      'Log Out',
                      style: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: Colors.white.withOpacity(0.2),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Support Link ─────────────────────────────
                TextButton(
                  onPressed: () {
                    // TODO: support email/link
                  },
                  child: const Text(
                    'Contact Support',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}