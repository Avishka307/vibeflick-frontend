import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({Key? key}) : super(key: key);

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  // Password strength
  double _passwordStrength = 0.0;
  String _passwordStrengthText = '';
  Color _passwordStrengthColor = Colors.grey;

  // Internet connection
  bool _hasInternetConnection = true;
  bool _showNoInternetToast = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // 🆕 Backend URL - CHANGE THIS TO YOUR SERVER URL
  static const String SERVER_URL = 'https://avishka-tiktok-api.zeabur.app'; // Android Emulator


  @override
  void initState() {
    super.initState();
    _checkInternetConnection();
    _listenToConnectivityChanges();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  // 🆕 Check internet connectivity
  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        if (mounted) {
          setState(() {
            _hasInternetConnection = true;
          });
        }
        return true;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasInternetConnection = false;
        });
        _showNoInternetConnection();
      }
      return false;
    }
    return false;
  }

  // Listen to connectivity changes
  void _listenToConnectivityChanges() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      final hasConnection = !result.contains(ConnectivityResult.none);

      if (mounted) {
        setState(() {
          _hasInternetConnection = hasConnection;
        });

        if (!hasConnection) {
          _showNoInternetConnection();
        }
      }
    });
  }

  // 🆕 Show "No Internet" toast
  void _showNoInternetConnection() {
    if (!_showNoInternetToast && mounted) {
      setState(() {
        _showNoInternetToast = true;
        _hasInternetConnection = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.wifi_off, color: Colors.white),
              SizedBox(width: 12),
              Text('No internet connection'),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(top: 50, left: 16, right: 16),
        ),
      );

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showNoInternetToast = false;
          });
        }
      });
    }
  }

  // Calculate password strength
  void _calculatePasswordStrength(String password) {
    if (password.isEmpty) {
      setState(() {
        _passwordStrength = 0.0;
        _passwordStrengthText = '';
        _passwordStrengthColor = Colors.grey;
      });
      return;
    }

    double strength = 0.0;

    // Length check
    if (password.length >= 8) strength += 0.2;
    if (password.length >= 12) strength += 0.1;

    // Contains lowercase
    if (password.contains(RegExp(r'[a-z]'))) strength += 0.2;

    // Contains uppercase
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.2;

    // Contains numbers
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.2;

    // Contains special characters
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength += 0.1;

    setState(() {
      _passwordStrength = strength;

      if (strength <= 0.3) {
        _passwordStrengthText = 'Weak';
        _passwordStrengthColor = Colors.red;
      } else if (strength <= 0.6) {
        _passwordStrengthText = 'Medium';
        _passwordStrengthColor = Colors.orange;
      } else {
        _passwordStrengthText = 'Strong';
        _passwordStrengthColor = Colors.green;
      }
    });
  }

  // 🔐 Handle password change with backend - ✅ FIXED VERSION
  Future<void> _handleChangePassword() async {
    print('\n🔐 ========== STARTING PASSWORD CHANGE ==========');

    // 1. Form Validation
    if (!_formKey.currentState!.validate()) {
      print('❌ Form validation failed');
      return;
    }

    // 2. Internet Check
    print('🌐 Checking internet connection...');
    final hasInternet = await _checkInternetConnection();
    if (!hasInternet) {
      print('❌ No internet connection');
      _showNoInternetConnection();
      return;
    }
    print('✅ Internet connection OK');

    setState(() {
      _isLoading = true;
    });

    try {
      print('👤 Getting current Firebase user...');
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not found");
      }
      print('✅ Current user: ${user.email}');

      // ============================================================
      // STEP A: Re-authenticate User (Current Password එක හරිද බැලීම)
      // ============================================================
      print('\n🔒 STEP A: Re-authenticating user...');
      print('   Email: ${user.email}');

      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text.trim(),
      );

      print('   Attempting re-authentication...');
      await user.reauthenticateWithCredential(credential);
      print('✅ Re-authentication successful!');

      // ============================================================
      // STEP B: Call Backend API
      // ============================================================
      print('\n📡 STEP B: Calling backend API...');
      print('   Server URL: $SERVER_URL/api/change-password');
      print('   UID: ${user.uid}');

      final response = await http.post(
        Uri.parse('$SERVER_URL/api/change-password'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'uid': user.uid,
          'currentPassword': _currentPasswordController.text.trim(),
          'newPassword': _newPasswordController.text.trim(),
        }),
      ).timeout(const Duration(seconds: 30));

      print('📥 Backend response received');
      print('   Status code: ${response.statusCode}');
      print('   Response body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ Backend password change successful!');

        // ✅ CRITICAL FIX: Clear controllers IMMEDIATELY after success
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();

        // Reset password strength indicator
        setState(() {
          _passwordStrength = 0.0;
          _passwordStrengthText = '';
          _passwordStrengthColor = Colors.grey;
          _isLoading = false;
        });

        if (mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Password changed successfully!'),
                ],
              ),
              backgroundColor: const Color(0xFF43E97B),
              duration: const Duration(seconds: 2),
            ),
          );

          print('🔙 Navigating back in 800ms...');

          // Navigate back after short delay
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              Navigator.pop(context);
            }
          });
        }
      } else {
        print('❌ Backend error: ${response.statusCode}');
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to change password');
      }

    } on FirebaseAuthException catch (e) {
      print('\n❌ ========== FIREBASE AUTH ERROR ==========');
      print('Error code: ${e.code}');
      print('Error message: ${e.message}');

      String errorMessage = 'Error changing password';
      if (e.code == 'wrong-password') {
        errorMessage = 'Current password is incorrect';
      } else if (e.code == 'user-not-found') {
        errorMessage = 'User not found';
      } else if (e.code == 'too-many-requests') {
        errorMessage = 'Too many attempts. Please try again later';
      } else if (e.code == 'network-request-failed') {
        errorMessage = 'Network error. Please check your connection';
      } else if (e.code == 'requires-recent-login') {
        errorMessage = 'Please log in again and try';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: const Color(0xFFFF3B5C),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } on TimeoutException {
      print('\n❌ ========== TIMEOUT ERROR ==========');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request timed out. Please try again'),
            backgroundColor: Color(0xFFFF3B5C),
          ),
        );
      }
    } on SocketException {
      print('\n❌ ========== NETWORK ERROR ==========');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No internet connection'),
            backgroundColor: Color(0xFFFF3B5C),
          ),
        );
      }
    } catch (e) {
      print('\n❌ ========== GENERAL ERROR ==========');
      print('Error: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: const Color(0xFFFF3B5C),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      print('==========================================\n');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Change Password',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              // Current Password
              const Text(
                'Current Password',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrentPassword,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  hintText: 'Enter current password',
                  hintStyle: const TextStyle(color: Colors.white38),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCurrentPassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white54,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureCurrentPassword = !_obscureCurrentPassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your current password';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // New Password
              const Text(
                'New Password',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNewPassword,
                style: const TextStyle(color: Colors.white),
                onChanged: _calculatePasswordStrength,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  hintText: 'Enter new password',
                  hintStyle: const TextStyle(color: Colors.white38),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white54,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureNewPassword = !_obscureNewPassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a new password';
                  }
                  if (value.length < 8) {
                    return 'Password must be at least 8 characters';
                  }
                  if (!value.contains(RegExp(r'[A-Z]'))) {
                    return 'Password must contain at least one uppercase letter';
                  }
                  if (!value.contains(RegExp(r'[a-z]'))) {
                    return 'Password must contain at least one lowercase letter';
                  }
                  if (!value.contains(RegExp(r'[0-9]'))) {
                    return 'Password must contain at least one number';
                  }
                  return null;
                },
              ),

              // Password strength indicator
              if (_newPasswordController.text.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _passwordStrength,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation<Color>(_passwordStrengthColor),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _passwordStrengthText,
                      style: TextStyle(
                        color: _passwordStrengthColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use uppercase, lowercase, numbers & symbols',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Confirm Password
              const Text(
                'Confirm New Password',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  hintText: 'Re-enter new password',
                  hintStyle: const TextStyle(color: Colors.white38),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white54,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your new password';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 40),

              // Change Password Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleChangePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3B5C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Text(
                    'Change Password',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                            fontWeight: FontWeight.w600,
                    ),
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