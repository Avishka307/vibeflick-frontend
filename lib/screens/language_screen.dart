import 'package:flutter/material.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({Key? key}) : super(key: key);

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  // App එක සම්පූර්ණයෙන් English නිසා මේක always 'en' වෙලා locked වෙලා තියෙනවා
  final String _selectedLanguage = 'en';

  final List<Map<String, dynamic>> _languages = [
    {
      'code': 'en',
      'name': 'English',
      'localName': 'English',
      'flag': '🇬🇧',
      'available': true,
    },
    {
      'code': 'si',
      'name': 'Sinhala',
      'localName': 'සිංහල',
      'flag': '🇱🇰',
      'available': false,
    },
    {
      'code': 'ta',
      'name': 'Tamil',
      'localName': 'தமிழ்',
      'flag': '🇱🇰',
      'available': false,
    },
    {
      'code': 'fr',
      'name': 'French',
      'localName': 'Français',
      'flag': '🇫🇷',
      'available': false,
    },
    {
      'code': 'de',
      'name': 'German',
      'localName': 'Deutsch',
      'flag': '🇩🇪',
      'available': false,
    },
    {
      'code': 'ja',
      'name': 'Japanese',
      'localName': '日本語',
      'flag': '🇯🇵',
      'available': false,
    },
    {
      'code': 'zh',
      'name': 'Chinese',
      'localName': '中文',
      'flag': '🇨🇳',
      'available': false,
    },
    {
      'code': 'es',
      'name': 'Spanish',
      'localName': 'Español',
      'flag': '🇪🇸',
      'available': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF3B5C), Color(0xFFFF3B5C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            title: const Text(
              'Language',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.4,
              ),
            ),
            centerTitle: true,
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // Current Language Info Banner
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF3B5C), Color(0xFFFF3B5C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.language,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Language',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '🇬🇧  English',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Section header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    'SELECT LANGUAGE',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.6),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.65,
                    ),
                  ),
                ),

                // Language List
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: _languages.asMap().entries.map((entry) {
                      final index = entry.key;
                      final lang = entry.value;
                      final isSelected = _selectedLanguage == lang['code'];
                      final isAvailable = lang['available'] as bool;
                      final isLast = index == _languages.length - 1;

                      return Column(
                        children: [
                          InkWell(
                            onTap: isAvailable
                                ? null // English already selected, no action needed
                                : () => _showComingSoonSnackbar(
                                context, lang['name']),
                            borderRadius: BorderRadius.circular(16),
                            child: Opacity(
                              opacity: isAvailable ? 1.0 : 0.45,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                                child: Row(
                                  children: [
                                    // Flag
                                    Text(
                                      lang['flag'],
                                      style: const TextStyle(fontSize: 26),
                                    ),
                                    const SizedBox(width: 14),
                                    // Language name
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            lang['name'],
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: isSelected
                                                  ? const Color(0xFF43E97B)
                                                  : Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            lang['localName'],
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white
                                                  .withOpacity(0.5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Status indicator
                                    if (isSelected)
                                      Container(
                                        width: 26,
                                        height: 26,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [
                                              Color(0xFF43E97B),
                                              Color(0xFF38F9D7)
                                            ],
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      )
                                    else if (!isAvailable)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color:
                                          Colors.white.withOpacity(0.08),
                                          borderRadius:
                                          BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Soon',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color:
                                            Colors.white.withOpacity(0.4),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (!isLast)
                            Container(
                              margin: const EdgeInsets.only(left: 58),
                              height: 1,
                              color: Colors.white.withOpacity(0.07),
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 20),

                // Note
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '* More languages coming soon in future updates.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.35),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoonSnackbar(BuildContext context, String langName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$langName support coming soon!'),
        backgroundColor: const Color(0xFFBBACAC),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}