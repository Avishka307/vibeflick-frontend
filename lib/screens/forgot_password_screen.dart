import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

/// 🔐 Forgot Password Screen
/// යූසර්ට පාස්වර්ඩ් එක අමතක වුණාම, ඊමේල් එකට reset link එකක් යවන screen එක
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// ✅ Validate email format
  bool _validateEmail(String email) {
    if (email.isEmpty) {
      _showError('Please enter your email address');
      return false;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      _showError('Please enter a valid email address');
      return false;
    }

    return true;
  }

  /// 📧 Send password reset email
  Future<void> _sendPasswordResetEmail() async {
    final email = _emailController.text.trim();

    // Validate email
    if (!_validateEmail(email)) {
      return;
    }

    // Check network connection
    if (!await AuthService.isNetworkAvailable()) {
      AuthService.showNoInternetDialog(context);
      return;
    }

    // Show loading state
    setState(() {
      _isLoading = true;
    });

    try {
      // 🔥 Firebase Password Reset Email එක යවනවා
      await AuthService.auth.sendPasswordResetEmail(email: email);

      debugPrint('✅ Password reset email sent to: $email');

      // Success state
      setState(() {
        _isLoading = false;
        _emailSent = true;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset link sent to $email'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });

      debugPrint('❌ Password reset error: ${e.code}');
      _handlePasswordResetError(e);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      debugPrint('❌ Unexpected error: $e');
      _showError('Failed to send password reset email. Please try again.');
    }
  }

  /// ⚠️ Handle Firebase errors
  void _handlePasswordResetError(FirebaseAuthException exception) {
    String errorMessage;

    switch (exception.code) {
      case 'user-not-found':
        errorMessage = 'No account found with this email address';
        break;
      case 'invalid-email':
        errorMessage = 'Invalid email address format';
        break;
      case 'network-request-failed':
        errorMessage = 'Network error. Please check your internet connection';
        break;
      case 'too-many-requests':
        errorMessage = 'Too many attempts. Please try again later';
        break;
      default:
        errorMessage = 'Failed to send reset email: ${exception.message}';
    }

    _showError(errorMessage);
  }

  /// 🔴 Show error message
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// 🔙 Go back to login
  void _goBackToLogin() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF333333)),
          onPressed: _goBackToLogin,
        ),
        title: const Text(
          'Reset Password',
          style: TextStyle(
            color: Color(0xFF333333),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // 🔒 Lock Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFF008DFF).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_reset,
                    size: 50,
                    color: Color(0xFF008DFF),
                  ),
                ),
                const SizedBox(height: 30),

                // Email එක යැව්වා නම් success view එක පෙන්වන්න
                if (_emailSent) ...[
                  _buildSuccessView(),
                ] else ...[
                  _buildEmailInputView(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ✅ Success View (Email එක යැව්වට පස්සේ පෙන්වන එක)
  Widget _buildSuccessView() {
    return Column(
      children: [
        // Success Icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_outline,
            size: 50,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 24),

        // Success Title
        const Text(
          'Check Your Email',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Success Message
        Text(
          'We sent a password reset link to:',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Email
        Text(
          _emailController.text.trim(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF008DFF),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Instructions
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFF008DFF),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Click the link in your email to reset your password',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.email_outlined,
                    color: Color(0xFF008DFF),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Check your spam folder if you don\'t see the email',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    color: Color(0xFF008DFF),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'The link will expire in 1 hour',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Resend Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              setState(() {
                _emailSent = false;
              });
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF008DFF)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              'Resend Email',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF008DFF),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Back to Login Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _goBackToLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF008DFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
            ),
            child: const Text(
              'Back to Login',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 📧 Email Input View (මුල් view එක)
  Widget _buildEmailInputView() {
    return Column(
      children: [
        // Title
        const Text(
          'Forgot Your Password?',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Description
        Text(
          'Enter your email address and we\'ll send you a link to reset your password',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),

        // Email Input Field
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE0E0E0),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 15.0,
              vertical: 5,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.email_outlined,
                  color: Color(0xFF666666),
                  size: 20,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      hintText: 'Enter your email',
                      hintStyle: TextStyle(
                        color: Color(0xFF999999),
                      ),
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF333333),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    maxLines: 1,
                    enabled: !_isLoading,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 30),

        // Send Reset Link Button
        Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: _isLoading ? null : _sendPasswordResetEmail,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 55,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue[600]!,
                    Colors.blue[800]!,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
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
                  'SEND RESET LINK',
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
        const SizedBox(height: 24),

        // Back to Login Link
        TextButton(
          onPressed: _goBackToLogin,
          child: const Text(
            'Back to Login',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF008DFF),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}