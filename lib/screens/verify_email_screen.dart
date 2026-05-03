import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../services/auth_service.dart';

/// 📧 Email Verification Screen
/// User එක ලොගින් වුණ ගමන්ම මේ screen එකට redirect වෙනවා
/// Email verify කරනකම් ඇප් එකේ කිසිම feature එකක් use කරන්න බෑ
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with WidgetsBindingObserver {
  Timer? _verificationTimer;
  Timer? _resendTimer;

  // _isChecking is now ONLY used for manual button press — not periodic timer
  bool _isChecking = false;
  bool _canResend = true;
  int _resendCooldown = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Lifecycle observer

    // ✅ FIX: initState එකේදී email send කරන්නේ නැහැ
    // RegisterActivity ලා already send කරලා තියෙනවා
    // ඒකයි too-many-requests error එන්නේ
    // ඒ වෙනුවට cooldown set කරලා resend disable කරනවා
    _setCooldownAfterRegistration();

    _startVerificationCheck();
  }

  /// ✅ FIX: Registration flow එකෙන් ආවාම email already sent
  /// ඒකට 60s cooldown set කරනවා — user-ට confuse නෑ
  void _setCooldownAfterRegistration() {
    setState(() {
      _canResend = false;
      _resendCooldown = 60;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown > 0) {
        setState(() {
          _resendCooldown--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remove observer
    _verificationTimer?.cancel();
    _resendTimer?.cancel();
    super.dispose();
  }

  /// 📱 App Resume — user email app එකෙන් ආපහු ආවාම immediately check කරනවා
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _silentVerificationCheck(); // Silent — no loading UI
    }
  }

  /// 🔄 සෑම තත්පර 3කට වතාවක් silently check කරනවා (UI jumpy වෙන්නේ නැහැ)
  void _startVerificationCheck() {
    _verificationTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) async {
          await _silentVerificationCheck();
        });
  }

  /// ✅ Silent background check — UI loading state වෙනස් කරන්නේ නැහැ
  Future<void> _silentVerificationCheck() async {
    try {
      final user = AuthService.getCurrentUser();

      if (user == null) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
        return;
      }

      await user.reload();
      final updatedUser = AuthService.getCurrentUser();

      if (updatedUser != null && updatedUser.emailVerified) {
        debugPrint('✅ Email verified! Redirecting to interests...');
        _verificationTimer?.cancel();

        if (mounted) {
          await AuthService.checkUserInterestsAndNavigate(
            context: context,
            uid: updatedUser.uid,
            onLoadingEnd: () {},
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking email verification: $e');
    }
  }

  /// ✅ Manual check — "I've Verified My Email" බටන් press කළාම loading UI පෙන්වනවා
  Future<void> _checkEmailVerified() async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
    });

    try {
      final user = AuthService.getCurrentUser();

      if (user == null) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
        return;
      }

      await user.reload();
      final updatedUser = AuthService.getCurrentUser();

      if (updatedUser != null && updatedUser.emailVerified) {
        debugPrint('✅ Email verified! Redirecting to interests...');
        _verificationTimer?.cancel();

        if (mounted) {
          await AuthService.checkUserInterestsAndNavigate(
            context: context,
            uid: updatedUser.uid,
            onLoadingEnd: () {},
          );
        }
      } else {
        // Not verified yet — show snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Email not verified yet. Please check your inbox.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking email verification: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  /// 📧 Email verification link එක යවනවා
  /// ✅ FIX: too-many-requests සහ අනිත් errors properly handle කරනවා
  Future<void> _sendVerificationEmail() async {
    try {
      final user = AuthService.getCurrentUser();

      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        debugPrint('✅ Verification email sent to: ${user.email}');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Verification email sent to ${user.email}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ FirebaseAuthException sending verification email: ${e.code}');

      if (!mounted) return;

      // ✅ FIX: too-many-requests — friendly message, no crash
      if (e.code == 'too-many-requests') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Verification email was already sent. Please check your inbox or spam folder.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to send verification email. Please try again. (${e.code})'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error sending verification email: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Failed to send verification email. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 🔄 Resend verification email (with cooldown)
  Future<void> _resendVerificationEmail() async {
    if (!_canResend) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Please wait $_resendCooldown seconds before resending'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _canResend = false;
      _resendCooldown = 60;
    });

    await _sendVerificationEmail();

    _resendTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          if (_resendCooldown > 0) {
            setState(() {
              _resendCooldown--;
            });
          } else {
            setState(() {
              _canResend = true;
            });
            timer.cancel();
          }
        });
  }

  /// 🚪 Logout කරන function
  Future<void> _logout() async {
    try {
      await AuthService.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      debugPrint('❌ Logout error: $e');
    }
  }

  /// ✉️ Change email — logout කරලා register page එකට යවනවා
  Future<void> _changeEmail() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text(
          'Change Email?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'You will be logged out. Please register again with the correct email address.',
          style: TextStyle(color: Color(0xFFAAAAAA)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF888888)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout & Change',
              style: TextStyle(color: Color(0xFFFF3B5C)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.getCurrentUser();

    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _logout,
            child: const Text(
              'Logout',
              style: TextStyle(
                color: Color(0xFFFF3B5C),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Email Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B5C).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.email_outlined,
                  size: 60,
                  color: Color(0xFFFF3B5C),
                ),
              ),
              const SizedBox(height: 40),

              // Title
              const Text(
                'Verify Your Email',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                'We sent a verification link to:',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[400],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Email
              Text(
                user?.email ?? '',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFF3B5C),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Change Email link
              GestureDetector(
                onTap: _changeEmail,
                child: Text(
                  'Wrong email? Change it',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.grey[500],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Instructions
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2C),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF3A3A3A),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFFFF3B5C),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Click the link in your email to verify your account',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.refresh,
                          color: Color(0xFFFF3B5C),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'This page will automatically update when verified',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Checking Status — ONLY shown during manual button press
              if (_isChecking)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFFF3B5C),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Checking verification status...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),

              // Resend Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed:
                  _canResend ? _resendVerificationEmail : null,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _canResend
                          ? const Color(0xFFFF3B5C)
                          : const Color(0xFF3A3A3A),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: _canResend
                        ? const Color(0xFFFF3B5C).withOpacity(0.08)
                        : Colors.transparent,
                  ),
                  child: Text(
                    _canResend
                        ? 'Resend Verification Email'
                        : 'Resend in $_resendCooldown seconds',
                    style: TextStyle(
                      fontSize: 16,
                      color: _canResend
                          ? const Color(0xFFFF3B5C)
                          : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Check Now Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isChecking ? null : _checkEmailVerified,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3B5C),
                    disabledBackgroundColor:
                    const Color(0xFFFF3B5C).withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shadowColor:
                    const Color(0xFFFF3B5C).withOpacity(0.4),
                  ),
                  child: const Text(
                    'I\'ve Verified My Email',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Help Text
              TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF2C2C2C),
                      title: const Text(
                        'Need Help?',
                        style: TextStyle(color: Colors.white),
                      ),
                      content: const Text(
                        'If you didn\'t receive the email:\n\n'
                            '1. Check your spam/junk folder\n'
                            '2. Make sure you entered the correct email\n'
                            '3. Wait a few minutes and try resending\n'
                            '4. Contact support if the problem persists',
                        style: TextStyle(color: Color(0xFFAAAAAA)),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'OK',
                            style: TextStyle(color: Color(0xFFFF3B5C)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                child: Text(
                  'Didn\'t receive the email?',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.grey[500],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}