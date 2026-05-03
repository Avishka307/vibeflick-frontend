import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'notification_service.dart';
import 'verify_email_screen.dart'; // ✅ Email verification screen import
import 'forgot_password_screen.dart'; // 🔐 Password reset screen import

class LoginActivity extends StatefulWidget {
  const LoginActivity({super.key});

  @override
  State<LoginActivity> createState() => _LoginActivityState();
}
class _LoginActivityState extends State<LoginActivity>
    with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Focus nodes for keyboard navigation
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _passwordVisible = false; // Show/Hide password toggle

  // Field error states
  String? _emailError;
  String? _passwordError;

  // Focus state for border color animation
  bool _emailFocused = false;
  bool _passwordFocused = false;

  late AnimationController _dotAnimationController;
  late AnimationController _rotationController;
  late Animation<double> _dot1Animation;
  late Animation<double> _dot2Animation;
  late Animation<double> _dot3Animation;
  late Animation<double> _dot4Animation;

  @override
  void initState() {
    super.initState();

    // Dot animation controller
    _dotAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    // Rotation animation controller
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    // Staggered dot animations
    _dot1Animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _dotAnimationController,
        curve: const Interval(0.0, 0.25, curve: Curves.easeInOut),
      ),
    );

    _dot2Animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _dotAnimationController,
        curve: const Interval(0.25, 0.5, curve: Curves.easeInOut),
      ),
    );

    _dot3Animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _dotAnimationController,
        curve: const Interval(0.5, 0.75, curve: Curves.easeInOut),
      ),
    );

    _dot4Animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _dotAnimationController,
        curve: const Interval(0.75, 1.0, curve: Curves.easeInOut),
      ),
    );

    // Focus listeners for border color animation
    _emailFocusNode.addListener(() {
      setState(() {
        _emailFocused = _emailFocusNode.hasFocus;
        if (_emailFocused) _emailError = null; // Clear error on focus
      });
    });

    _passwordFocusNode.addListener(() {
      setState(() {
        _passwordFocused = _passwordFocusNode.hasFocus;
        if (_passwordFocused) _passwordError = null; // Clear error on focus
      });
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _dotAnimationController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  // Validate input — now sets field-level errors instead of only SnackBar
  bool _validateInput(String email, String password) {
    bool valid = true;

    // Reset errors
    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    if (email.isEmpty) {
      setState(() => _emailError = 'Email address is required');
      valid = false;
    } else {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(email)) {
        setState(() => _emailError = 'Please enter a valid email address');
        valid = false;
      }
    }

    if (password.isEmpty) {
      setState(() => _passwordError = 'Password is required');
      valid = false;
    } else if (password.length < 6) {
      setState(() => _passwordError = 'Password must be at least 6 characters');
      valid = false;
    }

    return valid;
  }

  // Login user
  Future<void> _loginUser() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (!_validateInput(email, password)) {
      return;
    }

    if (!await AuthService.isNetworkAvailable()) {
      AuthService.showNoInternetDialog(context);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await AuthService.auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      debugPrint('signInWithEmail:success');

      if (userCredential.user != null) {
        final user = userCredential.user!;

        // ✅ EMAIL VERIFICATION CHECK
        if (!user.emailVerified) {
          setState(() {
            _isLoading = false;
          });

          debugPrint('❌ Email not verified for: ${user.email}');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please verify your email to continue'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const VerifyEmailScreen(),
              ),
            );
          }
          return;
        }

        // ✅ NOTIFICATION CODE — background එකේ run කරනවා (await නැහැ)
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final userName = userDoc.data()?['name'] as String? ?? 'there';

        final ns = NotificationService();
        ns.saveFcmToken(user.uid);
        ns.sendOnboardingNotifications(uid: user.uid, userName: userName);

        await AuthService.checkUserInterestsAndNavigate(
          context: context,
          uid: user.uid,
          onLoadingStart: () {
            if (mounted) setState(() => _isLoading = true);
          },
          onLoadingEnd: () {
            if (mounted) setState(() => _isLoading = false);
          },
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('signInWithEmail:failure - ${e.code}');
      _handleLoginError(e);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Login error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login error occurred'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Handle login errors
  void _handleLoginError(FirebaseAuthException exception) {
    String errorMessage = 'Login error occurred';

    switch (exception.code) {
      case 'user-not-found':
        errorMessage = 'No account found with this email address';
        setState(() => _emailError = errorMessage);
        break;
      case 'wrong-password':
        errorMessage = 'The password you entered is incorrect';
        setState(() => _passwordError = errorMessage);
        break;
      case 'invalid-credential':
        errorMessage = 'The password you entered is incorrect or has expired';
        setState(() => _passwordError = errorMessage);
        break;
      case 'network-request-failed':
        errorMessage =
        'Network connection error. Please check your internet connection';
        break;
      case 'too-many-requests':
        errorMessage = 'Too many attempts. Please try again later';
        break;
      default:
        errorMessage = 'Login error: ${exception.message}';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Border color based on focus/error state
  Color _fieldBorderColor(bool isFocused, String? error) {
    if (error != null) return Colors.red;
    if (isFocused) return const Color(0xFFFF3B5C);
    return const Color(0xFF3A3A3A);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Disable back button while loading
      canPop: !_isLoading,
      child: Scaffold(
        backgroundColor: const Color(0xFF1F1F1F),
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: AutofillGroup(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 80.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // App Title
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Vibe',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFFF3B5C),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  const Text(
                                    'Flick',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Login to share and explore short videos',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[400],
                                ),
                              ),
                              const SizedBox(height: 40),

                              // Email Input
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 30.0,
                                ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2C2C2C),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _fieldBorderColor(
                                          _emailFocused, _emailError),
                                      width: _emailFocused ? 2.0 : 1.5,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 15.0,
                                      vertical: 5,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.email_outlined,
                                          color: _emailFocused
                                              ? const Color(0xFFFF3B5C)
                                              : Colors.grey[500],
                                          size: 20,
                                        ),
                                        const SizedBox(width: 15),
                                        Expanded(
                                          child: TextField(
                                            controller: _emailController,
                                            focusNode: _emailFocusNode,
                                            autofillHints: const [
                                              AutofillHints.email
                                            ],
                                            textInputAction:
                                            TextInputAction.next,
                                            onSubmitted: (_) {
                                              FocusScope.of(context)
                                                  .requestFocus(
                                                  _passwordFocusNode);
                                            },
                                            decoration: const InputDecoration(
                                              hintText: 'Email Address',
                                              hintStyle: TextStyle(
                                                color: Color(0xFF666666),
                                              ),
                                              border: InputBorder.none,
                                              errorBorder: InputBorder.none,
                                            ),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Colors.white,
                                            ),
                                            keyboardType:
                                            TextInputType.emailAddress,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Email error text
                              if (_emailError != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 36.0, top: 6),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      _emailError!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ),

                              const SizedBox(height: 16),

                              // Password Input
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 30.0,
                                ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2C2C2C),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _fieldBorderColor(
                                          _passwordFocused, _passwordError),
                                      width: _passwordFocused ? 2.0 : 1.5,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 15.0,
                                      vertical: 5,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.lock_outline,
                                          color: _passwordFocused
                                              ? const Color(0xFFFF3B5C)
                                              : Colors.grey[500],
                                          size: 20,
                                        ),
                                        const SizedBox(width: 15),
                                        Expanded(
                                          child: TextField(
                                            controller: _passwordController,
                                            focusNode: _passwordFocusNode,
                                            autofillHints: const [
                                              AutofillHints.password
                                            ],
                                            textInputAction:
                                            TextInputAction.done,
                                            onSubmitted: (_) => _loginUser(),
                                            decoration: const InputDecoration(
                                              hintText: 'Password',
                                              hintStyle: TextStyle(
                                                color: Color(0xFF666666),
                                              ),
                                              border: InputBorder.none,
                                            ),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Colors.white,
                                            ),
                                            obscureText: !_passwordVisible,
                                            maxLines: 1,
                                          ),
                                        ),
                                        // Show/Hide Password Toggle
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _passwordVisible =
                                              !_passwordVisible;
                                            });
                                          },
                                          child: Icon(
                                            _passwordVisible
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            color: _passwordVisible
                                                ? const Color(0xFFFF3B5C)
                                                : Colors.grey[600],
                                            size: 20,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Password error text
                              if (_passwordError != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 36.0, top: 6),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      _passwordError!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ),

                              const SizedBox(height: 12),

                              // 🔐 Forgot Password Link
                              Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 30.0),
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                          const ForgotPasswordScreen(),
                                        ),
                                      );
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text(
                                        'Forgot Password?',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFFFF3B5C),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 15),

                              // Login Button
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 30.0,
                                ),
                                child: Material(
                                  elevation: 2,
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    onTap: _loginUser,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      height: 55,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFFF3B5C),
                                            Color(0xFFCC1F3E),
                                          ],
                                        ),
                                        borderRadius:
                                        BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFFF3B5C)
                                                .withOpacity(0.35),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'LOGIN',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Bottom Section
                  Padding(
                    padding: const EdgeInsets.only(bottom: 30.0),
                    child: Column(
                      children: [
                        Text(
                          "Don't have an account?",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 5),
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(10.0),
                            child: Text(
                              'Register now',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFFFF3B5C),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Loading Overlay
            if (_isLoading)
              Container(
                color: const Color(0xE6000000),
                child: Center(
                  child: Card(
                    elevation: 12,
                    color: const Color(0xFF2C2C2C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 280),
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Enhanced Progress Indicator
                          SizedBox(
                            width: 100,
                            height: 100,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Outer Ring
                                RotationTransition(
                                  turns: _rotationController,
                                  child: Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFFFF3B5C)
                                            .withOpacity(0.3),
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                ),
                                // Middle Ring
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFFF3B5C)
                                          .withOpacity(0.5),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                // Main Progress
                                const SizedBox(
                                  width: 70,
                                  height: 70,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFFFF3B5C),
                                    ),
                                  ),
                                ),
                                // Inner Circle
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFFF3B5C)
                                        .withOpacity(0.2),
                                  ),
                                ),
                                // Center Dot
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFFFF3B5C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Loading Text
                          const Text(
                            'Signing you in...',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                              letterSpacing: 0.02,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Loading Subtext
                          Text(
                            'Please wait while we verify your credentials',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[400],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),

                          // Loading Dots Animation
                          AnimatedBuilder(
                            animation: _dotAnimationController,
                            builder: (context, child) {
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildDot(_dot1Animation.value),
                                  _buildDot(_dot2Animation.value),
                                  _buildDot(_dot3Animation.value),
                                  _buildDot(_dot4Animation.value),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(double opacity) {
    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFF3B5C).withOpacity(opacity),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF3B5C).withOpacity(opacity * 0.5),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}