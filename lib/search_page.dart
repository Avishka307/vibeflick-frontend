import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_vibe_flick/screens/algolia_admin_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'widgets/search_input_field.dart';
import 'widgets/explore_section.dart';
import 'widgets/search_suggestions_dropdown.dart';
import 'widgets/search_results_tabs.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  bool _isSearching = false;
  bool _hasSearched = false;
  String _currentQuery = '';
  Timer? _debounce;

  String? _currentUserId;

  // 🕐 Recent search history (local, phone-only)
  static const String _recentSearchesKey = 'recent_searches';
  static const int _maxRecentSearches = 10;
  List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid;
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);
    _loadRecentSearches();
    _checkAlgoliaOnFirstLoad();
    // 🎹 Keyboard dismiss scroll කරද්දී
    _scrollController.addListener(() {
      if (_scrollController.position.userScrollDirection !=
          ScrollDirection.idle) {
        _searchFocusNode.unfocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  // 🕐 Recent Search History - Local Storage
  // ─────────────────────────────────────────────────────────

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_recentSearchesKey) ?? [];
      setState(() {
        _recentSearches = saved;
      });
      debugPrint('📂 Loaded ${saved.length} recent searches');
    } catch (e) {
      debugPrint('❌ Failed to load recent searches: $e');
    }
  }
// ─────────────────────────────────────────────────────────
// 🔄 Algolia Auto-Sync — App open වෙද්දී background check
// ─────────────────────────────────────────────────────────
  Future<void> _checkAlgoliaOnFirstLoad() async {
    // Background — UI block නොකරයි
    AlgoliaAdminService.runFullSyncIfNeeded(
      onProgress: (msg) => debugPrint('🔄 Algolia: $msg'),
    );
  }
  Future<void> _saveRecentSearch(String query) async {
    if (query.trim().isEmpty) return;

    try {
      // දැනටමත් ඇතිනම් ඉවත් කරලා ඉහළින් දාන්න
      _recentSearches.remove(query);
      _recentSearches.insert(0, query);

      // Maximum limit
      if (_recentSearches.length > _maxRecentSearches) {
        _recentSearches = _recentSearches.sublist(0, _maxRecentSearches);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentSearchesKey, _recentSearches);

      setState(() {});
      debugPrint('💾 Saved recent search: "$query"');
    } catch (e) {
      debugPrint('❌ Failed to save recent search: $e');
    }
  }
// ─────────────────────────────────────────────────────────
  // 🌐 Internet Connection Check
  // ─────────────────────────────────────────────────────────
  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 12),
                Text('No internet connection'),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
    return false;
  }
  Future<void> _deleteRecentSearch(String query) async {
    try {
      _recentSearches.remove(query);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentSearchesKey, _recentSearches);
      setState(() {});
      debugPrint('🗑️ Deleted recent search: "$query"');
    } catch (e) {
      debugPrint('❌ Failed to delete recent search: $e');
    }
  }

  Future<void> _clearAllRecentSearches() async {
    try {
      _recentSearches.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentSearchesKey);
      setState(() {});
      debugPrint('🗑️ Cleared all recent searches');
    } catch (e) {
      debugPrint('❌ Failed to clear recent searches: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // 🔥 Trending Searches - Server Tracking
  // ─────────────────────────────────────────────────────────

  Future<void> _trackSearchOnServer(String query) async {
    try {
      await http.post(
        Uri.parse('https://avishka-tiktok-api.zeabur.app/api/track-search'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'keyword': query.trim().toLowerCase()}),
      );
      debugPrint('📊 Tracked search on server: "$query"');
    } catch (e) {
      debugPrint('⚠️ Search tracking failed (non-critical): $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // Search Logic
  // ─────────────────────────────────────────────────────────

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _currentQuery = _searchController.text.trim();
        _isSearching = _currentQuery.isNotEmpty;
      });
    });
  }

  void _onFocusChanged() {
    setState(() {});
  }

  void _performSearch() async {
    if (_searchController.text.trim().isEmpty) return;

    // 🌐 Internet check
    final hasInternet = await _checkInternetConnection();
    if (!hasInternet) return;

    HapticFeedback.lightImpact();
    _searchFocusNode.unfocus();

    final query = _searchController.text.trim         ();
    _saveRecentSearch(query);
    _trackSearchOnServer(query);

    setState(() {
      _hasSearched = true;
      _currentQuery = query;
      _isSearching = false;
    });
  }

  void _clearSearch() {
    // 📳 Haptic feedback
    HapticFeedback.lightImpact();

    _searchController.clear();
    setState(() {
      _isSearching = false;
      _hasSearched = false;
      _currentQuery = '';
    });
  }

  void _onVoiceSearch() {
    // 📳 Haptic feedback
    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Voice search - Coming soon!'),
        duration: Duration(seconds: 1),
        backgroundColor: Color(0xFF1E1E1E),
      ),
    );
  }

  void _onSuggestionTap(String suggestion) {
    // 📳 Haptic feedback
    HapticFeedback.selectionClick();

    _searchController.text = suggestion;
    _performSearch();
  }

  void _onHashtagTap(String hashtag) {
    // 📳 Haptic feedback
    HapticFeedback.selectionClick();

    _searchController.text = hashtag;
    _performSearch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // 🔍 Sticky Search Header
            SearchInputField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onClear: _clearSearch,
              onVoiceSearch: _onVoiceSearch,
              onSubmitted: (_) => _performSearch(),
            ),

            // 📱 Main Content
            Expanded(
              child: Stack(
                children: [
                  // Content based on state
                  if (!_hasSearched && !_isSearching)
                    ExploreSection(
                      onHashtagTap: _onHashtagTap,
                      currentUserId: _currentUserId,
                      // 🆕 Recent history props
                      recentSearches: _recentSearches,
                      onRecentSearchTap: _onSuggestionTap,
                      onDeleteRecentSearch: _deleteRecentSearch,
                      onClearAllRecent: _clearAllRecentSearches,
                    )
                  else if (_hasSearched)
                    SearchResultsTabs(
                      query: _currentQuery,
                      scrollController: _scrollController,
                      currentUserId: _currentUserId,
                    ),

                  // 💬 Search Suggestions Overlay
                  if (_isSearching && _searchFocusNode.hasFocus)
                    SearchSuggestionsDropdown(
                      query: _currentQuery,
                      onSuggestionTap: _onSuggestionTap,
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