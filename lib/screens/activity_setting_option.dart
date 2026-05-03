import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ⭐ Data cleanup සඳහා
import '../Help & Feedback/help_and_feedback_screen.dart';
import '../firebase_options.dart';
import '../sample/text_create_screen.dart';
import 'about_us_screen.dart';
import 'activity_account_settings.dart';
import 'activity_privacy.dart';
import 'activity_notification.dart';
import 'clean_storage_screen.dart';
import 'language_screen.dart';
import 'legal_and_policies_screen.dart';
import 'loginpage_activity.dart';



class ActivitySettingOption extends StatelessWidget {
  const ActivitySettingOption({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      body: CustomScrollView(
        slivers: [
          // App Bar with Gradient
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6B4CE6), Color(0xFF9B59D0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            title: const Text(
              'Settings',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.4,
              ),
            ),
            centerTitle: true,
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Account Section
                _buildSectionHeader('ACCOUNT'),
                _buildCard([
                  _buildSettingsItem(
                    id: 'accountItem',
                    icon: Icons.person,
                    iconGradient: const [Color(0xFF667EEA), Color(0xFF764BA2)],
                    title: 'Account',
                    subtitle: 'Manage your profile',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(           //ActivityAccountSettings
                          builder: (context) => const ActivityAccountSettings(),
                        ),
                      );
                    },
                  ),
                  _buildSettingsItem(
                    id: 'privacyItem',
                    icon: Icons.security,
                    iconGradient: const [Color(0xFFF093FB), Color(0xFFF5576C)],
                    title: 'Privacy',
                    subtitle: 'Privacy settings',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ActivityPrivacy(),
                        ),
                      );
                    },
                  ),
                ]),

                // General Section
                _buildSectionHeader('GENERAL'),
                _buildCard([
                  _buildSettingsItem(
                    id: 'notificationsItem',
                    icon: Icons.notifications,
                    iconGradient: const [Color(0xFF4FACFE), Color(0xFF00F2FE)],
                    title: 'Notifications',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ActivityNotification(),
                        ),
                      );
                    },
                  ),
                  _buildDivider(),
                  // Language item එක මේ විදිහට replace කරන්න:
                  _buildSettingsItem(
                    id: 'languageItem',
                    icon: Icons.language,
                    iconGradient: const [Color(0xFF43E97B), Color(0xFF38F9D7)],
                    title: 'Language',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LanguageScreen(),
                        ),
                      );
                    },
                    // ⭐ isDisabled අයින් කරන්න හෝ false කරන්න
                  ),
                  _buildDivider(),
                  // Clean Storage option එකට navigation add කරන්න:
                  _buildSettingsItem(
                    id: 'cleanStorageItem',
                    icon: Icons.storage,
                    iconGradient: const [Color(0xFFFA709A), Color(0xFFFEE140)],
                    title: 'Clean Storage',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CleanStorageScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDivider(),
                  _buildSettingsItem(
                    id: 'analyticsItem',
                    icon: Icons.analytics,
                    iconGradient: const [Color(0xFF30CFD0), Color(0xFF330867)],
                    title: 'Analytics',
                    onTap: () {
                      _showComingSoonBottomSheet(context);
                    },
                    isDisabled: true,
                  ),
                ]),

                // About Section
                _buildSectionHeader('ABOUT'),
                _buildCard([
                  _buildSettingsItem(
                    id: 'legalItem',
                    icon: Icons.gavel,
                    iconGradient: const [Color(0xFFA8EDEA), Color(0xFFFED6E3)],
                    title: 'Legal and Policies',
                    onTap: () {
                      // ⭐ මේ තමයි වෙනස් කරපු එකම තැන
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LegalAndPoliciesScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDivider(),
                  // Find "Help & Feedback" section and update:

                  _buildSettingsItem(
                    id: 'helpItem',
                    icon: Icons.help_outline,
                    iconGradient: const [Color(0xFFFF9A9E), Color(0xFFFAD0C4)],
                    title: 'Help & Feedback',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HelpAndFeedbackScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDivider(),
                  _buildSettingsItem(
                    id: 'aboutItem',
                    icon: Icons.info_outline,
                    iconGradient: const [Color(0xFFFBC2EB), Color(0xFFA6C1EE)],
                    title: 'About Us',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AboutUsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDivider(),
                  _buildSettingsItem(
                    id: 'switchAccountItem',
                    icon: Icons.swap_horiz,
                    iconGradient: const [Color(0xFFFDCBF1), Color(0xFFE6DEE9)],
                    title: 'Switch Account',
                    onTap: () {
                      _showComingSoonBottomSheet(context);
                    },
                    isDisabled: true,
                  ),
                ]),

                const SizedBox(height: 24),

                // Logout Button
                _buildCard([
                  _buildSettingsItem(
                    id: 'logoutItem',
                    icon: Icons.logout,
                    iconGradient: const [Color(0xFFFF6B6B), Color(0xFFFF4757)],
                    title: 'Logout',
                    onTap: () {
                      _showLogoutConfirmation(context);
                    },
                  ),
                ]),

                const SizedBox(height: 24),

                // App Version
                Center(
                  child: Text(
                    'App Version: v1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.5),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          color: Colors.white.withOpacity(0.6),
          fontWeight: FontWeight.bold,
          letterSpacing: 0.65,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingsItem({
    required String id,
    required IconData icon,
    required List<Color> iconGradient,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool isDisabled = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Row(
            children: [
              // Icon Container with Gradient
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDisabled
                        ? [Colors.grey.shade600, Colors.grey.shade700]
                        : iconGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        color: isDisabled
                            ? Colors.grey.shade500
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDisabled
                              ? Colors.grey.shade600
                              : Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Arrow Icon
              Icon(
                Icons.arrow_forward_ios,
                size: 20,
                color: isDisabled
                    ? Colors.grey.shade700
                    : Colors.white.withOpacity(0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.only(left: 76),
      height: 1,
      color: Colors.white.withOpacity(0.1),
    );
  }

  void _showComingSoonBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF2A2A2A),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6B4CE6), Color(0xFF9B59D0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.upcoming,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Coming Soon!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This feature is coming soon! Stay tuned.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withOpacity(0.7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B4CE6),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Got it!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Logout',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(
            color: Color(0xFFB0B0B0),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              // ⭐⭐⭐ මේ තමයි වෙනස් කරපු logout function එක ⭐⭐⭐
              try {
                // 1️⃣ Firebase session එක terminate කරනවා
                await FirebaseAuth.instance.signOut();

                // 2️⃣ Local data cleanup කරනවා
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear(); // සියලුම local data clear කරනවා

                if (context.mounted) {
                  // 3️⃣ Dialog එක close කරනවා
                  Navigator.pop(context);

                  // 4️⃣ Success message එක පෙන්වනවා
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Logged out successfully'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );

                  // 5️⃣ මුළු navigation stack එක clear කරලා Login screen එකට යනවා
                  // ⚠️ CRITICAL: මේකෙන් back button එක එබුවාට Settings එකට එන්න බෑ
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginPageActivity(), // ⭐ ඔයාගේ login screen widget name එක මෙතන දාන්න
                    ),
                        (route) => false, // මේකෙන් කියන්නේ පරණ stack එක අයින් කරන්න කියලා
                  );
                }
              } catch (e) {
                // Error handling
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Logout failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4757),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Logout',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Usage Example
void main() {
  runApp(const MaterialApp(
    home: ActivitySettingOption(),
  ));
}