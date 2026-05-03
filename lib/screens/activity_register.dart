import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'notification_service.dart';
import 'verify_email_screen.dart'; // ✅ Email verification screen import

class RegisterActivity extends StatefulWidget {
  const RegisterActivity({super.key});

  @override
  State<RegisterActivity> createState() => _RegisterActivityState();
}

class _RegisterActivityState extends State<RegisterActivity> {
  // Form Key — Global form validation
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
  TextEditingController();

  // Focus nodes for keyboard navigation
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmPasswordFocus = FocusNode();

  // Password visibility toggles
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  bool _termsAccepted = false;
  bool _isLoading = false;
  double _progress = 0.0;
  String _progressMessage = 'Initializing registration...';
  bool _isNavigating = false;

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Progress messages
  final List<String> _progressMessages = [
    'Initializing registration...',
    'Validating your information...',
    'Creating your account...',
    'Setting up your profile...',
    'Finalizing registration...',
  ];

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  // Validate all inputs
  bool _validateInputs(String fullName, String email, String phone,
      String password, String confirmPassword) {
    if (fullName.isEmpty) {
      _showError('Full name is required');
      return false;
    }
    if (fullName.length < 2) {
      _showError('Please enter a valid full name');
      return false;
    }
    if (email.isEmpty) {
      _showError('Email is required');
      return false;
    }
    if (phone.isEmpty) {
      _showError('Phone number is required');
      return false;
    }
    if (password.isEmpty) {
      _showError('Password is required');
      return false;
    }
    if (confirmPassword.isEmpty) {
      _showError('Please confirm your password');
      return false;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      _showError('Please enter a valid email address');
      return false;
    }
    if (password.length < 6) {
      _showError('Password must be at least 6 characters');
      return false;
    }
    if (password != confirmPassword) {
      _showError('Passwords do not match');
      return false;
    }

    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.length < 10) {
      _showError('Please enter a valid phone number (at least 10 digits)');
      return false;
    }
    if (!_termsAccepted) {
      _showError('Please accept Terms & Conditions to continue');
      return false;
    }

    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Register user
  Future<void> _registerUser() async {
    final fullName = _fullNameController.text.trim();
    // 4. Email lowercase — case sensitivity fix
    final email = _emailController.text.trim().toLowerCase();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (!_validateInputs(fullName, email, phone, password, confirmPassword)) {
      return;
    }

    if (!await AuthService.isNetworkAvailable()) {
      AuthService.showNoInternetDialog(context);
      return;
    }

    // 3. Phone uniqueness check before registration
    final phoneExists = await _checkPhoneExists(phone);
    if (phoneExists) {
      _showError(
          'This phone number is already registered. Please use a different number.');
      return;
    }

    _showProgressAnimation();
    // ✅ SPEED FIX: 500ms delay remove කළා
    await _startRegistrationProcess(fullName, email, phone, password);
  }

  // 3. Check if phone number already exists in Firestore
  Future<bool> _checkPhoneExists(String phone) async {
    try {
      final String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      final query = await _firestore
          .collection('users')
          .where('phone_number', isEqualTo: cleanPhone)
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Phone check error: $e');
      return false; // Don't block registration on check failure
    }
  }

  void _showProgressAnimation() {
    setState(() {
      _isLoading = true;
      _progress = 0.0;
      _progressMessage = _progressMessages[0];
    });
    _animateProgress();
  }

  void _animateProgress() {
    const steps = 100;
    const stepDuration = Duration(milliseconds: 50);
    int currentStep = 0;

    void updateProgress() {
      if (currentStep <= steps && mounted && _isLoading) {
        setState(() {
          _progress = currentStep / steps;
          if (_progress < 0.20) {
            _progressMessage = _progressMessages[0];
          } else if (_progress < 0.40) {
            _progressMessage = _progressMessages[1];
          } else if (_progress < 0.60) {
            _progressMessage = _progressMessages[2];
          } else if (_progress < 0.80) {
            _progressMessage = _progressMessages[3];
          } else {
            _progressMessage = _progressMessages[4];
          }
        });
        currentStep++;
        Future.delayed(stepDuration, updateProgress);
      }
    }

    updateProgress();
  }

  Future<void> _startRegistrationProcess(
      String fullName, String email, String phone, String password) async {
    debugPrint('Starting registration process for email: $email');

    UserCredential? userCredential;

    try {
      userCredential = await AuthService.auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      debugPrint('Firebase Auth registration successful');

      if (userCredential.user != null) {
        await _saveUserToFirestore(userCredential.user!, fullName, phone);
      } else {
        debugPrint('FirebaseUser is null after successful registration');
        _onRegistrationError(Exception('User creation failed'));
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth registration failed: ${e.code}');
      _onRegistrationError(e);
    } catch (e) {
      debugPrint('Registration error: $e');

      // 2. Orphaned account cleanup — Firestore fail වුණොත් Auth user delete
      if (userCredential?.user != null) {
        try {
          await userCredential!.user!.delete();
          debugPrint('🧹 Orphaned Auth account deleted');
        } catch (deleteError) {
          debugPrint('❌ Could not delete orphaned account: $deleteError');
        }
      }

      _onRegistrationError(Exception(e.toString()));
    }
  }

  Future<void> _saveUserToFirestore(
      User firebaseUser, String fullName, String phone) async {
    debugPrint('Starting to save user to Firestore');

    final now = DateTime.now().toUtc().toIso8601String();
    final String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    Map<String, Object> userData = {
      'uid': firebaseUser.uid,
      'name': fullName,
      'email': firebaseUser.email ?? '',
      'phone_number': cleanPhone,
      'profile_url': '',
      'joined_at': now,
      'interests': '',
      'isActive': true,
      'lastUpdated': now,
    };

    await _saveWithRetry(firebaseUser, userData, 0);
  }

  Future<void> _saveWithRetry(
      User firebaseUser, Map<String, Object> userData, int retryCount) async {
    const maxRetries = 3;

    try {
      await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .set(userData, SetOptions(merge: true));

      debugPrint('✅ User data saved to Firestore successfully');

      // ✅ SPEED FIX: 1 second delay remove කළා
      await _verifyDataSaved(firebaseUser.uid);
    } catch (e) {
      debugPrint(
          '❌ Error saving to Firestore (attempt ${retryCount + 1}): $e');

      if (retryCount < maxRetries - 1) {
        // ✅ SPEED FIX: retry delay අඩු කළා
        await Future.delayed(const Duration(milliseconds: 500));
        debugPrint('Retrying save operation...');
        await _saveWithRetry(firebaseUser, userData, retryCount + 1);
      } else {
        debugPrint('Max retries reached. Cleaning up orphaned auth account...');

        // 2. Orphaned account cleanup on max retries
        try {
          await firebaseUser.delete();
          debugPrint('🧹 Orphaned Auth account deleted after max retries');
        } catch (deleteError) {
          debugPrint('❌ Could not delete orphaned account: $deleteError');
        }

        _onRegistrationError(Exception(e.toString()));
      }
    }
  }

  Future<void> _verifyDataSaved(String uid) async {
    debugPrint('Verifying data was saved for UID: $uid');

    try {
      final docSnapshot =
      await _firestore.collection('users').doc(uid).get();

      if (docSnapshot.exists) {
        debugPrint('✅ Data verification successful');
        final data = docSnapshot.data();

        if (data != null &&
            data.containsKey('name') &&
            data.containsKey('email')) {
          debugPrint('All required fields verified');

          // ✅ FIX: getCurrentUser() වෙනුවට uid parameter එකම use කරනවා
          final user = AuthService.auth.currentUser;

          // ✅ FIX: UID match වෙනවාද confirm කරනවා
          if (user == null || user.uid != uid) {
            debugPrint('❌ UID mismatch! Expected: $uid, Got: ${user?.uid}');
            _onRegistrationError(Exception('User authentication mismatch'));
            return;
          }

          if (!user.emailVerified) {
            await user.sendEmailVerification();
            debugPrint('📧 Verification email sent to: ${user.email}');

            // ✅ SPEED FIX: background එකේ run කරනවා (await නැහැ)
            final userName = _fullNameController.text.trim();
            final ns = NotificationService();
            ns.saveFcmToken(uid);
            ns.sendOnboardingNotifications(uid: uid, userName: userName);

            if (mounted) {
              setState(() {
                _isLoading = false;
              });

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const VerifyEmailScreen(),
                ),
              );
            }
          } else {
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
        } else {
          debugPrint('❌ Required fields missing in saved document');
          _onRegistrationError(Exception('Data verification failed'));
        }
      } else {
        debugPrint('❌ Document was not saved!');
        _onRegistrationError(Exception('Document not found after save'));
      }
    } catch (e) {
      debugPrint('❌ Error verifying saved data: $e');
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
  }

  void _onRegistrationError(Exception exception) {
    _isNavigating = false;
    debugPrint('Registration error occurred: $exception');

    if (mounted) {
      setState(() {
        _isLoading = false;
        _progress = 0.0;
      });
    }

    String errorMessage = _getAuthErrorMessage(exception);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  String _getAuthErrorMessage(Exception exception) {
    String msg = exception.toString().toLowerCase();

    if (msg.contains('email') && msg.contains('already in use')) {
      return 'This email is already registered. Please use a different email.';
    }
    if (msg.contains('weak-password') || msg.contains('weak password')) {
      return 'Password is too weak. Please choose a stronger password (at least 6 characters).';
    }
    if (msg.contains('badly formatted') ||
        msg.contains('invalid email') ||
        msg.contains('invalid-email')) {
      return 'Invalid email format. Please enter a valid email address.';
    }
    if (msg.contains('network error') ||
        msg.contains('network is unreachable')) {
      return 'Network error. Please check your internet connection and try again.';
    }
    if (msg.contains('too many requests')) {
      return 'Too many attempts. Please try again after a few minutes.';
    }
    if (msg.contains('email-already-in-use')) {
      return 'This email is already registered. Please use a different email or try logging in.';
    }
    if (msg.contains('database') || msg.contains('firestore')) {
      return 'Database error. Please try again later.';
    }

    return 'Registration failed: ${exception.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 80),

                  // App Logo/Title Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Vibe',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF3B5C),
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
                  const SizedBox(height: 20),

                  // Subtitle
                  Text(
                    'Create account to share your creativity',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Progress Section
                  if (_isLoading)
                    Column(
                      children: [
                        Text(
                          _progressMessage,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFFFF3B5C),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _progress,
                            minHeight: 8,
                            backgroundColor: const Color(0xFF3A3A3A),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFFF3B5C),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${(_progress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),

                  // Full Name Input
                  _buildInputField(
                    controller: _fullNameController,
                    icon: Icons.person_outline,
                    hint: 'Full Name',
                    inputType: TextInputType.name,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) =>
                        FocusScope.of(context).requestFocus(_emailFocus),
                  ),
                  const SizedBox(height: 15),

                  // Email Input
                  _buildInputField(
                    controller: _emailController,
                    focusNode: _emailFocus,
                    icon: Icons.email_outlined,
                    hint: 'Email Address',
                    inputType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) =>
                        FocusScope.of(context).requestFocus(_phoneFocus),
                  ),
                  const SizedBox(height: 15),

                  // Phone Number Input
                  _buildInputField(
                    controller: _phoneController,
                    focusNode: _phoneFocus,
                    icon: Icons.phone_outlined,
                    hint: 'Phone Number',
                    inputType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) =>
                        FocusScope.of(context).requestFocus(_passwordFocus),
                  ),
                  const SizedBox(height: 15),

                  // Password Input
                  _buildInputField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    icon: Icons.lock_outline,
                    hint: 'Password',
                    isPassword: true,
                    isPasswordVisible: _passwordVisible,
                    onTogglePassword: () {
                      setState(() => _passwordVisible = !_passwordVisible);
                    },
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => FocusScope.of(context)
                        .requestFocus(_confirmPasswordFocus),
                  ),
                  const SizedBox(height: 15),

                  // Confirm Password Input
                  _buildInputField(
                    controller: _confirmPasswordController,
                    focusNode: _confirmPasswordFocus,
                    icon: Icons.lock_clock_outlined,
                    hint: 'Confirm Password',
                    isPassword: true,
                    isPasswordVisible: _confirmPasswordVisible,
                    onTogglePassword: () {
                      setState(() =>
                      _confirmPasswordVisible = !_confirmPasswordVisible);
                    },
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _registerUser(),
                  ),
                  const SizedBox(height: 20),

                  // Terms & Conditions
                  Row(
                    children: [
                      Checkbox(
                        value: _termsAccepted,
                        onChanged: (value) {
                          setState(() {
                            _termsAccepted = value ?? false;
                          });
                        },
                        activeColor: const Color(0xFFFF3B5C),
                        checkColor: Colors.white,
                        side: const BorderSide(
                            color: Color(0xFF3A3A3A), width: 1.5),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'I agree to the Terms & Conditions and Privacy Policy',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),

                  // Register Button — 6. Greyed out when loading
                  Material(
                    elevation: _isLoading ? 0 : 2,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: _isLoading ? null : _registerUser,
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 55,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isLoading
                                ? [
                              const Color(0xFFFF3B5C).withOpacity(0.4),
                              const Color(0xFFCC1F3E).withOpacity(0.4),
                            ]
                                : [
                              const Color(0xFFFF3B5C),
                              const Color(0xFFCC1F3E),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _isLoading
                              ? []
                              : [
                            BoxShadow(
                              color: const Color(0xFFFF3B5C)
                                  .withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isLoading
                              ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                              : const Text(
                            'CREATE ACCOUNT',
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
                  const SizedBox(height: 30),

                  // Bottom Section
                  Column(
                    children: [
                      Text(
                        'Already have an account?',
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
                            'Login',
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
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    FocusNode? focusNode,
    required IconData icon,
    required String hint,
    TextInputType inputType = TextInputType.text,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onTogglePassword,
    TextInputAction textInputAction = TextInputAction.next,
    ValueChanged<String>? onSubmitted,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A3A3A), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 5),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey[500], size: 20),
            const SizedBox(width: 15),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(color: Color(0xFF666666)),
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 16, color: Colors.white),
                keyboardType: inputType,
                obscureText: isPassword && !isPasswordVisible,
                maxLines: 1,
                textInputAction: textInputAction,
                onSubmitted: onSubmitted,
              ),
            ),
            // 1. Password visibility toggle
            if (isPassword && onTogglePassword != null)
              GestureDetector(
                onTap: onTogglePassword,
                child: Icon(
                  isPasswordVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: isPasswordVisible
                      ? const Color(0xFFFF3B5C)
                      : Colors.grey[600],
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
}