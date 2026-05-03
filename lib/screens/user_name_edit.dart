import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';

class UserNameEditScreen extends StatefulWidget {
  final String currentUsername;
  final String userId;

  const UserNameEditScreen({
    super.key,
    this.currentUsername = '',
    required this.userId,
  });

  @override
  State<UserNameEditScreen> createState() => _UserNameEditScreenState();
}

class _UserNameEditScreenState extends State<UserNameEditScreen> with WidgetsBindingObserver {
  final TextEditingController _usernameController = TextEditingController();
  final int _maxLength = 20;

  static const String BASE_URL = "https://avishka-tiktok-api.zeabur.app";

  bool? _isAvailable;
  String _errorMessage = '';
  List<String> _suggestions = [];
  bool _isCheckingAvailability = false;
  bool _isSaving = false;
  bool _canChangeUsername = true;
  int _daysRemaining = 0;
  bool _isLoading = true;
  bool _hasInternetConnection = true;

  Timer? _debounceTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  final List<String> _profanityList = [
    'admin', 'administrator', 'root', 'moderator', 'mod', 'support', 'staff',
    'official', 'system', 'verified', 'tiktok', 'instagram', 'facebook',
    'twitter', 'youtube', 'google', 'fuck', 'shit', 'damn', 'ass', 'bitch',
    'bastard', 'hell', 'piss', 'cunt', 'dick', 'cock', 'pussy', 'whore', 'slut',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _usernameController.text = widget.currentUsername;

    // 🆕 Debug: Print initial state
    _debugLog('🎬 Screen initialized');
    _debugLog('📝 User ID: ${widget.userId}');
    _debugLog('👤 Current Username: "${widget.currentUsername}"');

    _initializeScreen();
    _usernameController.addListener(_onUsernameChanged);
    _setupConnectivityListener();
  }

  @override
  void dispose() {
    _debugLog('🛑 Screen disposed');
    WidgetsBinding.instance.removeObserver(this);
    _usernameController.dispose();
    _debounceTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  // 🆕 Debug helper function
  void _debugLog(String message) {
    print('🔍 [USERNAME_EDIT] $message');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final username = _usernameController.text.trim().toLowerCase();
      if (username.isNotEmpty && username.length >= 3) {
        _validateUsername(username);
      }
    }
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final hasConnection = results.any((result) =>
      result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet
      );

      if (mounted) {
        setState(() {
          _hasInternetConnection = hasConnection;
        });

        if (!hasConnection) {
          _debugLog('❌ Internet connection lost');
          _showSnackbar('No Internet Connection', Colors.red);
        } else {
          _debugLog('✅ Internet connection restored');
        }
      }
    });
  }

  Future<bool> _checkInternetConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final hasConnection = connectivityResult.any((result) =>
    result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet
    );

    if (!hasConnection) {
      _debugLog('❌ No internet connection');
      _showSnackbar('No Internet Connection', Colors.red);
      return false;
    }
    return true;
  }

  Future<void> _initializeScreen() async {
    setState(() => _isLoading = true);
    _debugLog('⏳ Loading screen...');

    if (!await _checkInternetConnection()) {
      setState(() => _isLoading = false);
      return;
    }

    await _checkUsernameCooldown();

    if (mounted) {
      setState(() => _isLoading = false);
      _debugLog('✅ Screen loaded successfully');
    }
  }

  Future<void> _checkUsernameCooldown() async {
    try {
      _debugLog('🔍 Checking cooldown for user: ${widget.userId}');

      final response = await http.get(
        Uri.parse('$BASE_URL/api/v1/check-username-cooldown/${widget.userId}'),
      ).timeout(const Duration(seconds: 10));

      _debugLog('📡 Cooldown response status: ${response.statusCode}');
      _debugLog('📦 Cooldown response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _canChangeUsername = data['canChange'] ?? true;
            _daysRemaining = data['daysRemaining'] ?? 0;
          });

          if (_canChangeUsername) {
            _debugLog('✅ User can change username');
          } else {
            // 🆕 Check if this is an auto-generated username (first time)
            // Auto-generated usernames can be changed freely (no cooldown)
            if (data['isAutoGenerated'] == true) {
              setState(() {
                _canChangeUsername = true;
                _daysRemaining = 0;
              });
              _debugLog('✅ Auto-generated username — cooldown bypassed');
            } else {
              _debugLog('⏰ Cooldown active: $_daysRemaining days remaining');
            }
          }
        }
      }
    } catch (e) {
      _debugLog('❌ Cooldown check error: $e');
    }
  }

  void _onUsernameChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      final currentText = _usernameController.text;
      _debugLog('⌨️ Username input: "$currentText"');
      _validateUsername(currentText);
    });
  }

  void _validateUsername(String text) {
    if (!mounted) return;

    setState(() {
      _errorMessage = '';
      _isAvailable = null;
      _suggestions = [];
    });

    if (text.isEmpty) {
      _debugLog('⚠️ Validation: Empty username');
      return;
    }

    final cleanText = text.trim().toLowerCase();
    _debugLog('🔍 Validating username: "$cleanText"');

    // Length validation
    if (cleanText.length < 3) {
      _debugLog('❌ Validation failed: Too short (${cleanText.length} chars)');
      setState(() {
        _errorMessage = 'Username must be at least 3 characters';
        _isAvailable = false;
      });
      return;
    }

    // Format validation
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(cleanText)) {
      _debugLog('❌ Validation failed: Invalid format');
      setState(() {
        _errorMessage = 'Only lowercase letters, numbers and underscores allowed';
        _isAvailable = false;
      });
      return;
    }

    // Profanity check
    if (_containsProfanity(cleanText)) {
      _debugLog('❌ Validation failed: Contains profanity');
      setState(() {
        _errorMessage = 'Username contains inappropriate words';
        _isAvailable = false;
      });
      return;
    }

    // Same as current username
    if (widget.currentUsername.isNotEmpty &&
        cleanText == widget.currentUsername.toLowerCase()) {
      _debugLog('⚠️ Validation: Same as current username');
      setState(() {
        _errorMessage = 'This is your current username';
        _isAvailable = false;
      });
      return;
    }

    _debugLog('✅ Client-side validation passed');
    _checkAvailability(cleanText);
  }

  bool _containsProfanity(String text) {
    final lowerText = text.toLowerCase();
    return _profanityList.any((word) => lowerText.contains(word.toLowerCase()));
  }

  Future<void> _checkAvailability(String username) async {
    if (!mounted) return;

    setState(() {
      _isCheckingAvailability = true;
      _errorMessage = '';
      _isAvailable = null;
      _suggestions = [];
    });

    _debugLog('🔍 Checking availability for: "$username"');

    try {
      final url = '$BASE_URL/api/v1/check-username-availability/$username';
      _debugLog('📡 API Request: GET $url');

      final response = await http.get(
        Uri.parse(url),
      ).timeout(const Duration(seconds: 10));

      _debugLog('📡 Availability response status: ${response.statusCode}');
      _debugLog('📦 Availability response body: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          _isCheckingAvailability = false;
          _isAvailable = data['available'] ?? false;

          if (_isAvailable!) {
            _debugLog('✅ Username "$username" is AVAILABLE');
          } else {
            _debugLog('❌ Username "$username" is TAKEN');
            _errorMessage = data['message'] ?? 'Username is already taken';
            _generateSuggestions(username);
          }
        });
      } else {
        _debugLog('❌ Availability check failed with status: ${response.statusCode}');
        setState(() {
          _isCheckingAvailability = false;
          _errorMessage = 'Error checking availability';
          _isAvailable = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _debugLog('❌ Availability check error: $e');
      setState(() {
        _isCheckingAvailability = false;
        _errorMessage = 'Network error. Please try again';
        _isAvailable = false;
      });
    }
  }

  void _generateSuggestions(String base) {
    final random = DateTime.now().millisecondsSinceEpoch % 999;
    final suggestions = [
      '${base}_$random',
      '${base}_${random + 1}',
      'the_$base',
      '${base}_user',
    ];

    _debugLog('💡 Generated suggestions: ${suggestions.join(", ")}');

    setState(() {
      _suggestions = suggestions;
    });
  }

  Future<void> _handleSave() async {
    if (!await _checkInternetConnection()) {
      return;
    }

    if (!_canChangeUsername) {
      _debugLog('⏰ Save blocked: Cooldown active ($_daysRemaining days)');
      _showSnackbar('You can change username in $_daysRemaining days', Colors.orange);
      return;
    }

    final newUsername = _usernameController.text.trim().toLowerCase();
    _debugLog('💾 Save attempt: "$newUsername"');

    // Validate before saving
    if (newUsername.isEmpty || newUsername.length < 3) {
      _debugLog('❌ Save failed: Username too short');
      setState(() => _errorMessage = 'Username must be at least 3 characters');
      return;
    }

    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(newUsername)) {
      _debugLog('❌ Save failed: Invalid format');
      setState(() => _errorMessage = 'Only lowercase letters, numbers and underscores allowed');
      return;
    }

    if (_containsProfanity(newUsername)) {
      _debugLog('❌ Save failed: Contains profanity');
      setState(() => _errorMessage = 'Username contains inappropriate words');
      return;
    }

    if (widget.currentUsername.isNotEmpty &&
        newUsername == widget.currentUsername.toLowerCase()) {
      _debugLog('❌ Save failed: Same as current username');
      setState(() => _errorMessage = 'This is your current username');
      return;
    }

    if (_isAvailable != true) {
      _debugLog('❌ Save failed: Username not available');
      setState(() => _errorMessage = 'Please choose an available username');
      return;
    }

    setState(() => _isSaving = true);
    _debugLog('⏳ Saving username...');

    try {
      final requestBody = {
        'userId': widget.userId,
        'newUsername': newUsername,
        'oldUsername': widget.currentUsername.isEmpty ? null : widget.currentUsername.toLowerCase(),
      };

      _debugLog('📡 API Request: POST $BASE_URL/api/v1/update-username');
      _debugLog('📦 Request body: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse('$BASE_URL/api/v1/update-username'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 15));

      _debugLog('📡 Update response status: ${response.statusCode}');
      _debugLog('📦 Update response body: ${response.body}');

      if (!mounted) return;

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        _debugLog('✅ Username updated successfully!');
        _debugLog('🎉 New username: "$newUsername"');

        _showSnackbar('Username updated successfully!', Colors.green);
        await Future.delayed(const Duration(milliseconds: 500));

        _debugLog('🔙 Returning to previous screen with new username');
        Navigator.of(context).pop(newUsername);
      } else {
        _debugLog('❌ Update failed: ${responseData['message']}');

        setState(() {
          _isSaving = false;
          _errorMessage = responseData['message'] ?? 'Failed to update username';
        });

        // 🆕 වැඩිදියුණු කළ error handling - UI වල error message එකක් විතරයි
        if (responseData['message']?.contains('already taken') == true ||
            responseData['message']?.contains('භාවිතා') == true) {
          _generateSuggestions(newUsername);
        }
      }

    } catch (e) {
      if (!mounted) return;
      _debugLog('❌ Save error: $e');

      setState(() {
        _isSaving = false;
        _errorMessage = 'Network error. Please try again';
      });
    }
  }

  void _showSnackbar(String message, Color color) {
    if (!mounted) return;

    _debugLog('📢 Snackbar: $message');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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
            'Edit Username',
            style: TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(
                  color: Color(0xFF757575),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Edit Username',
            style: TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                ),
              )
                  : const Icon(
                Icons.check,
                color: Color(0xFF2196F3),
                size: 28,
              ),
              onPressed: (_isAvailable == true && !_isSaving && _canChangeUsername)
                  ? _handleSave
                  : null,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // No internet warning
              if (!_hasInternetConnection)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF44336)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.wifi_off, color: Color(0xFFF44336), size: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No Internet Connection',
                          style: TextStyle(
                            color: Color(0xFFF44336),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Cooldown warning
              if (!_canChangeUsername)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFF9800)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_clock, color: Color(0xFFFF9800), size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You can change username in $_daysRemaining days',
                          style: const TextStyle(
                            color: Color(0xFFFF9800),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Username input
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isAvailable == true
                        ? const Color(0xFF4CAF50)
                        : _isAvailable == false
                        ? const Color(0xFFF44336)
                        : const Color(0xFFE0E0E0),
                    width: _isAvailable != null ? 2 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.alternate_email, size: 20, color: Color(0xFF757575)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _usernameController,
                          enabled: _canChangeUsername,
                          maxLength: _maxLength,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) {
                            FocusScope.of(context).unfocus();
                            if (_isAvailable == true && !_isSaving && _canChangeUsername) {
                              _handleSave();
                            }
                          },
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
                            LowerCaseTextFormatter(),
                          ],
                          decoration: const InputDecoration(
                            hintText: 'Enter username',
                            hintStyle: TextStyle(color: Color(0xFF9E9E9E)),
                            border: InputBorder.none,
                            counterText: '',
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // Status icon
                      if (_isCheckingAvailability)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (_isAvailable == true)
                        const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 22)
                      else if (_isAvailable == false)
                          const Icon(Icons.cancel, color: Color(0xFFF44336), size: 22),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Character count
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${_usernameController.text.length}/$_maxLength',
                    style: const TextStyle(
                      color: Color(0xFF757575),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 🆕 වැඩිදියුණු කළ Error message (Snackbar එකක් නැහැ)
              if (_errorMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF44336)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFF44336), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(
                            color: Color(0xFFF44336),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Suggestions
              if (_suggestions.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Try these suggestions:',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF757575),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _suggestions.map((suggestion) {
                    return GestureDetector(
                      onTap: () {
                        _usernameController.text = suggestion;
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF2196F3)),
                        ),
                        child: Text(
                          suggestion,
                          style: const TextStyle(
                            color: Color(0xFF2196F3),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 20),

              // Requirements
              const Text(
                'Username requirements:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              _buildRequirement('3-20 characters long'),
              _buildRequirement('Lowercase letters, numbers and underscores only'),
              _buildRequirement('Must be unique'),
              _buildRequirement('Can only be changed once every 14 days after first edit'),


              const SizedBox(height: 20),

              // Info box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFFFF9800), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Username can only be changed once every 14 days after first manual edit',
                        style: TextStyle(
                          color: Color(0xFFFF9800),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequirement(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.fiber_manual_record, size: 8, color: Color(0xFF757575)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF757575),
            ),
          ),
        ],
      ),
    );
  }
}

class LowerCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    return TextEditingValue(
      text: newValue.text.toLowerCase(),
      selection: newValue.selection,
    );
  }
}