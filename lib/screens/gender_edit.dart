import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GenderEditScreen extends StatefulWidget {
  final String currentGender;

  const GenderEditScreen({
    super.key,
    required this.currentGender,
  });

  @override
  State<GenderEditScreen> createState() => _GenderEditScreenState();
}

class _GenderEditScreenState extends State<GenderEditScreen> {
  late String selectedGender;
  bool isSaving = false;
  bool showGenderTag = true; // ✅ New

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    selectedGender = widget.currentGender;
    _loadSettings(); // ✅ New
  }

  // ✅ Load show_gender_tag from Firestore
  Future<void> _loadSettings() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          showGenderTag = doc.data()?['show_gender_tag'] ?? true;
        });
      }
    } catch (e) {
      print('Error loading gender settings: $e');
    }
  }

  Future<void> _saveGender() async {
    if (isSaving) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not authenticated')),
        );
      }
      return;
    }

    setState(() => isSaving = true);

    try {
      // Check last update time for rate limiting
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        final lastGenderUpdate = data?['lastGenderUpdate'] as Timestamp?;

        if (lastGenderUpdate != null) {
          final lastUpdate = lastGenderUpdate.toDate();
          final now = DateTime.now();
          final difference = now.difference(lastUpdate);

          // Rate limit: 1 minute between updates
          if (difference.inMinutes < 1) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Please wait ${60 - difference.inSeconds} seconds before updating again',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
              setState(() => isSaving = false);
            }
            return;
          }
        }
      }

      // Update gender + show_gender_tag in Firestore
      await _firestore.collection('users').doc(currentUser.uid).update({
        'gender': selectedGender,
        'show_gender_tag': showGenderTag, // ✅ New
        'lastGenderUpdate': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gender updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        await Future.delayed(const Duration(milliseconds: 500));
        Navigator.pop(context, selectedGender);
      }
    } catch (e) {
      print('Error saving gender: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update gender. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Select Gender',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: isSaving
                ? const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFFFF3B5C), // ✅ Color changed
                  ),
                ),
              ),
            )
                : IconButton(
              icon: const Icon(
                Icons.check,
                color: Color(0xFFFF3B5C), // ✅ Color changed
                size: 28,
              ),
              onPressed: _saveGender,
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text(
              'Choose your gender',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF757575),
              ),
            ),
            const SizedBox(height: 20),
            _buildGenderOption('Male'),
            const SizedBox(height: 10),
            _buildGenderOption('Female'),
            const SizedBox(height: 10),
            _buildGenderOption('Other'),
            const SizedBox(height: 10),
            _buildGenderOption('Prefer not to say'),

            // ✅ Show gender tag section
            const SizedBox(height: 28),
            const Text(
              'Display on profile',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF9E9E9E),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const Text(
                      'Show gender tag',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                    const Spacer(),
                    // iOS-style animated toggle matching the existing switch style
                    GestureDetector(
                      onTap: () =>
                          setState(() => showGenderTag = !showGenderTag),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 52,
                        height: 32,
                        decoration: BoxDecoration(
                          color: showGenderTag
                              ? const Color(0xFFFF3B5C)
                              : const Color(0xFFBDBDBD),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          alignment: showGenderTag
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            width: 28,
                            height: 28,
                            margin: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderOption(String genderOption) {
    final isSelected = selectedGender == genderOption;

    return InkWell(
      onTap: () {
        setState(() {
          selectedGender = genderOption;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF3B5C).withOpacity(0.1) // ✅ Color changed
              : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF3B5C) // ✅ Color changed
                : const Color(0xFFE0E0E0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFFF3B5C) // ✅ Color changed
                      : const Color(0xFF757575),
                  width: 2,
                ),
                color: Colors.white,
              ),
              child: isSelected
                  ? Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFF3B5C), // ✅ Color changed
                  ),
                ),
              )
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              genderOption,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.black : const Color(0xFF424242),
              ),
            ),
          ],
        ),
      ),
    );
  }
}