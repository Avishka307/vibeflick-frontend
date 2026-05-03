import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({Key? key}) : super(key: key);

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmationController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isDeleteButtonEnabled = false;
  bool _isLoading = false;
  String? _selectedReason;

  final List<String> _deleteReasons = [
    'I found another app',
    'Privacy concerns',
    'Too many notifications',
    'Not using it anymore',
    'Other',
  ];

  void _checkFormValidity() {
    setState(() {
      _isDeleteButtonEnabled =
          _passwordController.text.isNotEmpty &&
              _confirmationController.text.trim().toUpperCase() == 'DELETE';
    });
  }

  // 🔐 STEP 1: Re-authenticate user (CRITICAL!)
  Future<bool> _reauthenticateUser() async {
    try {
      print('🔐 Re-authenticating user...');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        _showErrorDialog('Authentication Error', 'No user logged in');
        return false;
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _passwordController.text.trim(),
      );

      await user.reauthenticateWithCredential(credential);

      print('✅ Re-authentication successful');
      return true;

    } on FirebaseAuthException catch (e) {
      print('❌ Re-authentication failed: ${e.code}');

      String errorMessage;
      if (e.code == 'wrong-password') {
        errorMessage = 'Incorrect password. Please try again.';
      } else if (e.code == 'user-not-found') {
        errorMessage = 'User not found.';
      } else if (e.code == 'too-many-requests') {
        errorMessage = 'Too many attempts. Please try again later.';
      } else {
        errorMessage = 'Authentication failed: ${e.message}';
      }

      _showErrorDialog('Authentication Failed', errorMessage);
      return false;

    } catch (e) {
      print('❌ Unexpected error: $e');
      _showErrorDialog('Error', 'An unexpected error occurred');
      return false;
    }
  }

  // 🗑️ STEP 2: Call backend to schedule deletion
  Future<bool> _scheduleDeletion() async {
    try {
      print('📡 Calling backend API to schedule deletion...');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final url = Uri.parse('https://avishka-tiktok-api.zeabur.app/api/account/schedule-deletion');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uid': user.uid,
          'email': user.email,
          'reason': _selectedReason ?? 'Not specified',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      print('📥 Backend response: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print('✅ Account scheduled for deletion');
          return true;
        }
      }

      _showErrorDialog('Error', 'Failed to schedule account deletion');
      return false;

    } catch (e) {
      print('❌ Backend API error: $e');
      _showErrorDialog('Network Error', 'Could not connect to server');
      return false;
    }
  }

  // 📧 STEP 3: Send confirmation email (optional but recommended)
  Future<void> _sendConfirmationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final url = Uri.parse('https://avishka-tiktok-api.zeabur.app/api/account/send-deletion-email');

      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uid': user.uid,
          'email': user.email,
        }),
      );

      print('📧 Confirmation email sent');

    } catch (e) {
      print('⚠️ Email sending failed (non-critical): $e');
    }
  }

  // 🚪 STEP 4: Sign out user
  Future<void> _signOutUser() async {
    try {
      await FirebaseAuth.instance.signOut();
      print('🚪 User signed out successfully');
    } catch (e) {
      print('⚠️ Sign out error: $e');
    }
  }

  // 🔥 MAIN DELETE FUNCTION
  void _proceedWithDeletion() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      // Step 1: Re-authenticate
      final isAuthenticated = await _reauthenticateUser();
      if (!isAuthenticated) {
        setState(() => _isLoading = false);
        return;
      }

      // Step 2: Schedule deletion via backend
      final isScheduled = await _scheduleDeletion();
      if (!isScheduled) {
        setState(() => _isLoading = false);
        return;
      }

      // Step 3: Send confirmation email
      await _sendConfirmationEmail();

      // Step 4: Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ Account scheduled for deletion. You have 30 days to recover.',
            ),
            backgroundColor: Color(0xFFDC143C),
            duration: Duration(seconds: 5),
          ),
        );
      }

      // Step 5: Sign out and navigate
      await Future.delayed(const Duration(seconds: 2));
      await _signOutUser();

      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login', // Replace with your login route
              (route) => false,
        );
      }

    } catch (e) {
      print('❌ Critical error in deletion process: $e');
      _showErrorDialog('Error', 'Account deletion failed. Please contact support.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showFinalConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFDC143C), width: 2),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFDC143C), size: 32),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Are you absolutely sure?',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This action cannot be undone. Your account will be scheduled for permanent deletion.',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
              SizedBox(height: 16),
              Text(
                '⏱️ You have 30 days to change your mind and reactivate your account.',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Keep Account',
                style: TextStyle(
                  color: Color(0xFF4CAF50),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _proceedWithDeletion();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC143C),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Yes, Delete',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFF4CAF50))),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Delete My Account',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Warning Box
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A0A0A),
                      border: Border.all(color: const Color(0xFFDC143C), width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Color(0xFFDC143C),
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '⚠️ WARNING ⚠️',
                          style: TextStyle(
                            color: Color(0xFFDC143C),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Deleting your account will permanently remove:',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        _buildDataLossItem('📸 All your photos and media'),
                        _buildDataLossItem('📝 All your posts and comments'),
                        _buildDataLossItem('👥 Your followers and connections'),
                        _buildDataLossItem('⭐ Saved items and favorites'),
                        _buildDataLossItem('💬 Message history'),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F1F1F),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFFD700)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.schedule, color: Color(0xFFFFD700), size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Grace Period: You have 30 days to reconsider and reactivate your account',
                                  style: TextStyle(
                                    color: Color(0xFFFFD700),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Reason Dropdown
                  const Text(
                    'Why are you leaving? (Optional)',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF3A3A3A)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedReason,
                        hint: const Text(
                          'Select a reason',
                          style: TextStyle(color: Colors.white38),
                        ),
                        dropdownColor: const Color(0xFF2A2A2A),
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        items: _deleteReasons.map((String reason) {
                          return DropdownMenuItem<String>(
                            value: reason,
                            child: Text(reason),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedReason = newValue;
                          });
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Danger Zone
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A0A0A),
                      border: Border.all(color: const Color(0xFFDC143C), width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '🚨 DANGER ZONE 🚨',
                          style: TextStyle(
                            color: Color(0xFFDC143C),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'To delete your account, please:',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Password Field
                        const Text(
                          '1. Enter your password',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Enter your password',
                            hintStyle: const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: const Color(0xFF2A2A2A),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFDC143C), width: 2),
                            ),
                            prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
                          ),
                          onChanged: (_) => _checkFormValidity(),
                        ),

                        const SizedBox(height: 20),

                        // Confirmation Field
                        const Text(
                          '2. Type "DELETE" to confirm',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _confirmationController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Type DELETE here',
                            hintStyle: const TextStyle(
                              color: Colors.white38,
                              letterSpacing: 0,
                            ),
                            filled: true,
                            fillColor: const Color(0xFF2A2A2A),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFDC143C), width: 2),
                            ),
                            prefixIcon: const Icon(Icons.warning_amber, color: Color(0xFFDC143C)),
                          ),
                          onChanged: (_) => _checkFormValidity(),
                        ),

                        const SizedBox(height: 24),

                        // Delete Button
                        ElevatedButton(
                          onPressed: _isDeleteButtonEnabled ? _showFinalConfirmationDialog : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isDeleteButtonEnabled
                                ? const Color(0xFFDC143C)
                                : const Color(0xFF3A3A3A),
                            disabledBackgroundColor: const Color(0xFF3A3A3A),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: _isDeleteButtonEnabled ? 8 : 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.delete_forever,
                                color: _isDeleteButtonEnabled ? Colors.white : Colors.white24,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'DELETE MY ACCOUNT',
                                style: TextStyle(
                                  color: _isDeleteButtonEnabled ? Colors.white : Colors.white24,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Cancel Button
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cancel_outlined, color: Color(0xFF4CAF50), size: 24),
                        SizedBox(width: 12),
                        Text(
                          'CANCEL - KEEP MY ACCOUNT',
                          style: TextStyle(
                            color: Color(0xFF4CAF50),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFDC143C)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Processing account deletion...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDataLossItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.close, color: Color(0xFFDC143C), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}