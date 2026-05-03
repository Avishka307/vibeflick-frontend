import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'activity_log_screen.dart';
import 'change_password_screen.dart';
import 'delete_account_screen.dart';
import 'request_verification_badge.dart';

class ActivityAccountSettings extends StatefulWidget {
  const ActivityAccountSettings({Key? key}) : super(key: key);

  @override
  State<ActivityAccountSettings> createState() => _ActivityAccountSettingsState();
}

class _ActivityAccountSettingsState extends State<ActivityAccountSettings> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Dark theme colors
  static const Color _bgColor = Color(0xFF1F1F1F);
  static const Color _cardColor = Color(0xFF2A2A2A);
  static const Color _accentColor = Color(0xFF6C63FF);
  static const Color _secondaryAccent = Color(0xFF9B59D0);

  // 🆕 Passkey status tracking
  bool _isPasskeyActive = false;
  bool _isCheckingPasskey = true;

  @override
  void initState() {
    super.initState();
    _checkPasskeyStatus(); // 🆕 Check if passkey is set up
  }

  // 🆕 Check if user has passkey enabled
  Future<void> _checkPasskeyStatus() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        final userDoc = await _db.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data();
          setState(() {
            _isPasskeyActive = data?['passkeyEnabled'] == true;
            _isCheckingPasskey = false;
          });
        }
      }
    } catch (e) {
      print('Error checking passkey status: $e');
      setState(() {
        _isCheckingPasskey = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section
            _buildHeader(),

            // Security Settings Card
            _buildSecurityCard(),

            // Danger Zone Card
            _buildDangerZoneCard(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_accentColor, _secondaryAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 55, 16, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(2),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Account Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Change Password
          _buildSettingItem(
            icon: Icons.lock,
            title: 'Change Password',
            subtitle: 'Update your password',
            iconBgColor: _accentColor.withOpacity(0.2),
            iconColor: _accentColor,
            onTap: _handleChangePassword,
          ),
          _buildDivider(),

          // 🆕 PASSKEYS SECTION
          _buildPasskeyItem(),
          _buildDivider(),

          // 🆕 REQUEST VERIFICATION BADGE
          _buildSettingItem(
            icon: Icons.verified,
            title: 'Request Verification',
            subtitle: 'Get verified badge for your account',
            iconBgColor: const Color(0xFF4CAF50).withOpacity(0.2),
            iconColor: const Color(0xFF4CAF50),
            onTap: _handleRequestVerification,
          ),
          _buildDivider(),

          // Logged In Devices
          _buildSettingItem(
            icon: Icons.devices,
            title: 'Logged In Devices',
            subtitle: 'Manage logged in devices',
            iconBgColor: _accentColor.withOpacity(0.15),
            iconColor: _accentColor,
            onTap: _handleLoggedDevices,
            isLast: true,
          ),
        ],
      ),
    );
  }

  // 🆕 PASSKEY ITEM WITH STATUS INDICATOR
  Widget _buildPasskeyItem() {
    return InkWell(
      onTap: _handlePasskeys,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            // Icon Container
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.fingerprint, // 🔑 Passkey icon
                color: Color(0xFF4CAF50),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Title & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Passkeys',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 🆕 STATUS BADGE
                      if (!_isCheckingPasskey)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isPasskeyActive
                                ? const Color(0xFF4CAF50).withOpacity(0.2)
                                : Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _isPasskeyActive
                                  ? const Color(0xFF4CAF50)
                                  : Colors.grey.shade600,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _isPasskeyActive ? 'Active' : 'Not Set',
                            style: TextStyle(
                              color: _isPasskeyActive
                                  ? const Color(0xFF4CAF50)
                                  : Colors.grey.shade400,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Use biometrics to sign in safely',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Arrow Icon
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey.shade600,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerZoneCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Danger Zone Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Danger Zone',
                    style: TextStyle(
                      color: Color(0xFFFF6584),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6584).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            height: 1,
            color: const Color(0xFF3A3A3A),
          ),
          // Delete Account
          _buildSettingItem(
            icon: Icons.delete_forever,
            title: 'Delete Account',
            subtitle: 'Permanently delete account',
            iconBgColor: const Color(0xFFFF6584).withOpacity(0.2),
            iconColor: const Color(0xFFFF6584),
            titleColor: const Color(0xFFFF6584),
            onTap: _showDeleteAccountConfirmation,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconBgColor,
    required Color iconColor,
    Color? titleColor,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: titleColor ?? Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.only(left: 84, right: 20),
      height: 1,
      color: const Color(0xFF3A3A3A),
    );
  }

  // Event Handlers
  void _handleChangePassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChangePasswordScreen(),
      ),
    );
  }

  // 🆕 PASSKEY HANDLER
  void _handlePasskeys() {
    // TODO: Navigate to Passkey Management Screen
    _showComingSoon();
  }

  // 🆕 REQUEST VERIFICATION HANDLER
  void _handleRequestVerification() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RequestVerificationBadge(),
      ),
    );
  }

  void _handleLoggedDevices() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ActivityLogScreen(),
      ),
    );
  }

  void _showDeleteAccountConfirmation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DeleteAccountScreen(),
      ),
    );
  }

  // 🆕 COMING SOON DIALOG
  void _showComingSoon() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.fingerprint,
                color: Color(0xFF4CAF50),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Passkeys',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Coming Soon!',
              style: TextStyle(
                color: Colors.grey.shade300,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Passkey authentication is currently under development. You\'ll soon be able to sign in securely using biometrics.',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _accentColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: _accentColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Stay tuned for updates!',
                      style: TextStyle(
                        color: Colors.grey.shade300,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('Deleting Account', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _accentColor),
            const SizedBox(height: 16),
            Text('Please wait...', style: TextStyle(color: Colors.grey.shade300)),
          ],
        ),
      ),
    );

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        Navigator.pop(context);
        _showError('User not found');
        return;
      }

      final userId = currentUser.uid;

      // Delete user media from Firestore
      await _deleteUserMedia(userId);

      // Delete user document
      await _db.collection('users').doc(userId).delete();

      // Delete user from Firebase Auth
      await currentUser.delete();

      // Sign out
      await _auth.signOut();

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show success and navigate to login
      _showSuccess('Account deleted successfully');

    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showError('Failed to delete account: $e');
    }
  }

  Future<void> _deleteUserMedia(String userId) async {
    try {
      final mediaSnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('media')
          .get();

      for (var doc in mediaSnapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error deleting media: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFF6584),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}