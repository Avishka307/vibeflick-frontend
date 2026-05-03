// lib/screens/settings/faq_screen.dart

import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'help_and_feedback_screen.dart';

class FAQScreen extends StatefulWidget {
  final String? searchQuery;
  const FAQScreen({Key? key, this.searchQuery}) : super(key: key);

  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> {
  // 🔍 Search Controller
  final TextEditingController _searchController = TextEditingController();

  // 📂 Selected Category
  String _selectedCategory = 'All';

  // 🗂️ Categories
  final List<String> _categories = [
    'All',
    'Account',
    'Video',
    'Upload',
    'Privacy',
    'Technical',
  ];

  // 📝 FAQ Data with categories and actions
  final List<FAQItem> _allFaqs = [
    // Account FAQs
    FAQItem(
      question: 'How do I change my password?',
      answer: 'Go to Settings > Account > Change Password. Enter your current password and your new password twice to confirm.',
      category: 'Account',
      actionLabel: 'Go to Settings',
      actionRoute: '/settings',
    ),
    FAQItem(
      question: 'How do I delete my account?',
      answer: 'Go to Settings > Account > Delete Account. Please note that this action is permanent and cannot be undone.',
      category: 'Account',
      actionLabel: 'Go to Account Settings',
      actionRoute: '/settings/account',
    ),
    FAQItem(
      question: 'How do I edit my profile?',
      answer: 'Tap on your profile picture, then tap "Edit Profile". You can change your name, bio, profile picture, and cover photo.',
      category: 'Account',
      actionLabel: 'Go to Profile',
      actionRoute: '/profile',
    ),

    // Video FAQs
    FAQItem(
      question: 'How do I upload a video?',
      answer: 'To upload a video:\n1. Tap the + icon at the bottom center\n2. Select or record a video\n3. Add music, effects, and filters\n4. Write a caption and tap Post',
      category: 'Video',
      actionLabel: 'Upload Video',
      actionRoute: '/upload',
    ),
    FAQItem(
      question: 'How do I add music to my video?',
      answer: 'After selecting your video, tap "Add Music" and choose from our music library. You can also record your own audio.',
      category: 'Video',
      actionLabel: 'Explore Music',
      actionRoute: '/music',
    ),
    FAQItem(
      question: 'Can I use copyrighted music?',
      answer: 'Use only music from our library or music you have rights to. Copyrighted music may result in your video being removed.',
      category: 'Privacy',
    ),

    // Upload FAQs
    FAQItem(
      question: 'Why is my video not uploading?',
      answer: 'Check your internet connection. Make sure the video is under 60 seconds and less than 100MB. If the problem persists, try restarting the app.',
      category: 'Upload',
    ),
    FAQItem(
      question: 'What video formats are supported?',
      answer: 'We support MP4, MOV, and AVI formats. Videos should be under 60 seconds and less than 100MB.',
      category: 'Upload',
    ),

    // Privacy FAQs
    FAQItem(
      question: 'How do I report inappropriate content?',
      answer: 'Tap and hold on any video, then select "Report". Choose the reason and submit. Our team will review it within 24 hours.',
      category: 'Privacy',
    ),
    FAQItem(
      question: 'How do I make my account private?',
      answer: 'Go to Settings > Privacy > Private Account. When your account is private, only approved followers can see your videos.',
      category: 'Privacy',
      actionLabel: 'Privacy Settings',
      actionRoute: '/settings/privacy',
    ),

    // Technical FAQs
    FAQItem(
      question: 'The app keeps crashing, what should I do?',
      answer: 'Try clearing the app cache, updating to the latest version, or reinstalling the app. If the problem persists, contact support.',
      category: 'Technical',
    ),
    FAQItem(
      question: 'Videos are not playing smoothly',
      answer: 'Check your internet connection. Try lowering video quality in Settings > Video Quality. Clear app cache if needed.',
      category: 'Technical',
      actionLabel: 'Go to Settings',
      actionRoute: '/settings',
    ),
  ];

  // 🔧 Appwrite Configuration
  late Client _client;
  late Databases _databases;

  static const String APPWRITE_ENDPOINT = 'https://sgp.cloud.appwrite.io/v1';
  static const String APPWRITE_PROJECT_ID = '699097b80017e2b33ca5';
  static const String APPWRITE_DATABASE_ID = 'problem_reports';
  static const String APPWRITE_COLLECTION_ID = 'faq_feedback'; // අලුත් collection එකක්

  // 📊 Filtered FAQs
  List<FAQItem> _filteredFaqs = [];

  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _initializeAppwrite();

    // Set initial search query if provided
    if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
      _searchController.text = widget.searchQuery!;
    }

    _filterFaqs();
  }

  void _initializeAppwrite() {
    _client = Client()
        .setEndpoint(APPWRITE_ENDPOINT)
        .setProject(APPWRITE_PROJECT_ID);
    _databases = Databases(_client);
  }

  // 🔍 Filter FAQs based on search and category
  void _filterFaqs() {
    setState(() {
      _filteredFaqs = _allFaqs.where((faq) {
        // Category filter
        final matchesCategory = _selectedCategory == 'All' ||
            faq.category == _selectedCategory;

        // Search filter
        final searchQuery = _searchController.text.toLowerCase();
        final matchesSearch = searchQuery.isEmpty ||
            faq.question.toLowerCase().contains(searchQuery) ||
            faq.answer.toLowerCase().contains(searchQuery);

        return matchesCategory && matchesSearch;
      }).toList();
    });
  }

  // 👍👎 Save feedback to Appwrite
  Future<void> _saveFeedback(FAQItem faq, bool isHelpful) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final feedbackData = {
        'faq_question': faq.question,
        'is_helpful': isHelpful,
        'user_id': currentUser.uid,
        'created_at': DateTime.now().toIso8601String(),
      };

      await _databases.createDocument(
        databaseId: APPWRITE_DATABASE_ID,
        collectionId: APPWRITE_COLLECTION_ID,
        documentId: ID.unique(),
        data: feedbackData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isHelpful
                ? 'Thanks for your feedback! 😊'
                : 'Sorry this didn\'t help. We\'ll improve it! 💪'),
            backgroundColor: isHelpful
                ? const Color(0xFF43E97B)
                : const Color(0xFFFF3B5C),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to save FAQ feedback: $e');
    }
  }

  // 🔗 Handle action button press (Deep linking)
  void _handleAction(String? route) {
    if (route == null) return;

    // Deep linking logic - ඔයාගේ app routes වලට අනුව customize කරන්න
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigating to $route...'),
        backgroundColor: const Color(0xFF4FACFE),
        duration: const Duration(seconds: 1),
      ),
    );

    // TODO: Implement actual navigation based on route
    // Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        title: const Text(
          'FAQ / Help Center',
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
      body: Column(
        children: [
          // 🔍 Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search FAQs...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                      _filterFaqs();
                    },
                  )
                      : null,
                  border: InputBorder.none,
                ),
                onChanged: (value) => _filterFaqs(),
              ),
            ),
          ),

          // 🗂️ Category Chips (Horizontal Scroll)
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category;
                        _filterFaqs();
                      });
                    },
                    selectedColor: const Color(0xFF43E97B),
                    backgroundColor: const Color(0xFF2A2A2A),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF43E97B)
                          : Colors.grey.shade700,
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // 📝 FAQ List
          Expanded(
            child: _filteredFaqs.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredFaqs.length + 1, // +1 for "Still Stuck?" card
              itemBuilder: (context, index) {
                // "Still Stuck?" card at the end
                if (index == _filteredFaqs.length) {
                  return _buildStillStuckCard();
                }

                final faq = _filteredFaqs[index];
                final isExpanded = _expandedIndex == index;

                return _buildFAQItem(faq, index, isExpanded);
              },
            ),
          ),
        ],
      ),
    );
  }

  // 📋 FAQ Item Widget
  Widget _buildFAQItem(FAQItem faq, int index, bool isExpanded) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded ? const Color(0xFF43E97B) : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expandedIndex = isExpanded ? null : index;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          faq.question,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: const Color(0xFF43E97B),
                      ),
                    ],
                  ),
                  if (isExpanded) ...[
                    const SizedBox(height: 12),
                    Text(
                      faq.answer,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),

                    // 🔗 Action Button
                    if (faq.actionLabel != null && faq.actionRoute != null) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _handleAction(faq.actionRoute),
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: Text(faq.actionLabel!),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF43E97B),
                            side: const BorderSide(color: Color(0xFF43E97B)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],

                    // 👍👎 Did this help?
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          'Was this helpful?',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => _saveFeedback(faq, true),
                          icon: const Icon(Icons.thumb_up_outlined),
                          color: const Color(0xFF43E97B),
                          iconSize: 20,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _saveFeedback(faq, false),
                          icon: const Icon(Icons.thumb_down_outlined),
                          color: const Color(0xFFFF3B5C),
                          iconSize: 20,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 📭 Empty State
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: Colors.grey.shade700,
            ),
            const SizedBox(height: 16),
            const Text(
              'No results found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try different keywords or browse by category',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HelpAndFeedbackScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.support_agent),
              label: const Text('Contact Support'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF43E97B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🆘 "Still Stuck?" Card
  Widget _buildStillStuckCard() {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4FACFE).withOpacity(0.2),
            const Color(0xFF00F2FE).withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4FACFE).withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.help_outline,
            color: Color(0xFF4FACFE),
            size: 48,
          ),
          const SizedBox(height: 12),
          const Text(
            'Still need help?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Can\'t find what you\'re looking for? Our support team is here to help!',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HelpAndFeedbackScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.support_agent),
              label: const Text('Contact Support'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4FACFE),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// 📋 FAQ Item Model
class FAQItem {
  final String question;
  final String answer;
  final String category;
  final String? actionLabel;
  final String? actionRoute;

  FAQItem({
    required this.question,
    required this.answer,
    required this.category,
    this.actionLabel,
    this.actionRoute,
  });
}