import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({Key? key}) : super(key: key);

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  String _selectedFilter = 'All';
  final List<String> _filterOptions = [
    'All',
    'Logins',
    'Posts',
    'Settings',
    'Security',
  ];

  // 🆕 Backend URL
  static const String SERVER_URL = 'https://avishka-tiktok-api.zeabur.app';

  // 🆕 State management
  List<ActivityItem> _activities = [];
  bool _isLoading = true;
  bool _hasInternetConnection = true;
  bool _showNoInternetToast = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // 🆕 Pagination
  int _currentPage = 1;
  final int _itemsPerPage = 20;
  bool _hasMoreData = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _checkInternetConnection();
    _listenToConnectivityChanges();
    _loadActivities();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // 🆕 Check internet connectivity
  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        if (mounted) {
          setState(() {
            _hasInternetConnection = true;
          });
        }
        return true;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasInternetConnection = false;
        });
        _showNoInternetConnection();
      }
      return false;
    }
    return false;
  }

  // Listen to connectivity changes
  void _listenToConnectivityChanges() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
          (List<ConnectivityResult> result) {
        final hasConnection = !result.contains(ConnectivityResult.none);

        if (mounted) {
          setState(() {
            _hasInternetConnection = hasConnection;
          });

          if (!hasConnection) {
            _showNoInternetConnection();
          }
        }
      },
    );
  }

  // 🆕 Show "No Internet" toast
  void _showNoInternetConnection() {
    if (!_showNoInternetToast && mounted) {
      setState(() {
        _showNoInternetToast = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.wifi_off, color: Colors.white),
              SizedBox(width: 12),
              Text('No internet connection'),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(top: 50, left: 16, right: 16),
        ),
      );

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showNoInternetToast = false;
          });
        }
      });
    }
  }

  // 🆕 Load activities from backend
  Future<void> _loadActivities({bool isRefresh = false}) async {
    print('\n📊 ========== LOADING ACTIVITY LOGS ==========');

    if (!await _checkInternetConnection()) {
      print('❌ No internet connection');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    if (isRefresh) {
      setState(() {
        _currentPage = 1;
        _hasMoreData = true;
        _activities.clear();
      });
    }

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not found");
      }

      print('👤 Loading activities for: ${user.uid}');
      print('📄 Page: $_currentPage, Limit: $_itemsPerPage');

      final response = await http.get(
        Uri.parse(
          '$SERVER_URL/api/activity-logs/${user.uid}?page=$_currentPage&limit=$_itemsPerPage',
        ),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      print('📥 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> activities = data['data'] ?? [];

        print('✅ Received ${activities.length} activities');

        if (mounted) {
          setState(() {
            if (activities.isEmpty) {
              _hasMoreData = false;
            } else {
              _activities.addAll(
                activities.map((json) => ActivityItem.fromJson(json)).toList(),
              );
              _currentPage++;
            }
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to load activities');
      }
    } catch (e) {
      print('❌ Error loading activities: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }

    print('==========================================\n');
  }

  // 🆕 Pagination scroll listener
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMoreData) {
      _loadActivities();
    }
  }

  // 🆕 Refresh activities
  Future<void> _refreshActivities() async {
    await _loadActivities(isRefresh: true);
  }

  List<ActivityItem> get _filteredActivities {
    if (_selectedFilter == 'All') return _activities;

    return _activities.where((activity) {
      switch (_selectedFilter) {
        case 'Logins':
          return activity.type == ActivityType.login;
        case 'Posts':
          return activity.type == ActivityType.post;
        case 'Settings':
          return activity.type == ActivityType.settings;
        case 'Security':
          return activity.type == ActivityType.security;
        default:
          return true;
      }
    }).toList();
  }

  Map<String, List<ActivityItem>> _groupActivitiesByDate() {
    final Map<String, List<ActivityItem>> grouped = {};
    final now = DateTime.now();

    for (var activity in _filteredActivities) {
      String dateKey;

      if (_isSameDay(activity.timestamp, now)) {
        dateKey = 'Today';
      } else if (_isSameDay(
          activity.timestamp, now.subtract(const Duration(days: 1)))) {
        dateKey = 'Yesterday';
      } else if (activity.timestamp
          .isAfter(now.subtract(const Duration(days: 7)))) {
        dateKey = 'Last Week';
      } else if (activity.timestamp
          .isAfter(now.subtract(const Duration(days: 30)))) {
        dateKey = 'Last Month';
      } else {
        dateKey = 'Older';
      }

      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(activity);
    }

    return grouped;
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _getRelativeTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(timestamp);
    }
  }

  void _showActivityDetails(ActivityItem activity) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF2A2A2A),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Row(
              children: [
                _getActivityIcon(activity.type, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    activity.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Divider(color: Color(0xFF3A3A3A)),
            const SizedBox(height: 16),

            // Details
            _buildDetailRow(
                Icons.access_time,
                'Time',
                DateFormat('MMM dd, yyyy - hh:mm a')
                    .format(activity.timestamp)),
            _buildDetailRow(Icons.phone_android, 'Device', activity.device),
            _buildDetailRow(Icons.location_on, 'Location', activity.location),
            _buildDetailRow(Icons.wifi, 'IP Address', activity.ipAddress),
            _buildDetailRow(
                Icons.check_circle,
                'Status',
                activity.status == ActivityStatus.success
                    ? 'Success'
                    : 'Failed',
                statusColor: activity.status == ActivityStatus.success
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFDC143C)),

            const SizedBox(height: 24),

            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A3A3A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value,
      {Color? statusColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white60, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: statusColor ?? Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🆕 Clear history with backend call
  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Clear Activity History?',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'This will permanently delete all your activity logs. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _clearHistory();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC143C),
            ),
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // 🆕 Clear history backend call
  Future<void> _clearHistory() async {
    print('\n🗑️ ========== CLEARING ACTIVITY HISTORY ==========');

    if (!await _checkInternetConnection()) {
      _showNoInternetConnection();
      return;
    }

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not found");

      print('🗑️ Clearing history for: ${user.uid}');

      final response = await http.delete(
        Uri.parse('$SERVER_URL/api/activity-logs/${user.uid}'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      print('📥 Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ History cleared successfully');

        if (mounted) {
          setState(() {
            _activities.clear();
            _currentPage = 1;
            _hasMoreData = true;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Activity history cleared'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error clearing history: $e');
    }

    print('==========================================\n');
  }

  Icon _getActivityIcon(ActivityType type, {double size = 24}) {
    switch (type) {
      case ActivityType.login:
        return Icon(Icons.key, color: const Color(0xFF2196F3), size: size);
      case ActivityType.post:
        return Icon(Icons.edit, color: const Color(0xFF9C27B0), size: size);
      case ActivityType.settings:
        return Icon(Icons.settings, color: const Color(0xFFFF9800), size: size);
      case ActivityType.security:
        return Icon(Icons.lock, color: const Color(0xFF4CAF50), size: size);
    }
  }

  Color _getStatusColor(ActivityStatus status) {
    return status == ActivityStatus.success
        ? const Color(0xFF4CAF50)
        : const Color(0xFFDC143C);
  }

  @override
  Widget build(BuildContext context) {
    final groupedActivities = _groupActivitiesByDate();

    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Activity History',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _refreshActivities,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white70),
            onPressed: _showClearHistoryDialog,
            tooltip: 'Clear History',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF2A2A2A),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filterOptions.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                      backgroundColor: const Color(0xFF1F1F1F),
                      selectedColor: const Color(0xFF2196F3),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      checkmarkColor: Colors.white,
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFF2196F3)
                            : const Color(0xFF3A3A3A),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Activity List
          Expanded(
            child: _isLoading && _activities.isEmpty
                ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2196F3),
              ),
            )
                : _filteredActivities.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _refreshActivities,
              color: const Color(0xFF2196F3),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: groupedActivities.length + 1,
                itemBuilder: (context, sectionIndex) {
                  // Loading indicator at bottom
                  if (sectionIndex == groupedActivities.length) {
                    return _isLoading
                        ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF2196F3),
                        ),
                      ),
                    )
                        : const SizedBox.shrink();
                  }

                  final dateKey =
                  groupedActivities.keys.elementAt(sectionIndex);
                  final activities = groupedActivities[dateKey]!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date Header
                      Padding(
                        padding: const EdgeInsets.only(
                            left: 8, bottom: 16, top: 8),
                        child: Text(
                          dateKey,
                          style: const TextStyle(
                            color: Color(0xFF2196F3),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                      // Activities in this date group
                      ...activities
                          .map((activity) =>
                          _buildActivityItem(activity)),

                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(ActivityItem activity) {
    return InkWell(
      onTap: () => _showActivityDetails(activity),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline
            Column(
              children: [
                // Status dot
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getStatusColor(activity.status),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF1F1F1F),
                      width: 2,
                    ),
                  ),
                ),
                // Vertical line
                Container(
                  width: 2,
                  height: 60,
                  color: const Color(0xFF3A3A3A),
                ),
              ],
            ),

            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF3A3A3A),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Icon
                    Row(
                      children: [
                        _getActivityIcon(activity.type),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            activity.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Timestamp
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          color: Colors.white60,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getRelativeTime(activity.timestamp),
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Device and Location
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_android,
                          color: Colors.white60,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${activity.device} • ${activity.location}',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            Icons.history,
            size: 80,
            color: Colors.white24,
          ),
          SizedBox(height: 16),
          Text(
            'No activity recorded yet',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your account activity will appear here',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// Models
enum ActivityType {
  login,
  post,
  settings,
  security,
}

enum ActivityStatus {
  success,
  failed,
}

class ActivityItem {
  final String title;
  final ActivityType type;
  final DateTime timestamp;
  final String device;
  final String location;
  final String ipAddress;
  final ActivityStatus status;

  ActivityItem({
    required this.title,
    required this.type,
    required this.timestamp,
    required this.device,
    required this.location,
    required this.ipAddress,
    required this.status,
  });

  // 🆕 From JSON
  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    return ActivityItem(
      title: json['title'] ?? '',
      type: ActivityType.values.firstWhere(
            (e) => e.toString().split('.').last == json['type'],
        orElse: () => ActivityType.login,
      ),
      timestamp: DateTime.parse(json['timestamp']),
      device: json['device'] ?? 'Unknown',
      location: json['location'] ?? 'Unknown',
      ipAddress: json['ipAddress'] ?? 'Unknown',
      status: json['status'] == 'success'
          ? ActivityStatus.success
          : ActivityStatus.failed,
    );
  }

  // 🆕 To JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'type': type.toString().split('.').last,
      'timestamp': timestamp.toIso8601String(),
      'device': device,
      'location': location,
      'ipAddress': ipAddress,
      'status': status == ActivityStatus.success ? 'success' : 'failed',
    };
  }
}