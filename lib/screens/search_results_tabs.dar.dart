import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tabs/hashtags_search_tab.dart';
import '../tabs/sounds_search_tab.dart';
import '../tabs/videos_search_tab.dart';
import '../widgets/tabs/users_search_tab.dart';


class SearchResultsTabs extends StatefulWidget {
  final String query;
  final ScrollController scrollController;
  final String? currentUserId;

  const SearchResultsTabs({
    super.key,
    required this.query,
    required this.scrollController,
    this.currentUserId,
  });

  @override
  State<SearchResultsTabs> createState() => _SearchResultsTabsState();
}

class _SearchResultsTabsState extends State<SearchResultsTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Lazy loading - track which tabs have been visited
  final Set<int> _loadedTabs = {0}; // Users tab loads first

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        HapticFeedback.selectionClick();
        setState(() {
          _loadedTabs.add(_tabController.index);
        });
        debugPrint('📌 Lazy load tab: ${_tabController.index}');
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Results for "${widget.query}"',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ),
        ),

        // Tab Bar
        Container(
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            indicatorColor: const Color(0xFFFF0050),
            indicatorWeight: 2.5,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(0.4),
            labelStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              Tab(text: 'Users'),
              Tab(text: 'Videos'),
              Tab(text: 'Sounds'),
              Tab(text: 'Hashtags'),
            ],
          ),
        ),

        // Tab Content - Lazy loaded
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _loadedTabs.contains(0)
                  ? UsersSearchTab(query: widget.query, currentUserId: widget.currentUserId)
                  : const SizedBox.shrink(),
              _loadedTabs.contains(1)
                  ? VideosSearchTab(query: widget.query, currentUserId: widget.currentUserId)
                  : const SizedBox.shrink(),
              _loadedTabs.contains(2)
                  ? SoundsSearchTab(query: widget.query)
                  : const SizedBox.shrink(),
              _loadedTabs.contains(3)
                  ? HashtagsSearchTab(query: widget.query)
                  : const SizedBox.shrink(),
            ],
          ),
        ),
      ],
    );
  }
}