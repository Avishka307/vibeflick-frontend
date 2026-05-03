import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'history_tab.dart';
import 'contact_tab.dart';
import 'drafts_tab.dart';

class SocialCardsTabs extends StatefulWidget {
  final int initialTab;
  const SocialCardsTabs({Key? key, this.initialTab = 0}) : super(key: key);

  @override
  State<SocialCardsTabs> createState() => _SocialCardsTabsState();
}

class _SocialCardsTabsState extends State<SocialCardsTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeTab = 0;

  // ✅ GlobalKey - HistoryTab refresh කරන්න
  final GlobalKey<HistoryTabState> _historyTabKey = GlobalKey<HistoryTabState>();

  final List<Map<String, dynamic>> _tabs = [
    {
      'label': 'History',
      'icon': Icons.history,
    },
    {
      'label': 'Contact',
      'icon': Icons.people_alt_rounded,
    },
    {
      'label': 'Drafts',
      'icon': Icons.pending_actions_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _activeTab = widget.initialTab;
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        final newIndex = _tabController.index;
        setState(() => _activeTab = newIndex);

        // ✅ History tab (index 0) select කළාම refresh කරනවා
        if (newIndex == 0) {
          _historyTabKey.currentState?.loadHistory();
        }
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
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
        ),
        title: const Text('', style: TextStyle(color: Colors.white)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _buildTabBar(),
        ),
      ),
      body: _buildTabContent(),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  TAB BAR
  // ══════════════════════════════════════════════════════════
  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.fromLTRB(20, 20, 10, 12),
      child: Row(
        children: List.generate(_tabs.length, (index) {
          final bool active = _activeTab == index;
          final String label = _tabs[index]['label'] as String;
          final IconData icon = _tabs[index]['icon'] as IconData;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _activeTab = index;
                  _tabController.animateTo(index);
                });

                // ✅ History tab tap කළාම refresh
                if (index == 0) {
                  _historyTabKey.currentState?.loadHistory();
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        icon,
                        size: 15,
                        color: active
                            ? Colors.white
                            : const Color(0xFF666666),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                          active ? FontWeight.w700 : FontWeight.w500,
                          color: active
                              ? Colors.white
                              : const Color(0xFF666666),
                          letterSpacing: active ? 0.2 : 0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 2.5,
                    width: active ? 32 : 0,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA314E),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  TAB CONTENT
  // ══════════════════════════════════════════════════════════
  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        // ✅ GlobalKey pass කළා - refresh trigger කරන්න
        HistoryTab(key: _historyTabKey),
        const ContactTab(),
        const DraftsTab(),
      ],
    );
  }
}