import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NameEditActivityScreen extends StatefulWidget {
  const NameEditActivityScreen({super.key});

  @override
  State<NameEditActivityScreen> createState() => _NameEditActivityScreenState();
}

class _NameEditActivityScreenState extends State<NameEditActivityScreen> {
  final TextEditingController _nameController = TextEditingController();
  final int _maxLength = 30;
  static const int nameChangeLimitDays = 7;

  // Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String originalName = '';
  bool canUpdateName = true;
  String nextUpdateDate = '';
  int daysRemaining = 0; // 🆕 Days remaining
  bool isLoading = true;
  bool isSaving = false;

  // 🆕 Internet connectivity
  bool _hasInternetConnection = true;
  bool _showNoInternetToast = false;

  // ✅ නරක වචන ලිස්ට් එක (Profanity Filter)
  final List<String> _profanityList = [
    'fuck', 'shit', 'bitch', 'asshole', 'damn', 'bastard', 'cunt', 'dick',
    'පකෝ', 'හුත්තෝ', 'පොන්නයෝ', 'හුකන්නෝ',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentName();
    _checkUpdatePermission();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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

  Future<void> _loadCurrentName() async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not authenticated')),
        );
        Navigator.pop(context);
      }
      return;
    }

    try {
      final docSnapshot = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (docSnapshot.exists) {
        final name = docSnapshot.data()?['name'] as String?;
        if (name != null && name.isNotEmpty) {
          setState(() {
            originalName = name;
            _nameController.text = name;
            _nameController.selection = TextSelection.fromPosition(
              TextPosition(offset: name.length),
            );
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading current name: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load current name')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _checkUpdatePermission() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final docSnapshot = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (docSnapshot.exists) {
        final lastNameUpdate =
        docSnapshot.data()?['lastNameUpdate'] as Timestamp?;

        if (lastNameUpdate != null) {
          final lastUpdateDate = lastNameUpdate.toDate();
          final nextAllowedDate =
          lastUpdateDate.add(const Duration(days: nameChangeLimitDays));
          final currentDate = DateTime.now();

          if (currentDate.isBefore(nextAllowedDate)) {
            final dateFormat = DateFormat('MMM dd, yyyy');
            // 🆕 Calculate days remaining
            final remaining = nextAllowedDate.difference(currentDate).inDays + 1;
            setState(() {
              canUpdateName = false;
              nextUpdateDate = dateFormat.format(nextAllowedDate);
              daysRemaining = remaining;
            });
          } else {
            setState(() {
              canUpdateName = true;
              daysRemaining = 0;
            });
          }
        } else {
          setState(() {
            canUpdateName = true;
            daysRemaining = 0;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking update permission: $e');
      setState(() => canUpdateName = true);
    }
  }

  bool _containsProfanity(String text) {
    final lowerText = text.toLowerCase();
    for (var word in _profanityList) {
      if (lowerText.contains(word.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  bool _containsSpecialCharacters(String text) {
    final validPattern =
    RegExp(r'^[a-zA-Z0-9\s\u0D80-\u0DFF\u0B80-\u0BFF]+$');
    return !validPattern.hasMatch(text);
  }

  Future<bool> _isUsernameUnique(String username) async {
    try {
      final usernameDoc = await _firestore
          .collection('usernames')
          .doc(username.toLowerCase())
          .get();

      if (!usernameDoc.exists) {
        return true;
      }

      final userId = usernameDoc.data()?['userId'] as String?;
      return userId == _auth.currentUser?.uid;
    } catch (e) {
      debugPrint('Error checking username uniqueness: $e');
      return false;
    }
  }

  Future<void> _saveName() async {
    // 🆕 Internet check first
    final hasInternet = await _checkInternetConnection();
    if (!hasInternet) return;

    final newName = _nameController.text.trim();

    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name')),
      );
      return;
    }

    if (newName.length > _maxLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name must be 30 characters or less')),
      );
      return;
    }

    if (_containsProfanity(newName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name contains inappropriate language'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_containsSpecialCharacters(newName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name can only contain letters, numbers and spaces'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!canUpdateName) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You can change your name again on $nextUpdateDate'),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      if (newName.toLowerCase() != originalName.toLowerCase()) {
        final isUnique = await _isUsernameUnique(newName);
        if (!isUnique) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This username is already taken'),
                backgroundColor: Colors.orange,
              ),
            );
            setState(() => isSaving = false);
          }
          return;
        }
      }

      await _firestore.runTransaction((transaction) async {
        // ✅ පළමු document exist දැයි check කරන්න
        if (originalName.isNotEmpty &&
            originalName.toLowerCase() != newName.toLowerCase()) {
          final oldUsernameDoc = await transaction.get(
            _firestore.collection('usernames').doc(originalName.toLowerCase()),
          );
          if (oldUsernameDoc.exists) {
            transaction.delete(oldUsernameDoc.reference);
          }
        }

        transaction.set(
          _firestore.collection('usernames').doc(newName.toLowerCase()),
          {
            'userId': currentUser.uid,
            'username': newName,
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true), // ✅ create or merge
        );

        transaction.update(
          _firestore.collection('users').doc(currentUser.uid),
          {
            'name': newName,
            'lastNameUpdate': FieldValue.serverTimestamp(),
          },
        );
      });

      debugPrint('Name updated successfully in Firestore');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name updated successfully')),
        );
        Navigator.pop(context, newName);
      }
    } catch (e) {
      debugPrint('Error updating name in Firestore: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),  // ← මේකෙන් replace
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  bool get _isSaveEnabled {
    final currentName = _nameController.text.trim();
    final hasChanges = currentName != originalName;
    final isValid = currentName.isNotEmpty && currentName.length <= _maxLength;
    return hasChanges && isValid && canUpdateName && !isSaving;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text('Name'),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFF3B5C), // 🆕 Brand color
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
                color: const Color(0xFF0F172A).withOpacity(0.03),
                offset: const Offset(0, 2),
                blurRadius: 8,
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
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 4,
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),

                  // Title
                  const Text(
                    'Name',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),

                  // Save Button
                  ListenableBuilder(
                    listenable: _nameController,
                    builder: (context, child) {
                      return TextButton(
                        onPressed: _isSaveEnabled ? _saveName : null,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 4,
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFFF3B5C), // 🆕 Brand color
                            ),
                          ),
                        )
                            : Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _isSaveEnabled
                                ? const Color(0xFFFF3B5C) // 🆕 Brand color
                                : const Color(0xFFCBD5E1),
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInputSection(),
              const SizedBox(height: 20),
              _buildWarningContainer(),
              const SizedBox(height: 24),
              _buildGuidelinesCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Name',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: canUpdateName ? Colors.white : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.03),
                offset: const Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _nameController,
                  enabled: canUpdateName,
                  maxLength: _maxLength,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[a-zA-Z0-9\s\u0D80-\u0DFF\u0B80-\u0BFF]'),
                    ),
                  ],
                  decoration: const InputDecoration(
                    hintText: 'Enter your nickname',
                    hintStyle: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    counterText: '',
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0F172A),
                  ),
                  cursorColor: const Color(0xFFFF3B5C), // 🆕 Brand color
                ),
              ),
              Container(
                height: 2,
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                decoration: const BoxDecoration(
                  color: Color(0xFFE2E8F0),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ListenableBuilder(
          listenable: _nameController,
          builder: (context, child) {
            return Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_nameController.text.length}/$_maxLength',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildWarningContainer() {
    // 🆕 Days remaining display
    String warningText;
    if (canUpdateName) {
      warningText = 'Your nickname can only be changed once every 7 days.';
    } else {
      warningText = daysRemaining > 0
          ? 'You can change your name in $daysRemaining day${daysRemaining == 1 ? '' : 's'} (on $nextUpdateDate)'
          : 'You can change your name again on $nextUpdateDate';
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(
            color: Color(0xFFF59E0B),
            width: 3,
          ),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            color: Color(0xFFF59E0B),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              warningText,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF92400E),
                height: 1.43,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelinesCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF1F5F9),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF3B5C), // 🆕 Brand color
                      Color(0xFFE0002E),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF3B5C).withOpacity(0.2),
                      offset: const Offset(0, 2),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Nickname Guidelines',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildGuidelineItem('No special characters or symbols'),
          const SizedBox(height: 12),
          _buildGuidelineItem('Avoid offensive language'),
          const SizedBox(height: 12),
          _buildGuidelineItem('Maximum 30 characters'),
          const SizedBox(height: 12),
          _buildGuidelineItem('Can only be changed once every 7 days'),
        ],
      ),
    );
  }

  Widget _buildGuidelineItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFFF3B5C), // 🆕 Brand color
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF475569),
              height: 1.43,
            ),
          ),
        ),
      ],
    );
  }
}