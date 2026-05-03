import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/auth_service.dart';

class InterestSelectionActivity extends StatefulWidget {
  const InterestSelectionActivity({super.key});

  @override
  State<InterestSelectionActivity> createState() =>
      _InterestSelectionActivityState();
}

class _InterestSelectionActivityState extends State<InterestSelectionActivity>
    with TickerProviderStateMixin {
  final Set<String> _selectedCategories = {};
  final int _minRequired = 3;
  bool _isSaving = false;
  bool _isLoadingExisting = true; // Loading existing interests

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Categories with colors
  final List<CategoryItem> _categories = [
    CategoryItem(
      id: 'dance',
      name: 'Dance',
      icon: Icons.music_note,
      selectedColor: const Color(0xFFE91E63),
      unselectedColor: const Color(0xFF2C2C2C),
    ),
    CategoryItem(
      id: 'music',
      name: 'Music',
      icon: Icons.music_video,
      selectedColor: const Color(0xFF9C27B0),
      unselectedColor: const Color(0xFF2C2C2C),
    ),
    CategoryItem(
      id: 'comedy',
      name: 'Comedy',
      icon: Icons.emoji_emotions,
      selectedColor: const Color(0xFFFFC107),
      unselectedColor: const Color(0xFF2C2C2C),
    ),
    CategoryItem(
      id: 'animals',
      name: 'Animals',
      icon: Icons.pets,
      selectedColor: const Color(0xFF4CAF50),
      unselectedColor: const Color(0xFF2C2C2C),
    ),
    CategoryItem(
      id: 'travel',
      name: 'Travel',
      icon: Icons.flight_takeoff,
      selectedColor: const Color(0xFF2196F3),
      unselectedColor: const Color(0xFF2C2C2C),
    ),
    CategoryItem(
      id: 'food',
      name: 'Food',
      icon: Icons.restaurant,
      selectedColor: const Color(0xFFFF5722),
      unselectedColor: const Color(0xFF2C2C2C),
    ),
    CategoryItem(
      id: 'sports',
      name: 'Sports',
      icon: Icons.sports_soccer,
      selectedColor: const Color(0xFF795548),
      unselectedColor: const Color(0xFF2C2C2C),
    ),
    CategoryItem(
      id: 'fashion',
      name: 'Fashion',
      icon: Icons.checkroom,
      selectedColor: const Color(0xFFE91E63),
      unselectedColor: const Color(0xFF2C2C2C),
    ),
    CategoryItem(
      id: 'technology',
      name: 'Technology',
      icon: Icons.computer,
      selectedColor: const Color(0xFF607D8B),
      unselectedColor: const Color(0xFF2C2C2C),
    ),
    CategoryItem(
      id: 'art',
      name: 'Art',
      icon: Icons.palette,
      selectedColor: const Color(0xFF673AB7),
      unselectedColor: const Color(0xFF2C2C2C),
    ),
    CategoryItem(
      id: 'gaming',
      name: 'Gaming',
      icon: Icons.sports_esports,
      selectedColor: const Color(0xFF3F51B5),
      unselectedColor: const Color(0xFF2C2C2C),
    ),
  ];

  bool get _canContinue => _selectedCategories.length >= _minRequired;

  @override
  void initState() {
    super.initState();
    // 2. Fetch existing interests from Firestore on init
    _loadExistingInterests();
  }

  // 2. Load existing interests from Firestore
  Future<void> _loadExistingInterests() async {
    try {
      final currentUser = AuthService.getCurrentUser();
      if (currentUser == null) {
        setState(() => _isLoadingExisting = false);
        return;
      }

      final doc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['interests'] != null) {
          final interests = data['interests'];
          if (interests is List) {
            setState(() {
              _selectedCategories.addAll(interests.cast<String>());
            });
          } else if (interests is String && interests.isNotEmpty) {
            // Legacy comma-separated format support
            setState(() {
              _selectedCategories.addAll(interests.split(','));
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading existing interests: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingExisting = false);
      }
    }
  }

  void _toggleCategory(String categoryId) {
    setState(() {
      if (_selectedCategories.contains(categoryId)) {
        _selectedCategories.remove(categoryId);
      } else {
        _selectedCategories.add(categoryId);
      }
    });
  }

  Future<void> _onContinue() async {
    if (!_canContinue) return;

    setState(() {
      _isSaving = true;
    });

    await _saveInterestsToFirestore();
  }

  Future<void> _saveInterestsToFirestore() async {
    final currentUser = AuthService.getCurrentUser();

    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not authenticated'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isSaving = false;
        });
      }
      return;
    }

    final uid = currentUser.uid;
    final interestsList = _selectedCategories.toList();

    debugPrint('Saving interests as List: $interestsList for user: $uid');

    try {
      // Firestore — source of truth
      await _firestore.collection('users').doc(uid).set(
        {'interests': interestsList},
        SetOptions(merge: true),
      );

      debugPrint('Interests saved successfully as List');

      // 4. SharedPreferences — offline backup only (not primary source)
      await _saveSelectedCategoriesLocalBackup();

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Interests saved successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const MainScreen(),
            ),
                (route) => false,
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving interests: $e');

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save interests. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // 4. SharedPreferences — offline backup only
  Future<void> _saveSelectedCategoriesLocalBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'selected_categories',
        _selectedCategories.toList(),
      );
      debugPrint('Categories saved to SharedPreferences (offline backup)');
    } catch (e) {
      debugPrint('Error saving to SharedPreferences: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. PopScope instead of deprecated WillPopScope
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: const Color(0xFF1F1F1F),
        body: SafeArea(
          child: _isLoadingExisting
              ? const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFFF3B5C),
            ),
          )
              : Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 32),

                        // Header Section
                        Column(
                          children: [
                            const Text(
                              'What interests you?',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Choose at least 3 categories to personalize your feed',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[400],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),

                            // Selection Counter
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF3B5C)
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFFF3B5C)
                                      .withOpacity(0.4),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '${_selectedCategories.length}/$_minRequired+ selected',
                                style: const TextStyle(
                                  color: Color(0xFFFF3B5C),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Categories Grid
                        // 5. AnimatedScale instead of AnimationController per card
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1.5,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            final category = _categories[index];
                            final isSelected =
                            _selectedCategories.contains(category.id);

                            return _buildCategoryCard(
                              category: category,
                              isSelected: isSelected,
                              onTap: () => _toggleCategory(category.id),
                            );
                          },
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Section with Continue Button
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Material(
                  elevation: _canContinue ? 8 : 0,
                  borderRadius: BorderRadius.circular(28),
                  child: InkWell(
                    onTap: (_canContinue && !_isSaving)
                        ? _onContinue
                        : null,
                    borderRadius: BorderRadius.circular(28),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: _canContinue
                            ? const LinearGradient(
                          colors: [
                            Color(0xFFFF3B5C),
                            Color(0xFFCC1F3E),
                          ],
                        )
                            : null,
                        color: _canContinue
                            ? null
                            : const Color(0xFF3A3A3A),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: _canContinue
                            ? [
                          BoxShadow(
                            color: const Color(0xFFFF3B5C)
                                .withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ]
                            : [],
                      ),
                      child: Center(
                        child: _isSaving
                            ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                            AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                            : Text(
                          _canContinue
                              ? 'Continue'
                              : 'Select ${_minRequired - _selectedCategories.length} more',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _canContinue
                                ? Colors.white
                                : Colors.grey[600],
                          ),
                        ),
                      ),
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

  // 5. AnimatedScale — no AnimationController needed per card
  Widget _buildCategoryCard({
    required CategoryItem category,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return AnimatedScale(
      scale: isSelected ? 0.95 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected
                ? category.selectedColor
                : category.unselectedColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? category.selectedColor
                  : const Color(0xFF3A3A3A),
              width: isSelected ? 3 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? category.selectedColor.withOpacity(0.4)
                    : Colors.black.withOpacity(0.2),
                blurRadius: isSelected ? 12 : 4,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Content
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      category.icon,
                      size: 36,
                      color: isSelected
                          ? Colors.white
                          : category.selectedColor,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      category.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.grey[300],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Selection Indicator
              if (isSelected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.check,
                      color: category.selectedColor,
                      size: 18,
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

class CategoryItem {
  final String id;
  final String name;
  final IconData icon;
  final Color selectedColor;
  final Color unselectedColor;

  CategoryItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.selectedColor,
    required this.unselectedColor,
  });
}