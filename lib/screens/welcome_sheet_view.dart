import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'verify_email_screen.dart';

/// 🎉 Welcome Sheet View
/// Google Sign-In සහ Email Login options පෙන්වන මුල් view එක
class WelcomeSheetView extends StatefulWidget {
  final VoidCallback onEmailLoginTap;
  final VoidCallback onRegisterTap;
  final VoidCallback onClose;

  const WelcomeSheetView({
    super.key,
    required this.onEmailLoginTap,
    required this.onRegisterTap,
    required this.onClose,
  });

  @override
  State<WelcomeSheetView> createState() => _WelcomeSheetViewState();
}

class _WelcomeSheetViewState extends State<WelcomeSheetView> {
  bool _isLoading = false;

  // Firebase instances
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Google Sign In Function
  Future<void> _signInWithGoogle() async {
    // Check network
    if (!await AuthService.isNetworkAvailable()) {
      AuthService.showNoInternetDialog(context, onRetry: _signInWithGoogle);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Clear any existing sign-in state
      await _googleSignIn.signOut();

      // Trigger Google Sign In
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        setState(() {
          _isLoading = false;
        });
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
      final UserCredential userCredential =
      await AuthService.auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        await _saveUserToFirestore(userCredential.user!);
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Google Sign In error: $error');
      _showSignInErrorDialog();
    }
  }

  /// Show sign-in error dialog
  void _showSignInErrorDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text(
          'Sign In Failed',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Unable to sign in with Google. Please check your internet connection and try again.',
          style: TextStyle(color: Color(0xFFAAAAAA)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _signInWithGoogle();
            },
            child: const Text(
              'Retry',
              style: TextStyle(color: Color(0xFFFF3B5C)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF888888)),
            ),
          ),
        ],
      ),
    );
  }

  /// Save user to Firestore
  Future<void> _saveUserToFirestore(User user) async {
    final uid = user.uid;
    final name = user.displayName ?? '';
    final email = user.email ?? '';
    final now = DateTime.now().toUtc().toIso8601String();

    try {
      // Check if user exists
      final docSnapshot = await _firestore.collection('users').doc(uid).get();

      Map<String, dynamic> userData = {
        'name': name,
        'email': email,
        'uid': uid,
        'profile_picture_url': '',
      };

      if (docSnapshot.exists) {
        // User exists - update last login
        userData['last_login'] = now;
        await _firestore.collection('users').doc(uid).update(userData);
      } else {
        // New user - create document
        userData['joined_at'] = now;
        userData['last_login'] = now;
        userData['interests'] = '';
        await _firestore.collection('users').doc(uid).set(userData);
      }

      // Check interests and navigate
      if (mounted) {
        widget.onClose(); // Close bottom sheet
        await AuthService.checkUserInterestsAndNavigate(
          context: context,
          uid: uid,
          onLoadingEnd: () {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
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
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1F1F1F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Bottom sheet drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A3A),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 28),

            // Logo Section
            _buildLogoSection(),
            const SizedBox(height: 40),

            // Loading or Login Buttons
            if (_isLoading)
              _buildLoadingIndicator()
            else ...[
              _buildLoginButtons(),
              const SizedBox(height: 24),
              _buildRegisterLink(),
            ],

            const SizedBox(height: 32),

            // Terms & Privacy
            _buildTermsAndPrivacy(),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        // App Icon / Logo
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
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
                blurRadius: 18,
                spreadRadius: 2,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 40,
              ),
              Positioned(
                right: 9,
                bottom: 9,
                child: Icon(
                  Icons.graphic_eq_rounded,
                  color: Colors.white70,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // App name
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Text(
              'Welcome to ',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const Text(
              'Vibe',
              style: TextStyle(
                fontSize: 28,
                color: Color(0xFFFF3B5C),
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'Flick',
              style: TextStyle(
                fontSize: 28,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Login to share and explore short videos',
          style: TextStyle(fontSize: 15, color: Colors.grey[400]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoginButtons() {
    return Column(
      children: [
        // Google Sign In Button — official 4-color logo
        InkWell(
          onTap: _signInWithGoogle,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF3A3A3A), width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CustomPaint(painter: GoogleLogoPainter()),
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
        ),
        const SizedBox(height: 16),

        // Email Login Button
        InkWell(
          onTap: widget.onEmailLoginTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFFF3B5C), width: 1.5),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.email_outlined,
                    color: Color(0xFFFF3B5C), size: 24),
                SizedBox(width: 12),
                Text(
                  'Login with Email',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFFFF3B5C),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
          onTap: widget.onRegisterTap,
          child: const Padding(
            padding: EdgeInsets.all(4.0),
            child: Text(
              'Register now',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFFFF3B5C),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsAndPrivacy() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                  // TODO: Navigate to Terms of Service page
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
                  // TODO: Navigate to Privacy Policy page
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

  Widget _buildLoadingIndicator() {
    return Column(
      children: [
        const SizedBox(
          width: 50,
          height: 50,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor:
            AlwaysStoppedAnimation<Color>(Color(0xFFFF3B5C)),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Signing you in...',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[300],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// Custom painter for the official Google G logo with 4 colors
class GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double radius = size.width / 2;

    const Color blue = Color(0xFF4285F4);
    const Color red = Color(0xFFEA4335);
    const Color yellow = Color(0xFFFBBC05);
    const Color green = Color(0xFF34A853);

    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = red;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      _toRadians(-230),
      _toRadians(115),
      true,
      paint,
    );

    paint.color = yellow;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      _toRadians(115),
      _toRadians(55),
      true,
      paint,
    );

    paint.color = green;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      _toRadians(170),
      _toRadians(95),
      true,
      paint,
    );

    paint.color = blue;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      _toRadians(-85),
      _toRadians(115),
      true,
      paint,
    );

    paint.color = blue;
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - radius * 0.2, radius, radius * 0.4),
      paint,
    );

    final innerPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF2C2C2C); // Match button background

    canvas.drawCircle(Offset(cx, cy), radius * 0.62, innerPaint);

    innerPaint.color = const Color(0xFF2C2C2C);
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - radius * 0.2, radius * 0.62, radius * 0.4),
      innerPaint,
    );
  }

  double _toRadians(double degrees) => degrees * 3.14159265 / 180;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}