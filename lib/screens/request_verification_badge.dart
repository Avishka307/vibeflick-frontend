import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class RequestVerificationBadge extends StatefulWidget {
  const RequestVerificationBadge({Key? key}) : super(key: key);

  @override
  State<RequestVerificationBadge> createState() => _RequestVerificationBadgeState();
}

class _RequestVerificationBadgeState extends State<RequestVerificationBadge> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  // Dark theme colors
  static const Color _bgColor = Color(0xFF1F1F1F);
  static const Color _cardColor = Color(0xFF2A2A2A);
  static const Color _accentColor = Color(0xFF6C63FF);
  static const Color _secondaryAccent = Color(0xFF9B59D0);

  // Form fields
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _facebookController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();

  // Notability links
  final List<TextEditingController> _linkControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  // Category selection
  String? _selectedCategory;
  final List<String> _categories = [
    'News/Media',
    'Sports',
    'Government',
    'Music',
    'Content Creator',
    'Business',
    'Entertainment',
    'Fashion',
    'Education',
    'Other',
  ];

  // Identity document
  File? _identityDocument;
  File? _selfieVideo;
  final ImagePicker _picker = ImagePicker();

  // Social profiles status
  bool _facebookConnected = false;
  bool _instagramConnected = false;

  // Security check
  bool _has2FAEnabled = false;
  bool _isChecking2FA = true;

  // Current verification status
  String? _verificationStatus; // "pending", "approved", "rejected", null
  String? _rejectionReason;
  DateTime? _rejectedAt;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _checkVerificationStatus();
    _check2FAStatus();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _reasonController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    for (var controller in _linkControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // Check 2FA status
  Future<void> _check2FAStatus() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        final userDoc = await _db.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data();
          setState(() {
            _has2FAEnabled = data?['twoFactorEnabled'] == true;
            _isChecking2FA = false;
          });
        } else {
          setState(() {
            _isChecking2FA = false;
          });
        }
      }
    } catch (e) {
      print('Error checking 2FA status: $e');
      setState(() {
        _isChecking2FA = false;
      });
    }
  }

  // Check if user already has a verification request
  Future<void> _checkVerificationStatus() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        final verificationDoc = await _db
            .collection('verificationRequests')
            .doc(currentUser.uid)
            .get();

        if (verificationDoc.exists) {
          final data = verificationDoc.data();
          setState(() {
            _verificationStatus = data?['status'] ?? 'pending';
            _rejectionReason = data?['rejectionReason'];
            if (data?['rejectedAt'] != null) {
              _rejectedAt = (data!['rejectedAt'] as Timestamp).toDate();
            }
            _isLoading = false;
          });
        } else {
          setState(() {
            _verificationStatus = null;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error checking verification status: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(color: _accentColor),
      )
          : SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            if (_verificationStatus != null)
              _buildStatusTracker()
            else
              _buildVerificationForm(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_accentColor, _secondaryAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 55, 16, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(2),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Request Verification Badge',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const Icon(
            Icons.verified,
            color: Colors.white,
            size: 28,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTracker() {
    Color statusColor;
    IconData statusIcon;
    String statusTitle;
    String statusMessage;

    switch (_verificationStatus) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        statusTitle = 'Pending Review';
        statusMessage = 'Your verification request is being reviewed. This usually takes 2-3 business days.';
        break;
      case 'approved':
        statusColor = const Color(0xFF4CAF50);
        statusIcon = Icons.check_circle;
        statusTitle = 'Approved';
        statusMessage = 'Congratulations! Your account has been verified. Your badge is now active.';
        break;
      case 'rejected':
        statusColor = const Color(0xFFFF6584);
        statusIcon = Icons.cancel;
        statusTitle = 'Rejected';
        statusMessage = _rejectionReason ?? 'Your verification request was not approved. Please ensure all information is accurate and try again.';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
        statusTitle = 'Unknown';
        statusMessage = 'Status unavailable.';
    }

    // Check cooloff period (30 days)
    bool canResubmit = true;
    String? cooloffMessage;
    if (_verificationStatus == 'rejected' && _rejectedAt != null) {
      final daysSinceRejection = DateTime.now().difference(_rejectedAt!).inDays;
      final daysRemaining = 30 - daysSinceRejection;
      if (daysRemaining > 0) {
        canResubmit = false;
        cooloffMessage = 'You can submit a new request in $daysRemaining days';
      }
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Status Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              statusIcon,
              color: statusColor,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),

          // Status Title
          Text(
            statusTitle,
            style: TextStyle(
              color: statusColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Status Message
          Text(
            statusMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
              height: 1.5,
            ),
          ),

          // Rejection Reason (if rejected)
          if (_verificationStatus == 'rejected' && _rejectionReason != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6584).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFF6584).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: const Color(0xFFFF6584),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rejection Reason:',
                          style: TextStyle(
                            color: Color(0xFFFF6584),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _rejectionReason!,
                          style: TextStyle(
                            color: Colors.grey.shade300,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Status Timeline
          _buildTimeline(),

          // Cooloff message
          if (!canResubmit && cooloffMessage != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cooloffMessage,
                        style: TextStyle(
                          color: Colors.grey.shade300,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Action Button
          if (_verificationStatus == 'rejected' && canResubmit)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _resubmitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Submit New Request',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildTimelineItem(
            'Submitted',
            true,
            isFirst: true,
          ),
          _buildTimelineItem(
            'Under Review',
            _verificationStatus == 'pending' || _verificationStatus == 'approved' || _verificationStatus == 'rejected',
          ),
          _buildTimelineItem(
            _verificationStatus == 'approved' ? 'Approved' : _verificationStatus == 'rejected' ? 'Rejected' : 'Decision',
            _verificationStatus == 'approved' || _verificationStatus == 'rejected',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String title, bool isActive, {bool isFirst = false, bool isLast = false}) {
    return Row(
      children: [
        Column(
          children: [
            if (!isFirst)
              Container(
                width: 2,
                height: 20,
                color: isActive ? _accentColor : Colors.grey.shade700,
              ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isActive ? _accentColor : Colors.grey.shade700,
                shape: BoxShape.circle,
              ),
              child: isActive
                  ? const Icon(Icons.check, color: Colors.white, size: 12)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 20,
                color: isActive ? _accentColor : Colors.grey.shade700,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey.shade600,
            fontSize: 14,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Guidelines Link
          _buildGuidelinesCard(),

          // 2FA Security Check
          if (!_has2FAEnabled && !_isChecking2FA)
            _build2FAWarning(),

          // Info Card
          _buildInfoCard(),

          // Confidentiality Note
          _buildConfidentialityNote(),

          // Category Selection
          _buildSectionCard(
            title: 'Category',
            icon: Icons.category,
            subtitle: 'Select your account category',
            children: [
              _buildCategoryDropdown(),
            ],
          ),

          // Personal Information Section
          _buildSectionCard(
            title: 'Personal Information',
            icon: Icons.person,
            children: [
              _buildTextField(
                controller: _fullNameController,
                label: 'Full Name',
                hint: 'Enter your full legal name',
                icon: Icons.badge,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _reasonController,
                label: 'Reason for Verification',
                hint: 'Why do you need a verified badge?',
                icon: Icons.description,
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please provide a reason';
                  }
                  return null;
                },
              ),
            ],
          ),

          // Social Profiles Section
          _buildSectionCard(
            title: 'Connect Social Profiles',
            icon: Icons.link,
            subtitle: 'Link your social accounts to verify follower count',
            children: [
              _buildSocialProfileField(
                controller: _facebookController,
                platform: 'Facebook',
                icon: Icons.facebook,
                color: const Color(0xFF1877F2),
                isConnected: _facebookConnected,
                onConnect: () => _connectSocialProfile('facebook'),
              ),
              const SizedBox(height: 12),
              _buildSocialProfileField(
                controller: _instagramController,
                platform: 'Instagram',
                icon: Icons.camera_alt,
                color: const Color(0xFFE4405F),
                isConnected: _instagramConnected,
                onConnect: () => _connectSocialProfile('instagram'),
              ),
            ],
          ),

          // Notability Links Section
          _buildSectionCard(
            title: 'Official Links (Notability)',
            icon: Icons.public,
            subtitle: 'Add links to news articles or websites about you',
            children: [
              _buildNotabilityLinks(),
            ],
          ),

          // Identity Proof Section
          _buildSectionCard(
            title: 'Proof of Identity',
            icon: Icons.credit_card,
            subtitle: 'Upload government-issued ID (NIC/Passport)',
            children: [
              _buildIdentityUpload(),
            ],
          ),

          // Video Verification Section
          _buildSectionCard(
            title: 'Video Verification',
            icon: Icons.videocam,
            subtitle: '5-second selfie video for identity confirmation',
            children: [
              _buildVideoUpload(),
            ],
          ),

          // Submit Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isSubmitting || !_has2FAEnabled) ? null : _submitVerificationRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey.shade700,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Text(
                  'Submit Verification Request',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _accentColor.withOpacity(0.2),
            _secondaryAccent.withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _accentColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.info_outline,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Verification Requirements',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Complete all fields and upload valid ID to get verified.',
                  style: TextStyle(
                    color: Colors.grey.shade300,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelinesCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showGuidelines,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _accentColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.menu_book,
                  color: _accentColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Read Verification Guidelines',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Learn about eligibility criteria',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: _accentColor,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _build2FAWarning() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6584).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF6584).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFFF6584),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '2FA Required',
                  style: TextStyle(
                    color: Color(0xFFFF6584),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enable Two-Factor Authentication to submit verification request',
                  style: TextStyle(
                    color: Colors.grey.shade300,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidentialityNote() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4CAF50).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline,
            color: Color(0xFF4CAF50),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'ඔබ ලබාදෙන තොරතුරු ආරක්ෂිතයි සහ කිසිවෙකුට ප්‍රදර්ශනය නොකෙරේ',
              style: TextStyle(
                color: Colors.grey.shade300,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: InputDecoration(
        labelText: 'Account Category',
        hintText: 'Select your category',
        labelStyle: TextStyle(color: Colors.grey.shade400),
        hintStyle: TextStyle(color: Colors.grey.shade600),
        prefixIcon: Icon(Icons.category, color: _accentColor),
        filled: true,
        fillColor: _bgColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade800),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _accentColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF6584)),
        ),
      ),
      dropdownColor: _cardColor,
      style: const TextStyle(color: Colors.white),
      items: _categories.map((category) {
        return DropdownMenuItem(
          value: category,
          child: Text(category),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedCategory = value;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a category';
        }
        return null;
      },
    );
  }

  Widget _buildNotabilityLinks() {
    return Column(
      children: [
        ...List.generate(_linkControllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              controller: _linkControllers[index],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Link ${index + 1}',
                hintText: 'https://example.com/article-about-you',
                labelStyle: TextStyle(color: Colors.grey.shade400),
                hintStyle: TextStyle(color: Colors.grey.shade600),
                prefixIcon: Icon(Icons.link, color: _accentColor),
                filled: true,
                fillColor: _bgColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade800),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _accentColor, width: 2),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        Text(
          'Add links to news articles or websites mentioning you',
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildVideoUpload() {
    return GestureDetector(
      onTap: _pickSelfieVideo,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selfieVideo != null ? const Color(0xFF4CAF50) : Colors.grey.shade800,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _selfieVideo != null
                    ? const Color(0xFF4CAF50).withOpacity(0.2)
                    : Colors.grey.shade800,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _selfieVideo != null ? Icons.check_circle : Icons.videocam,
                color: _selfieVideo != null ? const Color(0xFF4CAF50) : Colors.grey.shade400,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _selfieVideo != null ? 'Video Uploaded' : 'Record 5-Second Selfie Video',
              style: TextStyle(
                color: _selfieVideo != null ? Colors.white : Colors.grey.shade400,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selfieVideo != null
                  ? 'Tap to change video'
                  : 'Move your head left, right, up, or down',
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

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: _accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Colors.grey.shade400),
        hintStyle: TextStyle(color: Colors.grey.shade600),
        prefixIcon: Icon(icon, color: _accentColor),
        filled: true,
        fillColor: _bgColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade800),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _accentColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF6584)),
        ),
      ),
    );
  }

  Widget _buildSocialProfileField({
    required TextEditingController controller,
    required String platform,
    required IconData icon,
    required Color color,
    required bool isConnected,
    required VoidCallback onConnect,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected ? color.withOpacity(0.5) : Colors.grey.shade800,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  platform,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isConnected ? 'Connected' : 'Not connected',
                  style: TextStyle(
                    color: isConnected ? color : Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onConnect,
            style: ElevatedButton.styleFrom(
              backgroundColor: isConnected ? Colors.grey.shade700 : color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              isConnected ? 'Connected' : 'Connect',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityUpload() {
    return GestureDetector(
      onTap: _pickIdentityDocument,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _identityDocument != null ? _accentColor : Colors.grey.shade800,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _identityDocument != null
                    ? _accentColor.withOpacity(0.2)
                    : Colors.grey.shade800,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _identityDocument != null ? Icons.check_circle : Icons.upload_file,
                color: _identityDocument != null ? _accentColor : Colors.grey.shade400,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _identityDocument != null ? 'Document Uploaded' : 'Upload Identity Document',
              style: TextStyle(
                color: _identityDocument != null ? Colors.white : Colors.grey.shade400,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _identityDocument != null
                  ? 'Tap to change document'
                  : 'NIC or Passport (JPG, PNG, PDF)',
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

  // Pick identity document
  Future<void> _pickIdentityDocument() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _identityDocument = File(image.path);
        });
      }
    } catch (e) {
      _showError('Failed to pick document: $e');
    }
  }

  // Pick selfie video
  Future<void> _pickSelfieVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 5),
      );
      if (video != null) {
        setState(() {
          _selfieVideo = File(video.path);
        });
      }
    } catch (e) {
      _showError('Failed to record video: $e');
    }
  }

  // Show guidelines dialog
  void _showGuidelines() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.verified,
                color: _accentColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Verification Guidelines',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Eligibility Criteria:',
                style: TextStyle(
                  color: Colors.grey.shade300,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildGuidelineItem('✓ Authentic account representing a real person or business'),
              _buildGuidelineItem('✓ Minimum 10,000 followers on connected social profiles'),
              _buildGuidelineItem('✓ Active account with regular content'),
              _buildGuidelineItem('✓ Notable presence in your field'),
              _buildGuidelineItem('✓ Valid government-issued ID'),
              _buildGuidelineItem('✓ Two-Factor Authentication enabled'),
              const SizedBox(height: 16),
              Text(
                'Categories:',
                style: TextStyle(
                  color: Colors.grey.shade300,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Different verification standards apply to different categories (News/Media, Sports, Government, etc.)',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelineItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 13,
          height: 1.5,
        ),
      ),
    );
  }

  // Connect social profile
  void _connectSocialProfile(String platform) {
    // Simulate connection (in real app, use OAuth)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Connect $platform',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          'This will redirect you to $platform to authorize the connection.',
          style: TextStyle(color: Colors.grey.shade400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade400)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                if (platform == 'facebook') {
                  _facebookConnected = true;
                } else {
                  _instagramConnected = true;
                }
              });
              _showSuccess('$platform connected successfully!');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  // Submit verification request
  Future<void> _submitVerificationRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_identityDocument == null) {
      _showError('Please upload your identity document');
      return;
    }

    if (_selfieVideo == null) {
      _showError('Please record a selfie video for verification');
      return;
    }

    if (!_has2FAEnabled) {
      _showError('Please enable Two-Factor Authentication first');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Collect notability links
      final notabilityLinks = _linkControllers
          .map((controller) => controller.text)
          .where((link) => link.isNotEmpty)
          .toList();

      // In real app, upload document and video to Firebase Storage
      // For now, just store metadata

      await _db.collection('verificationRequests').doc(currentUser.uid).set({
        'userId': currentUser.uid,
        'category': _selectedCategory,
        'fullName': _fullNameController.text,
        'reason': _reasonController.text,
        'facebookProfile': _facebookController.text,
        'instagramProfile': _instagramController.text,
        'facebookConnected': _facebookConnected,
        'instagramConnected': _instagramConnected,
        'notabilityLinks': notabilityLinks,
        'identityDocumentUploaded': true,
        'selfieVideoUploaded': true,
        'twoFactorEnabled': _has2FAEnabled,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _verificationStatus = 'pending';
        _isSubmitting = false;
      });

      _showSuccess('Verification request submitted successfully!');
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      _showError('Failed to submit request: $e');
    }
  }

  // Resubmit after rejection
  void _resubmitRequest() {
    setState(() {
      _verificationStatus = null;
      _rejectionReason = null;
      _rejectedAt = null;
      _selectedCategory = null;
      _fullNameController.clear();
      _reasonController.clear();
      _facebookController.clear();
      _instagramController.clear();
      for (var controller in _linkControllers) {
        controller.clear();
      }
      _facebookConnected = false;
      _instagramConnected = false;
      _identityDocument = null;
      _selfieVideo = null;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFF6584),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}