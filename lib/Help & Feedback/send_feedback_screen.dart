// lib/screens/settings/send_feedback_screen.dart

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:appwrite/appwrite.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SendFeedbackScreen extends StatefulWidget {
  const SendFeedbackScreen({Key? key}) : super(key: key);

  @override
  State<SendFeedbackScreen> createState() => _SendFeedbackScreenState();
}

class _SendFeedbackScreenState extends State<SendFeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _feedbackController = TextEditingController();
  int _rating = 0;
  bool _isSubmitting = false;

  // 🆕 Internet connection state
  bool _hasInternetConnection = true;
  bool _showNoInternetToast = false;

  // 🔥 Appwrite Configuration
  late Client _client;
  late Databases _databases;

  // ⚠️ TODO: මේ values ටික ඔයාගේ Appwrite credentials වලින් replace කරන්න
  static const String APPWRITE_ENDPOINT = 'https://sgp.cloud.appwrite.io/v1';
  static const String APPWRITE_PROJECT_ID = '699097b80017e2b33ca5';
  static const String APPWRITE_DATABASE_ID = 'problem_reports';  // Same database as reports
  static const String APPWRITE_COLLECTION_ID = 'feedbacks';  // Use the exact ID from Appwrite

  @override
  void initState() {
    super.initState();
    _initializeAppwrite();
  }

  // 🔧 Appwrite Initialize කරන්න
  void _initializeAppwrite() {
    _client = Client()
        .setEndpoint(APPWRITE_ENDPOINT)
        .setProject(APPWRITE_PROJECT_ID);

    _databases = Databases(_client);

    debugPrint('✅ Appwrite initialized for feedback');
  }

  // 🆕 Check internet connectivity
  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        setState(() {
          _hasInternetConnection = true;
        });
        return true;
      }
    } catch (e) {
      setState(() {
        _hasInternetConnection = false;
      });
      _showNoInternetConnection();
      return false;
    }
    return false;
  }

  // 🆕 Show "No Internet" toast
  void _showNoInternetConnection() {
    if (!_showNoInternetToast) {
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

  // 💾 Save feedback to Appwrite Database
  Future<void> _submitFeedback() async {
    // 1️⃣ Validation
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please give us a rating ⭐'),
          backgroundColor: Color(0xFFFF3B5C),
        ),
      );
      return;
    }

    // 2️⃣ Check internet connection
    final hasInternet = await _checkInternetConnection();
    if (!hasInternet) {
      debugPrint('❌ No internet connection');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 3️⃣ Get current user from Firebase
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('💬 Submitting feedback...');
      debugPrint('   Rating: $_rating stars');
      debugPrint('   User ID: ${currentUser.uid}');

      // 4️⃣ Save to Appwrite
      final feedbackData = {
        'rating': _rating,
        'feedback_text': _feedbackController.text.trim(),
        'user_id': currentUser.uid,
        'user_email': currentUser.email ?? 'Unknown',
        'created_at': DateTime.now().toIso8601String(),
      };

      final document = await _databases.createDocument(
        databaseId: APPWRITE_DATABASE_ID,
        collectionId: APPWRITE_COLLECTION_ID,
        documentId: ID.unique(),
        data: feedbackData,
      );

      debugPrint('✅ Feedback saved: ${document.$id}');

      // 5️⃣ Success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your feedback! 💚'),
            backgroundColor: Color(0xFF43E97B),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('❌ Failed to submit feedback: $e');

      if (mounted) {
        String errorMessage = 'Failed to submit feedback';

        if (e.toString().contains('network') ||
            e.toString().contains('connection')) {
          errorMessage = 'Network error. Please check your connection';
        } else if (e.toString().contains('timeout')) {
          errorMessage = 'Request timeout. Please try again';
        } else if (e.toString().contains('User not authenticated')) {
          errorMessage = 'Please login to send feedback';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: const Color(0xFFFF3B5C),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _submitFeedback,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
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
        title: const Text(
          'Send Feedback',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header Message
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF43E97B).withOpacity(0.1),
                    const Color(0xFF38F9D7).withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    color: Color(0xFF43E97B),
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'We\'d love to hear from you!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your feedback helps us improve',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Rating Section
            Text(
              'How would you rate your experience?',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _rating = index + 1;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      size: 48,
                      color: index < _rating
                          ? const Color(0xFFFFA726)
                          : Colors.grey.shade600,
                    ),
                  ),
                );
              }),
            ),
            if (_rating > 0) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _getRatingText(_rating),
                  style: const TextStyle(
                    color: Color(0xFFFFA726),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Feedback Text
            Text(
              'Tell us more (optional)',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextFormField(
                controller: _feedbackController,
                maxLines: 6,
                maxLength: 500,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Share your thoughts, suggestions, or any issues you faced...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                  counterStyle: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF43E97B),
                  disabledBackgroundColor: Colors.grey.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Text(
                  'Send Feedback',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Privacy Note
            Text(
              'Your feedback is anonymous and will be used to improve our app',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Poor 😞';
      case 2:
        return 'Could be better 😐';
      case 3:
        return 'Good 🙂';
      case 4:
        return 'Great 😊';
      case 5:
        return 'Excellent! 🤩';
      default:
        return '';
    }
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }
}