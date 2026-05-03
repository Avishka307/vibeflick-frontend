import 'package:flutter/material.dart';
import 'results_tabs/top_tab.dart';
import 'results_tabs/users_tab.dart';
import 'results_tabs/videos_tab.dart';
import 'results_tabs/sounds_tab.dart';
import 'results_tabs/hashtags_tab.dart';

class SearchResults extends StatefulWidget {
  final String query;
  final ScrollController scrollController;

  const SearchResults({
    super.key,
    required this.query,
    required this.scrollController,
  });

  @override
  State<SearchResults> createState() => _SearchResultsState();
}

class _SearchResultsState extends State<SearchResults>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
        // Results Count
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          alignment: Alignment.centerLeft,
          child: Text(
            'Results for "${widget.query}"',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),

        // Tab Bar
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.black.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: const Color(0xFFFF0050),
            indicatorWeight: 3,
            labelColor: const Color(0xFFFF0050),
            unselectedLabelColor: Colors.black.withOpacity(0.5),
            labelStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            tabAlignment: TabAlignment.start,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            tabs: const [
              Tab(text: 'Top'),
              Tab(text: 'Users'),
              Tab(text: 'Videos'),
              Tab(text: 'Sounds'),
              Tab(text: 'Hashtags'),
            ],
          ),
        ),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              TopTab(query: widget.query),
              UsersTab(query: widget.query),
              VideosTab(query: widget.query),
              SoundsTab(query: widget.query),
              HashtagsTab(query: widget.query),
            ],
          ),
        ),
      ],
    );
  }
}