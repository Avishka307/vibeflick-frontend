import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import 'activity_login.dart';
import 'activity_register.dart';
import 'notification_service.dart';
import 'verify_email_screen.dart'; // ✅ Email verification screen import

class LoginPageActivity extends StatefulWidget {
  const LoginPageActivity({super.key});

  @override
  State<LoginPageActivity> createState() => _LoginPageActivityState();
}

class _LoginPageActivityState extends State<LoginPageActivity>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _dotController;

  // Firebase instances
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String privacyPolicyUrl = 'https://avishkadilshandev.github.io/vibeflick-legal/';
  static const String termsOfServiceUrl = 'https://avishkadilshandev.github.io/vibeflick-legal/terms.html';
  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Auto-login check with proper loading state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkCurrentUser();
    });
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  // Check if current user is logged in
  Future<void> _checkCurrentUser() async {
    final currentUser = AuthService.getCurrentUser();

    if (currentUser == null) {
      debugPrint('❌ No user logged in - Showing login page');
      return; // Stay on login page
    }

    debugPrint('✅ User already logged in: ${currentUser.uid}');
    _showLoading();

    try {
      // ✅ EMAIL VERIFICATION CHECK - NEW CODE
      // Check if email user and if email is verified
      if (AuthService.isEmailUser(currentUser) && !currentUser.emailVerified) {
        _hideLoading();
        debugPrint('❌ Email not verified - redirecting to verification screen');

        if (mounted) {

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const VerifyEmailScreen(),

            ),
          );
        }
        return;
      }

      // Check if user has completed interests (using AuthService)
      await AuthService.checkUserInterestsAndNavigate(
        context: context,
        uid: currentUser.uid,
        onLoadingEnd: _hideLoading,
      );
    } catch (e) {
      _hideLoading();
      debugPrint('❌ Error in auto-login check: $e');
    }
  }

  void _showLoading() {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
  }

  void _hideLoading() {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Google Sign In Function
  Future<void> _signInWithGoogle() async {
    // Check network
    if (!await AuthService.isNetworkAvailable()) {
      AuthService.showNoInternetDialog(context, onRetry: _signInWithGoogle);
      return;
    }

    try {
      _showLoading();

      // Clear any existing sign-in state
      await _googleSignIn.signOut();

      // Trigger Google Sign In
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        _hideLoading();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sign in was cancelled'),
              backgroundColor: Colors.grey,
            ),
          );
        }
        return;
      }

      // Get authentication details
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      // Create credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final UserCredential userCredential = await AuthService.auth
          .signInWithCredential(credential);

      if (userCredential.user != null) {
        await _saveUserToFirestore(userCredential.user!);
      }
    } catch (error) {
      _hideLoading();
      debugPrint('Google Sign In error: $error');
      _showSignInErrorDialog();
    }
  }

  // Show sign-in error dialog
  void _showSignInErrorDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign In Failed'),
        content: const Text(
          'Unable to sign in with Google. Please check your internet connection and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _signInWithGoogle();
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

  // Save user to Firestore
  Future<void> _saveUserToFirestore(User user) async {
    if (!await AuthService.isNetworkAvailable()) {
      AuthService.showNoInternetDialog(context);
      return;
    }

    final uid = user.uid;
    final name = user.displayName ?? '';
    final email = user.email ?? '';
    final now = DateTime.now().toUtc().toIso8601String();

    try {
      final docSnapshot = await _firestore.collection('users').doc(uid).get();

      Map<String, dynamic> userData = {
        'name': name,
        'email': email,
        'uid': uid,
        'profile_picture_url': '',
      };

      if (docSnapshot.exists) {
        debugPrint('✅ Existing user, updating last login');
        userData['last_login'] = now;

        await _firestore.collection('users').doc(uid).update(userData);
        debugPrint('User information updated successfully');
      } else {
        debugPrint('✅ New user, creating document');
        userData['joined_at'] = now;
        userData['last_login'] = now;
        userData['interests'] = '';

        await _firestore.collection('users').doc(uid).set(userData);
        debugPrint('User document created successfully');
      }

      // ✅ NOTIFICATION CODE — background එකේ run කරනවා (await නැහැ)
      final userName = user.displayName ?? 'there';
      final ns = NotificationService();
      ns.saveFcmToken(uid);
      ns.sendOnboardingNotifications(uid: uid, userName: userName);

      if (mounted) {
        await AuthService.checkUserInterestsAndNavigate(
          context: context,
          uid: uid,
          onLoadingEnd: _hideLoading,
        );
      }
    } catch (e) {
      _hideLoading();
      debugPrint('Error saving user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save user information'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      body: Stack(
        children: [
          // Main Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo Section
                  _buildLogoSection(),
                  const SizedBox(height: 64),

                  // Login Buttons
                  _buildLoginButtons(),
                  const SizedBox(height: 40),

                  // Register Link
                  _buildRegisterLink(),

                  const SizedBox(height: 24),

                  // Terms & Privacy
                  _buildTermsAndPrivacy(),
                ],
              ),
            ),
          ),

          // Loading Overlay
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        // App Icon / Logo
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFF3B5C),
                Color(0xFFFF6B35),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF3B5C).withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Stack(
            alignment: Alignment.center,
            children: [
              // Play button shape
              Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 44,
              ),
              // Small vibe wave indicator at bottom-right
              Positioned(
                right: 10,
                bottom: 10,
                child: Icon(
                  Icons.graphic_eq_rounded,
                  color: Colors.white70,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'Welcome to ',
              style: TextStyle(
                fontSize: 29,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.58,
              ),
            ),
            Text(
              'Vibe',
              style: TextStyle(
                fontSize: 32,
                color: Color(0xFFFF3B5C),
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
            ),
            Text(
              'Flick',
              style: TextStyle(
                fontSize: 32,
                color: Colors.white,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Text(
          'Login to share and explore short videos',
          style: TextStyle(fontSize: 16, color: Colors.grey[400], height: 1.2),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoginButtons() {
    return Column(
      children: [
        _buildGoogleLoginButton(onTap: _signInWithGoogle),
        const SizedBox(height: 16),
        _buildLoginButton(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LoginActivity()),
            );
          },
          icon: Icons.email_outlined,
          text: 'Login with Email',
          textColor: const Color(0xFFFF3B5C),
          borderColor: const Color(0xFFFF3B5C),
          iconColor: const Color(0xFFFF3B5C),
        ),
      ],
    );
  }

  // Official Google button with 4-color logo
  Widget _buildGoogleLoginButton({required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3A3A3A), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Official Google G logo using colored segments
            SizedBox(
              width: 24,
              height: 24,
              child: SvgPicture.asset(
                'assets/images/google-icon-logo-svgrepo-com.svg',
                width: 24,
                height: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Continue with Google',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginButton({
    required VoidCallback onTap,
    required IconData icon,
    required String text,
    required Color textColor,
    required Color borderColor,
    required Color iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                fontSize: 16,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
        ),
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RegisterActivity()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              'Register now',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFFFF3B5C),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Terms & Privacy section
  Widget _buildTermsAndPrivacy() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            height: 1.5,
          ),
          children: [
            const TextSpan(text: 'By continuing, you agree to our '),
            WidgetSpan(
              child: GestureDetector(
                onTap: () {
                  launchUrl(
                    Uri.parse(termsOfServiceUrl),
                    mode: LaunchMode.externalApplication,
                  );
                },
                child: const Text(
                  'Terms of Service',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFFF3B5C),
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const TextSpan(text: ' and '),
            WidgetSpan(
              child: GestureDetector(
                onTap: () {
                  launchUrl(
                    Uri.parse(privacyPolicyUrl),
                    mode: LaunchMode.externalApplication,
                  );
                },
                child: const Text(
                  'Privacy Policy',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFFF3B5C),
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const TextSpan(text: '.'),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Card(
          elevation: 8,
          color: const Color(0xFF2C2C2C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(minWidth: 200),
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFFF3B5C),
                          ),
                        ),
                      ),
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFF3B5C).withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Signing you in...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please wait',
                  style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                ),
                const SizedBox(height: 12),
                _buildAnimatedDots(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedDots() {
    return AnimatedBuilder(
      animation: _dotController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.33;
            final opacity = ((_dotController.value + delay) % 1.0) < 0.5
                ? 0.3
                : 1.0;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF3B5C).withOpacity(opacity),
              ),
            );
          }),
        );
      },
    );
  }
}

