import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_vibe_flick/screens/activity_login.dart';
import 'package:my_vibe_flick/screens/activity_register.dart';
import '../services/auth_service.dart';
import '../main.dart';


class LoginPageActivity extends StatefulWidget {
  const LoginPageActivity({super.key});

  @override
  State<LoginPageActivity> createState() => _LoginPageActivityState();
}

class _LoginPageActivityState extends State<LoginPageActivity>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _dotController;

  // Google Sign In instance
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>['email'],
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  void _showLoading() {
    if (mounted) setState(() => _isLoading = true);
  }

  void _hideLoading() {
    if (mounted) setState(() => _isLoading = false);
  }

  // Google Sign In Function
  Future<void> _signInWithGoogle() async {
    try {
      _showLoading();

      // Clear previous sign-in state
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        _hideLoading();
        return;
      }

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
      await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        // Save/update user in Firestore then navigate via AuthService
        await _saveUserToFirestore(userCredential.user!);
      } else {
        _hideLoading();
      }
    } catch (error) {
      _hideLoading();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Sign In failed: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ FIX: set() + merge:true — document නැත්නම් create, ඉන්නවා නම් update
  // ✅ FIX: AuthService.checkUserInterestsAndNavigate — interests check + navigate
  Future<void> _saveUserToFirestore(User user) async {
    final uid = user.uid;
    final name = user.displayName ?? '';
    final email = user.email ?? '';
    final now = DateTime.now().toUtc().toIso8601String();

    try {
      // Document exists check
      final docSnapshot =
      await _firestore.collection('users').doc(uid).get();

      if (docSnapshot.exists) {
        // ✅ Existing user — last_login update only, interests preserve
        await _firestore.collection('users').doc(uid).set(
          {
            'name': name,
            'email': email,
            'uid': uid,
            'last_login': now,
            'profile_picture_url':
            docSnapshot.data()?['profile_picture_url'] ?? '',
          },
          SetOptions(merge: true), // ← merge:true, existing fields safe
        );
        debugPrint('✅ Existing Google user — last_login updated');
      } else {
        // ✅ New user — full document create with empty interests
        await _firestore.collection('users').doc(uid).set(
          {
            'name': name,
            'email': email,
            'uid': uid,
            'profile_picture_url': '',
            'joined_at': now,
            'last_login': now,
            'interests': '', // empty → interest selection screen යනවා
          },
          SetOptions(merge: true),
        );
        debugPrint('✅ New Google user — document created');
      }

      // ✅ AuthService: interests check කරලා navigate කරනවා
      if (mounted) {
        await AuthService.checkUserInterestsAndNavigate(
          context: context,
          uid: uid,
          onLoadingEnd: _hideLoading,
        );
      }
    } catch (e) {
      _hideLoading();
      debugPrint('❌ Error saving Google user: $e');
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
                  _buildLogoSection(),
                  const SizedBox(height: 64),
                  _buildLoginButtons(),
                  const SizedBox(height: 40),
                  _buildRegisterLink(),
                  const SizedBox(height: 24),
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
              Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 44),
              Positioned(
                right: 10,
                bottom: 10,
                child: Icon(Icons.graphic_eq_rounded, color: Colors.white70, size: 18),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: const [
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
          child: const Padding(
            padding: EdgeInsets.all(4.0),
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

  Widget _buildTermsAndPrivacy() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.5),
          children: [
            const TextSpan(text: 'By continuing, you agree to our '),
            WidgetSpan(
              child: GestureDetector(
                onTap: () {},
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
                onTap: () {},
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      const SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF3B5C)),
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
                  style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text('Please wait', style: TextStyle(fontSize: 14, color: Colors.grey[400])),
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
            final opacity =
            ((_dotController.value + delay) % 1.0) < 0.5 ? 0.3 : 1.0;
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
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        _toRadians(-230), _toRadians(115), true, paint);

    paint.color = yellow;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        _toRadians(115), _toRadians(55), true, paint);

    paint.color = green;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        _toRadians(170), _toRadians(95), true, paint);

    paint.color = blue;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        _toRadians(-85), _toRadians(115), true, paint);

    paint.color = blue;
    canvas.drawRect(
        Rect.fromLTWH(cx, cy - radius * 0.2, radius, radius * 0.4), paint);

    final innerPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF2C2C2C);

    canvas.drawCircle(Offset(cx, cy), radius * 0.62, innerPaint);
    canvas.drawRect(
        Rect.fromLTWH(cx, cy - radius * 0.2, radius * 0.62, radius * 0.4),
        innerPaint);
  }

  double _toRadians(double degrees) => degrees * 3.14159265 / 180;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}