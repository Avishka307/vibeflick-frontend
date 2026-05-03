import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ActivityLanguage extends StatefulWidget {
  const ActivityLanguage({Key? key}) : super(key: key);

  @override
  State<ActivityLanguage> createState() => _ActivityLanguageState();
}

class _ActivityLanguageState extends State<ActivityLanguage> {
  String _selectedLanguage = 'en';
  late SharedPreferences _prefs;

  final List<LanguageOption> _languages = [
    LanguageOption(
      code: 'en',
      name: 'English',
      nativeName: 'English (US)',
      flag: '🇬🇧',
      color: Color(0xFFE3F2FD),
      accentColor: Color(0xFF1976D2),
    ),
    LanguageOption(
      code: 'si',
      name: 'සිංහල',
      nativeName: 'Sinhala',
      flag: '🇱🇰',
      color: Color(0xFFF3E5F5),
      accentColor: Color(0xFF7B1FA2),
    ),
    LanguageOption(
      code: 'ta',
      name: 'தமிழ்',
      nativeName: 'Tamil',
      flag: '🇱🇰',
      color: Color(0xFFE8F5E9),
      accentColor: Color(0xFF388E3C),
    ),
    LanguageOption(
      code: 'hi',
      name: 'हिन्दी',
      nativeName: 'Hindi',
      flag: '🇮🇳',
      color: Color(0xFFFFF3E0),
      accentColor: Color(0xFFF57C00),
    ),
    LanguageOption(
      code: 'es',
      name: 'Español',
      nativeName: 'Spanish',
      flag: '🇪🇸',
      color: Color(0xFFFFEBEE),
      accentColor: Color(0xFFDC2626),
    ),
    LanguageOption(
      code: 'fr',
      name: 'Français',
      nativeName: 'French',
      flag: '🇫🇷',
      color: Color(0xFFE1F5FE),
      accentColor: Color(0xFF0288D1),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = _prefs.getString('app_language') ?? 'en';
    });
  }

  Future<void> _applyLanguage() async {
    await _prefs.setString('app_language', _selectedLanguage);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Language changed successfully'),
        backgroundColor: Colors.green,
      ),
    );

    // In a real app, you would apply the locale here
    // For now, just show success message
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Select your preferred language',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF757575),
                      ),
                    ),
                  ),
                  _buildLanguageList(),
                  _buildApplyButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6B4CE6), Color(0xFF9B59D0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 55, 16, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Language',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < _languages.length; i++) ...[
            _buildLanguageItem(_languages[i]),
            if (i < _languages.length - 1) _buildDivider(),
          ],
        ],
      ),
    );
  }

  Widget _buildLanguageItem(LanguageOption language) {
    final isSelected = _selectedLanguage == language.code;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedLanguage = language.code;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: language.color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  language.flag,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    language.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    language.nativeName,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF757575),
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: language.code,
              groupValue: _selectedLanguage,
              onChanged: (value) {
                setState(() {
                  _selectedLanguage = value!;
                });
              },
              activeColor: language.accentColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.only(left: 84, right: 20),
      height: 1,
      color: const Color(0xFFF0F0F0),
    );
  }

  Widget _buildApplyButton() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1976D2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1976D2).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _applyLanguage,
          borderRadius: BorderRadius.circular(12),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text(
                'Apply Language',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LanguageOption {
  final String code;
  final String name;
  final String nativeName;
  final String flag;
  final Color color;
  final Color accentColor;

  LanguageOption({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
    required this.color,
    required this.accentColor,
  });
}