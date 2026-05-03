import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class BioEditActivityScreen extends StatefulWidget {
  final String currentBio;

  const BioEditActivityScreen({
    super.key,
    this.currentBio = '',
  });

  @override
  State<BioEditActivityScreen> createState() => _BioEditActivityScreenState();
}

class _BioEditActivityScreenState extends State<BioEditActivityScreen> {
  final TextEditingController _bioController = TextEditingController();
  final int _maxLength = 100;
  final int _maxNewLines = 3;

  bool _showTimeWarning = false;
  bool _isLoading = true;
  bool _isCooldownActive = false;
  bool _isSaving = false;
  int _remainingDays = 0;
  String _lastEdited = 'Never';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ✅ නරක වචන ලිස්ට් එක
  final List<String> _profanityList = [
    'fuck', 'shit', 'bitch', 'asshole', 'damn', 'bastard', 'cunt', 'dick',
    'pussy', 'cock', 'slut', 'whore', 'fag', 'nigger', 'retard',
    'පකෝ', 'හුත්තෝ', 'පොන්නයෝ', 'හුකන්නෝ', 'බල්ලෝ', 'හූත්ති', 'පක',
    'හුත්', 'පොන්න', 'කරිය', 'වේසි', 'පකයා', 'හුත්තා',
  ];

  @override
  void initState() {
    super.initState();
    _checkCooldownAndLoadBio();
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _checkCooldownAndLoadBio() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final userDoc = await _firestore.collection('users').doc(userId).get();
      final data = userDoc.data();

      if (data != null) {
        _bioController.text = data['bio'] ?? '';

        final lastBioUpdate = data['lastBioUpdate'] as Timestamp?;
        if (lastBioUpdate != null) {
          final lastUpdate = lastBioUpdate.toDate();
          final difference = DateTime.now().difference(lastUpdate);

          if (difference.inDays < 7) {
            setState(() {
              _isCooldownActive = true;
              _remainingDays = 7 - difference.inDays;
              _lastEdited = DateFormat('MM/dd/yyyy').format(lastUpdate);
            });
          } else {
            setState(() {
              _lastEdited = DateFormat('MM/dd/yyyy').format(lastUpdate);
            });
          }
        }
      }
    } catch (e) {
      print('Error loading bio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load bio: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String? _validateBio(String text) {
    final trimmedText = text.trim();

    // Empty check
    if (trimmedText.isEmpty) {
      return 'Bio cannot be empty';
    }

    // Length check
    if (trimmedText.length > _maxLength) {
      return 'Bio is too long (max $_maxLength characters)';
    }

    // Bad words filter
    final lowerText = trimmedText.toLowerCase();
    for (var word in _profanityList) {
      if (lowerText.contains(word.toLowerCase())) {
        return 'Please avoid using inappropriate language';
      }
    }

    // Link detection
    final urlPattern = RegExp(
      r'https?://|www\.|\.com|\.lk|\.net|\.org|\.edu|\.gov|\.io|bit\.ly|tinyurl',
      caseSensitive: false,
    );
    if (urlPattern.hasMatch(trimmedText)) {
      return 'Links are not allowed in bio';
    }

    // New line limit
    final newLineCount = '\n'.allMatches(trimmedText).length;
    if (newLineCount > _maxNewLines) {
      return 'Maximum $_maxNewLines line breaks allowed';
    }

    // Spam detection (repeated characters)
    final spamPattern = RegExp(r'(.)\1{9,}'); // 10+ same characters
    if (spamPattern.hasMatch(trimmedText)) {
      return 'Please avoid spam or repeated characters';
    }

    return null;
  }

  bool get _isSaveEnabled =>
      _bioController.text.trim().isNotEmpty &&
          !_isCooldownActive &&
          !_isSaving &&
          !_isLoading;

  Future<void> _handleSave() async {
    if (!_isSaveEnabled) return;

    // Validate bio
    final error = _validateBio(_bioController.text);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Firestore transaction with cooldown check
      await _firestore.runTransaction((transaction) async {
        final userDocRef = _firestore.collection('users').doc(userId);
        final userDoc = await transaction.get(userDocRef);

        if (userDoc.exists) {
          final data = userDoc.data();
          final lastBioUpdate = data?['lastBioUpdate'] as Timestamp?;

          if (lastBioUpdate != null) {
            final lastUpdate = lastBioUpdate.toDate();
            final difference = DateTime.now().difference(lastUpdate);

            if (difference.inDays < 7) {
              throw Exception(
                  'You can edit again in ${7 - difference.inDays} days');
            }
          }
        }

        // ✅ Update bio with timestamp
        transaction.update(userDocRef, {
          'bio': _bioController.text.trim(),
          'lastBioUpdate': FieldValue.serverTimestamp(),
        });
      });

      setState(() {
        _showTimeWarning = true;
        _isCooldownActive = true;
        _remainingDays = 7;
        _lastEdited = DateFormat('MM/dd/yyyy').format(DateTime.now());
      });

      if (mounted) {
        // ✅ Haptic feedback (premium feel)
        HapticFeedback.mediumImpact();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Bio saved successfully! ✓'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );

        // ✅ Navigate back and return the updated bio
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            Navigator.of(context).pop(_bioController.text.trim());
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _handleCancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(
              bottom: BorderSide(
                color: Color(0xFFF1F5F9),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                offset: const Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Cancel Button
                  TextButton(
                    onPressed: _isSaving ? null : _handleCancel,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 4,
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _isSaving
                            ? const Color(0xFFC9C5C5)
                            : Colors.black,
                      ),
                    ),
                  ),

                  // Title
                  const Text(
                    'Bio',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),

                  // Save Button
                  ListenableBuilder(
                    listenable: _bioController,
                    builder: (context, child) {
                      return TextButton(
                        onPressed: _isSaveEnabled ? _handleSave : null,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 4,
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF3B82F6),
                            ),
                          ),
                        )
                            : Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _isSaveEnabled
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFFC9C5C5),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time Limit Warning
            if (_showTimeWarning || _isCooldownActive)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                  border: const Border(
                    left: BorderSide(
                      color: Color(0xFFF59E0B),
                      width: 3,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_outlined,
                      size: 24,
                      color: Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isCooldownActive
                            ? 'You can edit your bio again in $_remainingDays ${_remainingDays == 1 ? 'day' : 'days'}'
                            : 'You can edit your bio again in 7 days',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFF57C00),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Bio Input Section
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bio',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: _isCooldownActive
                        ? const Color(0xFFEEEEEE)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isCooldownActive
                          ? const Color(0xFFD0D0D0)
                          : const Color(0xFFE0E0E0),
                    ),
                  ),
                  child: TextField(
                    controller: _bioController,
                    maxLength: _maxLength,
                    maxLines: 5,
                    enabled: !_isCooldownActive,
                    decoration: InputDecoration(
                      hintText: _isCooldownActive
                          ? 'You can edit again in $_remainingDays ${_remainingDays == 1 ? 'day' : 'days'}'
                          : 'Write something about yourself...',
                      hintStyle: TextStyle(
                        color: _isCooldownActive
                            ? const Color(0xFFAAAAAA)
                            : const Color(0xFF939292),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(12),
                      counterText: '',
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ListenableBuilder(
                  listenable: _bioController,
                  builder: (context, child) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_bioController.text.length}/$_maxLength',
                          style: TextStyle(
                            fontSize: 12,
                            color: _bioController.text.length > _maxLength
                                ? Colors.red
                                : const Color(0xFF666666),
                          ),
                        ),
                        Text(
                          'Last edited: $_lastEdited',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF999999),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Bio Tips Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 20,
                        color: Color(0xFFF59E0B),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Tips for a Great Bio',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Keep it brief and engaging\n'
                        '• Share your interests\n'
                        '• Add your location\n'
                        '• Mention your hobbies\n'
                        '• Use emojis to express yourself\n'
                        '• Avoid inappropriate language and links\n'
                        '• Remember: You can only edit once every 7 days',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                      height: 1.57,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Preview Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.remove_red_eye_outlined,
                        size: 20,
                        color: Color(0xFF64748B),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Preview',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFE0E0E0),
                      ),
                    ),
                    constraints: const BoxConstraints(
                      minHeight: 60,
                    ),
                    child: ListenableBuilder(
                      listenable: _bioController,
                      builder: (context, child) {
                        return Text(
                          _bioController.text.isEmpty
                              ? 'Your bio will appear here...'
                              : _bioController.text,
                          style: TextStyle(
                            fontSize: 14,
                            color: _bioController.text.isEmpty
                                ? const Color(0xFF999999)
                                : Colors.black,
                            fontStyle: _bioController.text.isEmpty
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}